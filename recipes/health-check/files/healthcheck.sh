#!/bin/sh
set -eu
HEALTH_CHECK_DIR=/etc/health.d
_NEWLINE=$(printf '\n')

log() {
    message="$(date -Iseconds || date --iso-8601=seconds) $*"
    echo "$message"
}

is_healthy() {
    # 0 = healthy, 1 = not healthy (to align with linux exit code convention)
    not_ok=0
    if command -V run-parts >/dev/null 2>&1; then
        log "Using run-parts to execute scripts in $HEALTH_CHECK_DIR"
        if ! run-parts --exit-on-error --new-session --lsbsysinit --verbose "$HEALTH_CHECK_DIR"; then
            not_ok=1
        fi
    else
        log "Using for loop to execute scripts in $HEALTH_CHECK_DIR"
        for file in "$HEALTH_CHECK_DIR"/*; do
            if [ -x "$file" ]; then
                if ! "$file"; then
                    not_ok=1
                    break
                fi
            fi
        done
    fi

    return "$not_ok"
}

main() {
    counter=0
    NOT_OK=1
    RETRY_DELAY=30

    while [ "$counter" -lt 10 ]; do
        if is_healthy; then
            NOT_OK=0
            break
        fi

        if command -V bc >/dev/null 2>&1; then
            counter=$(echo "$counter+1"|bc)
        else
            counter=$((counter + 1))
        fi
        log "Waiting $RETRY_DELAY seconds before checking the health again"
        sleep "$RETRY_DELAY"
    done

    exit "$NOT_OK"
}

main
