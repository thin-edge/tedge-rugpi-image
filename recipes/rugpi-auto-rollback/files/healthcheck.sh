#!/bin/sh
set -eu

HOT=$(/usr/bin/rugpi-ctrl system info | grep Hot | cut -d: -f2 | xargs)
DEFAULT=$(/usr/bin/rugpi-ctrl system info | grep Default | cut -d: -f2 | xargs)
DEVICE_ID="$(tedge config get device.id)"
TARGET="$(tedge config get mqtt.topic_root)/$(tedge config get mqtt.device_topic_id)"

echo "Current rugpi-ctrl state:" >&2
/usr/bin/rugpi-ctrl system info >&2

HEALTH_CHECK_DIR=/etc/health.d

needs_commit() {
    [ "$HOT" != "$DEFAULT" ]
}

is_healthy() {
    # 0 = health, 1 = not health (to align with linux exit code convention)
    healthy=0
    if command -V run-parts >/dev/null 2>&1; then
        echo "Using run-parts to execute scripts in $HEALTH_CHECK_DIR" >&2
        if ! run-parts --exit-on-error --new-session --lsbsysinit --verbose "$HEALTH_CHECK_DIR"; then
            healthy=1
        fi
    else
        # TODO: support running scripts without run_parts
        echo "Using find to execute scripts in $HEALTH_CHECK_DIR" >&2
        find "$HEALTH_CHECK_DIR" -prune -type f -mode 0755 -exec {} \;
    fi

    return "$healthy"
}

collect_rugpi() {
    if [ -z "$DEVICE_ID" ]; then
        return 0
    fi
    # Collect rugpi state information, e.g. which partition is active
    HOT=$(/usr/bin/rugpi-ctrl system info | grep Hot | cut -d: -f2 | xargs)
    DEFAULT=$(/usr/bin/rugpi-ctrl system info | grep Default | cut -d: -f2 | xargs)

    # TODO: Change to te topic once inventory updates are supported
    # c8y payload
    PAYLOAD=$(printf '{"rugpi":{"hot":"%s","default":"%s"}}' "$HOT" "$DEFAULT")
    tedge mqtt pub "c8y/inventory/managedObjects/update/$DEVICE_ID" "$PAYLOAD" ||:

    # publish to tedge api which is not yet supported
    PAYLOAD=$(printf '{"hot":"%s","default":"%s"}' "$HOT" "$DEFAULT")
    tedge mqtt pub "$TARGET/data/rugpi" "$PAYLOAD" ||:

    # publish event for chronological order
    PAYLOAD=$(printf '{"text":"Partition info. hot=%s, default=%s"}' "$HOT" "$DEFAULT")
    tedge mqtt pub "$TARGET/e/device_boot" "$PAYLOAD" ||:
}

collect_os_info() {
    if [ -z "$DEVICE_ID" ]; then
        return 0
    fi

    # Collect Operating System information
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release ||:

        # TODO: Change to te topic once inventory updates are supported
        PAYLOAD=$(printf '{"device_OS":{"family":"%s","version":"%s"}}' "$NAME" "${VERSION:-$VERSION_ID}")
        tedge mqtt pub "c8y/inventory/managedObjects/update/$DEVICE_ID" "$PAYLOAD" ||:

        # publish to tedge api which is not yet supported
        PAYLOAD=$(printf '{"family":"%s","version":"%s"}' "$NAME" "${VERSION:-$VERSION_ID}")
        tedge mqtt pub --retain "$TARGET/data/device_OS" "$PAYLOAD" ||:
    fi
}

try_wait_for_broker() {
    # Try to wait until the broker is ready before publishing data.
    # Proceed anyway if it still is not ready have N tries
    RETRIES=10
    while [ "$RETRIES" -gt 0 ]; do
        if tedge mqtt pub 'dummy/message' ''; then
            echo "Broker is ready" >&2
            return 0
        fi
        RETRIES=$((RETRIES - 1))
        sleep 5
    done

    echo "Broker is not ready, but continuing anyway" >&2
}

publish_system_info() {
    try_wait_for_broker
    collect_rugpi
    collect_os_info
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

    publish_system_info
}

if ! needs_commit; then
    echo "Already on default partition. No commit/rollback needed. hot=$HOT, default=$DEFAULT" >&2
    publish_system_info
    exit 0
fi

main
