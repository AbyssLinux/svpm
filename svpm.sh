#!/bin/sh

VERSION="1.0.0"

MIRROR_CONF="/etc/xbps.d/00-repository-main.conf"
RETRIES=3

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    if [ -t 1 ]; then
        case "${TERM:-}" in
            dumb|unknown|"")
                printf '%s' "$2"
                ;;
            *)
                printf '%b%s%b' "$1" "$2" "$NC"
                ;;
        esac
    else
        printf '%s' "$2"
    fi
}

is_root() {
    [ "$(id -u)" -eq 0 ]
}

run() {
    if is_root; then
        "$@"
    else
        sudo "$@"
    fi
}

run_tty() {
    if is_root; then
        "$@" </dev/tty >/dev/tty 2>/dev/tty
    else
        sudo "$@" </dev/tty >/dev/tty 2>/dev/tty
    fi
}

retry_run() {
    i=1
    while [ $i -le "$RETRIES" ]; do
        if "$@"; then
            return 0
        fi
        print_color "$YELLOW" "Attempt $i/$RETRIES failed... retrying"
        echo
        sleep 2
        i=$((i + 1))
    done
    print_color "$RED" "Command failed after $RETRIES retries."
    echo
    return 1
}

cmd_install() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    
    run_tty xbps-install -S "$@"
    status=$?
    
    if [ "$status" -ne 0 ]; then
        run xbps-install -S "$@" 2>/tmp/svpm_err.log
        status=$?
        
        if [ "$status" -ne 0 ]; then
            if grep -q -E "fetch|connection|GPG|signature|network" /tmp/svpm_err.log 2>/dev/null; then
                print_color "$YELLOW" "Retrying..."
                echo
                retry_run run xbps-install -S "$@"
            else
                cat /tmp/svpm_err.log
                rm -f /tmp/svpm_err.log
                exit "$status"
            fi
        fi
    fi
    
    rm -f /tmp/svpm_err.log
}

cmd_remove() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    run_tty xbps-remove "$@"
}

cmd_update() {
    run_tty xbps-install -S
}

cmd_upgrade() {
    retry_run run_tty xbps-install -Su "$@"
    for arg in "$@"; do
        if [ "$arg" = "--clean" ]; then
            run_tty xbps-remove -o
            break
        fi
    done
}

cmd_search() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    xbps-query -Rs "$@"
}

cmd_smart_search() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    print_color "$YELLOW" "Searching installed packages:"
    echo
    xbps-query -s "$@"
    echo
    print_color "$YELLOW" "Searching remote repositories:"
    echo
    xbps-query -Rs "$@"
}

cmd_list() {
    xbps-query -l
}

cmd_files() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    xbps-query -f "$@"
}

cmd_reconfigure() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    run_tty xbps-reconfigure "$@"
}

cmd_reconfigure_all() {
    run_tty xbps-reconfigure -a
}

cmd_rdeps() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    xbps-query -Rx "$@"
}

cmd_owns() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    xbps-query -S -o "$@"
}

cmd_info() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    xbps-query -R "$@"
}

cmd_list_files() {
    for pkg in $(xbps-query -l | awk '{print $2}'); do
        printf '### %s\n' "$pkg"
        xbps-query -f "$pkg"
        echo
    done
}

cmd_held() {
    print_color "$YELLOW" "Held packages:"
    echo
    xbps-pkgdb -m list 2>/dev/null | grep held || echo "None found."
}

cmd_purge() {
    if [ $# -eq 0 ]; then
        cmd_help
        return
    fi
    printf 'Finding reverse dependencies of %s...\n' "$1"
    DEPS=$(xbps-query -Rx "$1" 2>/dev/null | awk '{print $2}' | grep -v "^$1$")
    printf 'Removing: %s %s\n' "$1" "$DEPS"
    run_tty xbps-remove -R "$1" $DEPS
}

cmd_cleanup() {
    run_tty xbps-remove -o
}

cmd_status() {
    printf 'Checking connection to Void repo...\n'
    if ping -c 1 repo-default.voidlinux.org >/dev/null 2>&1; then
        print_color "$GREEN" "Repository is online"
        echo
    else
        print_color "$RED" "Repository is unreachable"
        echo
    fi
}

cmd_mirror_set() {
    url="$1"
    if [ -z "$url" ]; then
        cmd_help
        return
    fi
    run sh -c "echo 'repository=$url' > $MIRROR_CONF"
    print_color "$GREEN" "Mirror set to: $url"
    echo
}

cmd_mirror_show() {
    print_color "$YELLOW" "Current mirror:"
    echo
    cat "$MIRROR_CONF" 2>/dev/null || echo "No mirror configured"
}

cmd_mirror_list() {
    print_color "$YELLOW" "Official mirrors:"
    echo
    echo "https://repo-fi.voidlinux.org/"
    echo "https://repo-de.voidlinux.org/"
    echo "https://repo-fastly.voidlinux.org/"
    echo "https://mirrors.servercentral.com/voidlinux/current"
}

cmd_mirror() {
    subcmd="$1"
    if [ -z "$subcmd" ]; then
        cmd_help
        return
    fi
    shift
    case "$subcmd" in
        set)
            cmd_mirror_set "$@"
            ;;
        show)
            cmd_mirror_show "$@"
            ;;
        list)
            cmd_mirror_list "$@"
            ;;
        *)
            cmd_help
            ;;
    esac
}

