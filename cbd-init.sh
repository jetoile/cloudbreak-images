[[ "$TRACE" ]] && set -x

: ${DEBUG:=1}
: ${OS_USER:=cloudbreak}
: ${CBD_DIR:=cloudbreak-deployment}

debug() {
    [[ "$DEBUG" ]] && echo "-----> $*" 1>&2
}

reset_docker() {
    debug "STOP docker and clean id"
    service docker stop
    echo "Deleting key.json in order to avoid swarm conflicts"
    rm -vf /etc/docker/key.json
}

wait_for_cloudbreak() {
    debug "waitng for cloudbreak API ..."
    while ! curl -f  172.17.0.1:8080/info &>/dev/null ; do 
        echo -n .; sleep 1
    done

    debug "cloudbreak info: $( curl 172.17.0.1:8080/info)"
}
cbd_init() {
    mkdir $CBD_DIR
    cd $_
    cbd init

    if [[ "$CBD_BRANCH" != "" ]]; then
        debug "[UPDATING] update to: $CBD_BRANCH"
        cbd update $CBD_BRANCH
    fi

    cbd pull-parallel
    debug "start deployment to trigger image pull"
    cbd start

    wait_for_cloudbreak
    debug "stops containers"
    cbd kill

    debug "clean Profile certs and yamls"

    rm -rf Profile certs *.yml *.log
    cd ..
    chown -R $OS_USER:$OS_USER $CBD_DIR
    sudo chown -R $OS_USER:$OS_USER /var/lib/cloudbreak/
}

cbd_install() {
    : ${CBD_INSTALL_DIR:=/bin}
    : ${CBD_VERSION:?required}
    deubg "Install cbd: ${CBD_VERSION:?required} to ${CBD_INSTALL_DIR}"
    curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_${CBD_VERSION:?required}_$(uname)_x86_64.tgz \
        | tar -xz -C ${CBD_INSTALL_DIR}
}

main() {
    debug "START docker ..."
    service docker start

    cbd_install
    cbd_init
    reset_docker
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"