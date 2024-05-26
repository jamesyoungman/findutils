#! /bin/sh

# You might use this tool like this:
#
# sh build-aux/tabs-to-spaces.sh check $( find find lib locate tests xargs  -regextype posix-extended -regex '.*[.]([ch]|cc)$' )
set -u


error() {
    echo "$@" >&2
    exit 1
}

cleanup() {
    if ! rm -f "$@"
    then
        error "failed to delete temporary file(s) $@"
        return 1
    fi
}

usage_error() {
    error "Please specify a sub-command (either 'check' or 'fix')."
}

make_expanded_file() {
    if output="$(mktemp)"
    then
        expand -- "$1" > "${output}" && echo "${output}"
    else
        error 'failed to create temporary file'
    fi
}

check() {
    result=0
    for input
    do
        if expanded="$(make_expanded_file ${input})"
        then
            cmp -s -- "${input}" "${expanded}"
            rv="$?"
            if ! cleanup "${expanded}"
            then
                return 1
            fi
            case "$rv" in
                0) ;;
                1) echo "${input} is incorrectly formatted (it contains tabs)"
                   result=1
                   ;;
                *) error "failed to compare ${input} with ${expanded}"
                   ;;
            esac
        else
            exit 1
        fi
    done
    return $result
}

fix() {
    for input
    do
        if expanded="$(make_expanded_file ${input})"
        then
            cmp -s -- "${input}" "${expanded}"
            rv="$?"
            case "$rv" in
                0) if ! cleanup "${expanded}"
                   then
                       return 1
                   fi
                   # Otherwise, continue with next file.
                   ;;
                1) if ! mv "${expanded}" "${input}"
                   then
                       cleanup "${expanded}"
                       error "failed to replace ${input} with tab-expanded version ${expanded}"
                   else
                       unset expanded
                   fi
                   # Otherwise, continue with next file.
                   ;;
                *) error "failed to compare ${input} with ${expanded}"
                   ;;
            esac
        else
            exit 1
        fi
    done
}

main() {
    if [ $# -eq 0 ]
    then
        usage_error
    fi
    case "$1" in
        check) shift; check "$@" ;;
        fix) shift; fix "$@" ;;
        *) usage_error ;;

    esac
}


main "$@"