cmd_help() {
    print_color "$CYAN" "Usage:"
    printf ' svpm %s<%s>%s %s[args]%s\n' "$YELLOW" "command" "$NC" "$CYAN" "$NC"
    echo
    print_color "$GREEN" "Basic Commands:"
    echo
    printf '  %sinstall <pkg>%s           Install a package\n' "$YELLOW" "$NC"
    printf '  %sremove <pkg>%s            Remove a package\n' "$YELLOW" "$NC"
    printf '  %supgrade [--clean]%s       Upgrade system (optionally clean orphans)\n' "$YELLOW" "$NC"
    printf '  %supdate%s                  Sync repositories\n' "$YELLOW" "$NC"
    echo
    print_color "$GREEN" "Query Commands:"
    echo
    printf '  %ssearch <pattern>%s        Search available packages\n' "$YELLOW" "$NC"
    printf '  %ssmart-search <pattern>%s  Search installed and available packages\n' "$YELLOW" "$NC"
    printf '  %slist%s                    List installed packages\n' "$YELLOW" "$NC"
    printf '  %sinfo <pkg>%s              Show package info\n' "$YELLOW" "$NC"
    printf '  %sfiles <pkg>%s             Show files installed by package\n' "$YELLOW" "$NC"
    printf '  %sowns <file>%s             Find what package owns a file\n' "$YELLOW" "$NC"
    printf '  %srdeps <pkg>%s             Show reverse dependencies\n' "$YELLOW" "$NC"
    printf '  %sheld%s                    List held packages\n' "$YELLOW" "$NC"
    printf '  %slist-files%s              List files for all installed packages\n' "$YELLOW" "$NC"
    echo
    print_color "$GREEN" "System:"
    echo
    printf '  %sreconfigure <pkg>%s       Re-run postinstall for package\n' "$YELLOW" "$NC"
    printf '  %sreconfigure-all%s         Reconfigure all packages\n' "$YELLOW" "$NC"
    printf '  %spurge <pkg>%s             Remove package and reverse deps\n' "$YELLOW" "$NC"
    printf '  %smirror {set|show|list}%s  Manage repo mirrors\n' "$YELLOW" "$NC"
    printf '  %sstatus%s                  Check Void repo connection\n' "$YELLOW" "$NC"
    printf '  %scleanup%s                 Remove orphaned packages\n' "$YELLOW" "$NC"
}

main() {
    cmd="$1"
    if [ -z "$cmd" ]; then
        cmd="help"
    else
        shift
    fi
    
    case "$cmd" in
        install)
            cmd_install "$@"
            ;;
        remove)
            cmd_remove "$@"
            ;;
        update)
            cmd_update "$@"
            ;;
        upgrade)
            cmd_upgrade "$@"
            ;;
        search)
            cmd_search "$@"
            ;;
        smart-search)
            cmd_smart_search "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        files)
            cmd_files "$@"
            ;;
        reconfigure)
            cmd_reconfigure "$@"
            ;;
        reconfigure-all)
            cmd_reconfigure_all "$@"
            ;;
        rdeps)
            cmd_rdeps "$@"
            ;;
        owns)
            cmd_owns "$@"
            ;;
        info)
            cmd_info "$@"
            ;;
        list-files)
            cmd_list_files "$@"
            ;;
        held)
            cmd_held "$@"
            ;;
        purge)
            cmd_purge "$@"
            ;;
        cleanup)
            cmd_cleanup "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        mirror)
            cmd_mirror "$@"
            ;;
        help|--help|-h)
            cmd_help "$@"
            ;;
        *)
            print_color "$RED" "Unknown command: $cmd"
            echo
            printf 'Run '\''svpm help'\'' for a list of commands.\n'
            exit 1
            ;;
    esac
}

main "$@"
