#!/bin/sh
set -eu

HOT=$(/usr/bin/rugpi-ctrl system info | grep Hot | cut -d: -f2 | xargs)
DEFAULT=$(/usr/bin/rugpi-ctrl system info | grep Default | cut -d: -f2)

echo "Current rugpi-ctrl state:" >&2
/usr/bin/rugpi-ctrl system info >&2

HEALTH_CHECK_DIR=/etc/health.d

needs_commit() {
    [ "$HOT" = "$DEFAULT" ]
}

is_healthy() {
    # 0 = health, 1 = not health (to align with linux exit code convention)
    healthy=0
    if command -V run-parts >/dev/null 2>&1; then
        echo "Using run-parts to execute scripts in $HEALTH_CHECK_DIR" >&2
        if ! run-parts --exit-on-error --new-session --verbose "$HEALTH_CHECK_DIR"; then
            healthy=1
        fi
    else
        # TODO: support running scripts without run_parts
        echo "Using find to execute scripts in $HEALTH_CHECK_DIR" >&2
        find "$HEALTH_CHECK_DIR" -prune -type f -mode 0755 -exec {} \;
    fi

    return "$healthy"
}

main() {
    counter=0
    COMMIT=0
    while [ "$counter" -lt 10 ]; do
        if is_healthy; then
            COMMIT=1
            break
        fi

        if command -V bc >/dev/null 2>&1; then
            counter=$(echo "$counter+1"|bc)
        else
            counter=$((counter + 1))
        fi
        echo "Waiting 60 seconds before checking the health again" >&2
        sleep 60
    done

    if [ "$COMMIT" = "0" ]; then
        echo "Switching back to default partition: $DEFAULT" >&2
        /usr/bin/rugpi-ctrl system reboot
        exit 0
    fi

    echo "Making Hot partition the default partition: $DEFAULT" >&2
    /usr/bin/rugpi-ctrl system commit
}

if ! needs_commit; then
    echo "Already on default partition. No commit/rollback needed" >&2
    exit 0
fi

main
