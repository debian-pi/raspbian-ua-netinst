CURL() {
    if [ "_$IN_DOCKER" = _yes ] ; then
        echo curl -s "$@"  # show command instead of a progress bar
             curl -s "$@"
    else
        curl -# "$@"
    fi
}
