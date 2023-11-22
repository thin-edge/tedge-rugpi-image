#!/bin/sh
set -eu
LOG_FILE=/etc/tedge/healthcheck.log

# Perform simple log rotation, only keep last 200 lines
if [ -f "$LOG_FILE" ]; then
    tail -200 "$LOG_FILE" > "${LOG_FILE}.tmp" ||true
    mv "${LOG_FILE}.tmp" "$LOG_FILE" ||true
fi

_NEWLINE=$(printf '\n')
log() {
    message="$(date -Iseconds || date --iso-8601=seconds) $*"
    echo "$message"
    # Don't stop if writing to log fails (non critical error)
    echo "$message" 2>/dev/null >> "$LOG_FILE" ||true
}

log_r() {
    while IFS=$_NEWLINE read -r line; do
        log "$line"
    done
}

HOT=$(/usr/bin/rugpi-ctrl system info | grep Hot | cut -d: -f2 | xargs)
DEFAULT=$(/usr/bin/rugpi-ctrl system info | grep Default | cut -d: -f2 | xargs)
DEVICE_ID="$(tedge config get device.id)"
TARGET="$(tedge config get mqtt.topic_root)/$(tedge config get mqtt.device_topic_id)"
BUILD_INFO=/etc/.build_info

log "Current rugpi-ctrl state:"
/usr/bin/rugpi-ctrl system info | log_r

HEALTH_CHECK_DIR=/etc/health.d

hot_part() {
    /usr/bin/rugpi-ctrl system info | grep Hot | cut -d: -f2 | xargs
}

default_part() {
    /usr/bin/rugpi-ctrl system info | grep Default | cut -d: -f2 | xargs
}

needs_commit() {
    [ "$HOT" != "$DEFAULT" ]
}

is_healthy() {
    # 0 = health, 1 = not health (to align with linux exit code convention)
    healthy=0
    if command -V run-parts >/dev/null 2>&1; then
        log "Using run-parts to execute scripts in $HEALTH_CHECK_DIR"
        if ! run-parts --exit-on-error --new-session --lsbsysinit --verbose "$HEALTH_CHECK_DIR" >> "$LOG_FILE" 2>&1; then
            healthy=1
        fi
    else
        log "Using find to execute scripts in $HEALTH_CHECK_DIR"
        find "$HEALTH_CHECK_DIR" -prune -type f -mode 0755 -exec {} \; >> "$LOG_FILE" 2>&1
    fi

    return "$healthy"
}

collect_rugpi() {
    if [ -z "$DEVICE_ID" ]; then
        return 0
    fi

    # Collect firmware information
    firmware_name=
    firmware_version=
    if [ -f "$BUILD_INFO" ]; then
        firmware_name=$(cut -d_ -f1-2 "$BUILD_INFO")
        firmware_version=$(cut -d_ -f3- "$BUILD_INFO")
    fi
    if [ -z "$firmware_name" ]; then
        firmware_name=tedge_rugpi
    fi
    if [ -z "$firmware_version" ]; then
        firmware_version=unknown
    fi
    PAYLOAD=$(printf '{"name":"%s","version":"%s"}' "$firmware_name" "$firmware_version")
    tedge mqtt pub -q 1 -r "$TARGET/twin/c8y_Firmware" "$PAYLOAD" ||:

    # Collect rugpi state information, e.g. which partition is active
    PAYLOAD=$(printf '{"hot":"%s","default":"%s"}' "$HOT" "$DEFAULT")
    tedge mqtt pub -q 1 -r "$TARGET/twin/rugpi" "$PAYLOAD" ||:

    # publish event for chronological order
    PAYLOAD=$(printf '{"text":"Partition info. hot=%s (name=%s, version=%s), default=%s"}' "$HOT" "$firmware_name" "$firmware_version" "$DEFAULT")
    tedge mqtt pub -q 1 "$TARGET/e/device_boot" "$PAYLOAD" ||:
}

try_wait_for_broker() {
    # Try to wait until the broker is ready before publishing data.
    # Proceed anyway if it still is not ready have N tries
    RETRIES=10
    while [ "$RETRIES" -gt 0 ]; do
        if tedge mqtt pub 'dummy/message' ''; then
            log "Broker is ready"
            return 0
        fi
        RETRIES=$((RETRIES - 1))
        sleep 5
    done

    log "Broker is not ready, but continuing anyway"
}

publish_system_info() {
    try_wait_for_broker
    collect_rugpi
}

main() {
    counter=0
    COMMIT=0

    # Wait for broker before checking health, but don't block the health check
    try_wait_for_broker

    PAYLOAD=$(printf '{"text":"Booted into new image. Checking health before committing. hot=%s, default=%s"}' "$HOT" "$DEFAULT")
    tedge mqtt pub -q 1 "$TARGET/e/image_check" "$PAYLOAD" ||:

    # DEBUG: Give a chance to manually intercept this
    log "Waiting 10 minutes before checking health:"
    sleep 600

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
        log "Waiting 60 seconds before checking the health again"
        sleep 60
    done

    if [ "$COMMIT" = "0" ]; then
        log "Switching back to default partition: $DEFAULT"
        PAYLOAD=$(printf '{"text":"Health check failed. Rolling back to default partition. hot=%s, default=%s"}' "$HOT" "$DEFAULT")
        tedge mqtt pub -q 1 "$TARGET/e/image_rollback" "$PAYLOAD" ||:

        /usr/bin/rugpi-ctrl system reboot
        exit 0
    fi

    log "Making Hot partition the default partition: $DEFAULT"
    /usr/bin/rugpi-ctrl system commit
    log "Committed succesfully"

    # Refresh hot/default partition info as they change after a commit
    HOT=$(hot_part)
    DEFAULT=$(default_part)

    # Send notification that the image was committed
    PAYLOAD=$(printf '{"text":"Health check passed. Changing default partition. hot=%s, default=%s"}' "$HOT" "$DEFAULT")
    tedge mqtt pub "$TARGET/e/image_commit" "$PAYLOAD" ||:

    publish_system_info
}

if ! needs_commit; then
    log "Already on default partition. No commit/rollback needed. hot=$HOT, default=$DEFAULT"
    publish_system_info
    exit 0
fi

main
