#!/bin/sh
set -e
FIRMWARE_NAME=
FIRMWARE_VERSION=
FIRMWARE_URL=
FIRMWARE_META_FILE=/etc/tedge/.firmware
MANUAL_DOWNLOAD=0

# Exit codes
OK=0
FAILED=1
REQUEST_RESTART=4

# Use temp directory so that the file can't accidentally persist across partitions
# thus always booting into the spare partition
REBOOT_SPARE_REQUEST=/tmp/.reboot_spare

# Detect if sudo should be used or not. It will be used if it is found
SUDO=""
if command -V sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

_WORKDIR=$(pwd)

# Change to a directory which is readable otherwise rugpi-ctrl can have problems reading the mounts
cd /tmp || cd /

HOT=$(rugpi-ctrl system info | grep Hot | cut -d: -f2 | tr '[:lower:]' '[:upper:]' | xargs)
DEFAULT=$(rugpi-ctrl system info | grep Default | cut -d: -f2 | tr '[:lower:]' '[:upper:]' | xargs)
SPARE=$(rugpi-ctrl system info | grep Spare | cut -d: -f2 | tr '[:lower:]' '[:upper:]' | xargs)

ACTION="$1"
shift

log() {
    msg="$(date +%Y-%m-%dT%H:%M:%S) [current=$ACTION] $*"
    echo "$msg" >&2

    # publish to pub for better resolution
    tedge mqtt pub -q 2 te/device/main///e/firmware_update "{\"text\":\"Firmware Workflow: [$ACTION] $*\",\"state\":\"$ACTION\",\"partition\":\"$HOT\"}"
    sleep 1
}

local_log() {
    # Only log locally and don't push to the cloud
    msg="$(date +%Y-%m-%dT%H:%M:%S) [current=$ACTION] $*"
    echo "$msg" >&2
}

update_state() {
    echo ":::begin-tedge:::"
    echo "$1"
    echo ":::end-tedge:::"
    sleep 1
}

set_reason() {
    reason="$1"
    message=$(printf '{"reason":"%s"}' "$reason")
    update_state "$message"
}

#
# main
#
while [ $# -gt 0 ]; do
    case "$1" in
        --firmware-name)
            FIRMWARE_NAME="$2"
            shift
            ;;
        --firmware-version)
            FIRMWARE_VERSION="$2"
            shift
            ;;
        --url)
            FIRMWARE_URL="$2"
            shift
            ;;
    esac
    shift
done

wait_for_network() {
    #
    # Wait for network to be ready but don't block if still not available as the commit
    # might be used to restore network connectivity.
    #
    attempt=0
    max_attempts=10
    # Network ready: 0 = no, 1 = yes
    ready=0
    local_log "Waiting for network to be ready, and time to be synced"

    while [ "$attempt" -lt "$max_attempts" ]; do
        # TIME_SYNC_ACTIVE=$(timedatectl | grep NTP | awk '{print $NF}')
        TIME_IN_SYNC=$(timedatectl | awk '/System clock synchronized/{print $NF}')
        case "${TIME_IN_SYNC}" in
            yes)
                ready=1
                break
                ;;
        esac
        attempt=$((attempt + 1))
        local_log "Network not ready yet (attempt: $attempt from $max_attempts)"
        sleep 30
    done

    # Duration can only be based on uptime since the device's clock might not be synced yet, so 'date' will not be monotonic
    duration=$(awk '{print $1}' /proc/uptime)

    local_log "Network: ready=$ready (after ${duration}s)"
    if [ "$ready" = "1" ]; then
        log "Network is ready after ${duration}s (from startup)"
        return 0
    fi

    # Don't send cloud message if it is not ready
    return 1
}

executing() {
    if [ "$HOT" != "$DEFAULT" ]; then
        set_reason "Refusing to install update as the current (hot) partition is not the default partition. This indicates that you may be in the middle of an update. Please reboot to switch to the default partition"
        exit "$FAILED"
    fi
    log "Starting firmware update. Current partition is $HOT, so update will be applied to $SPARE"
}

download() {
    url="$1"

    #
    # Change url to a local url using the c8y proxy
    #
    case "$url" in
        https://*/inventory/binaries/*)
            # Cumulocity URL, use the c8y auth proxy service
            partial_path=$(echo "$url" | sed 's|https://[^/]*/||g')
            c8y_proxy_host=$(tedge config get c8y.proxy.client.host)
            c8y_proxy_port=$(tedge config get c8y.proxy.client.port)
            tedge_url="http://${c8y_proxy_host}:${c8y_proxy_port}/c8y/$partial_path"
            ;;
        http://*|https://*)
            # External URL, pass it untouched
            # NOTE: If a service required authorization, then this would be the place to add it
            # For example some blob stores support signed URLS
            partial_path=$(echo "$url" | sed 's|https://[^/]*/||g')
            tedge_url="$url"
            ;;
        *)
            # Assume url is actually a file and just go to the next state
            update_state "$(printf '{"url":"%s"}\n' "$url")"
            return "$OK"
            ;;
    esac

    if [ "$MANUAL_DOWNLOAD" = 1 ]; then
        TEDGE_DATA=$(tedge config get data.path)

        # Removing any older files to ensure space for next file to download
        # Note: busy box does not support the -delete flag
        find "$TEDGE_DATA" -name "*.firmware" -exec rm {} \;

        last_part=$(echo "$partial_path" | rev | cut -d/ -f1 | rev)
        local_file="$TEDGE_DATA/${last_part}.firmware"
        log "Manually downloading artifact from $tedge_url and saving to $local_file"
        wget -c -O "$local_file" "$tedge_url" >&2
        log "Downloaded file from: $tedge_url"
        update_state "$(printf '{"url":"%s"}\n' "$local_file")"
    else
        log "Replacing url with a tedge url: $tedge_url"
        update_state "$(printf '{"url":"%s"}\n' "$tedge_url")"
    fi
}

install() {
    url="$1"
    set +e
    case "$url" in
        http://*.img|https://*.img)
            log "Downloading and streaming uncompressed image to rugpi"
            wget -c -q -t 0 -O - "$url" | $SUDO rugpi-ctrl update install --stream --no-reboot -
            ;;

        # Assume a xz compressed file        
        http://*|https://*)
            log "Downloading and streaming xz compressed image to rugpi"
            wget -c -q -t 0 -O - "$url" | xz -d | $SUDO rugpi-ctrl update install --stream --no-reboot -
            ;;

        # It is a file
        *)
            # Check file type using mime types
            mime_type=$(file "$url" --mime-type | cut -d: -f2 | xargs)

            case "$mime_type" in
                application/x-xz)
                    # Decode the file and stream it into rugpi (decompressing on the fly)
                    log "Installing local xz compressed image to rugpi"
                    xz --decompress --stdout -T0 "$url" | $SUDO rugpi-ctrl update install --stream --no-reboot -
                    ;;
                *)
                    # Uncompressed file
                    log "Installing local uncompressed image to rugpi"
                    $SUDO rugpi-ctrl update install --no-reboot "$url"
                    ;;
            esac
            ;;
    esac
    EXIT_CODE=$?
    set -e

    case "$EXIT_CODE" in
        0)
            log "OK, RESTART required"
            ;;
        *)
            log "ERROR. Unexpected return code. code=$EXIT_CODE"
            ;;
    esac

    # Create mark file which is used by the restart state to reboot into the spare partition
    touch "$REBOOT_SPARE_REQUEST"
    exit "$EXIT_CODE"
}

restart() {
    # NOTE: This function should not be called in the script directly but rather via the system.toml
    if [ -f "$REBOOT_SPARE_REQUEST" ]; then
        rm -f "$REBOOT_SPARE_REQUEST"

        message=$(printf '{"text":"Rebooting into spare partition (%s -> %s)","partition":"%s"}' "$HOT" "$SPARE" "$HOT")
        tedge mqtt pub -q 1 "te/device/main///e/reboot_spare" "$message" ||:
        sleep 5
        $SUDO rugpi-ctrl system reboot --spare
    else
        message=$(printf '{"text":"Rebooting into default partition (%s -> %s)","partition":"%s"}' "$HOT" "$DEFAULT" "$HOT")
        tedge mqtt pub -q 1 "te/device/main///e/reboot_default" "$message" ||:
        sleep 5
        $SUDO rugpi-ctrl system reboot
    fi
    exit "$OK"
}

verify() {
    log "Checking device health"

    if [ "$HOT" = "$DEFAULT" ]; then
        # Don't both to reboot if no partition swap occurred because we are already in the ok partition
        set_reason "Partition swap did not occur. Reasons could be, corrupt/non-bootable image, someone did a manual rollback or the machine was restarted manually before the health check was run"
        exit "$FAILED"
    fi

    # Allow users to also call addition logic by adding their scripts to the /etc/health.d/ directory
    if /usr/bin/healthcheck.sh; then
        exit "$OK"
    else
        set_reason "Health check failed on new partition"
        exit "$REQUEST_RESTART"
    fi
}

commit() {
    log "Executing: rugpi-ctrl system commit"
    set +e
    $SUDO rugpi-ctrl system commit
    EXIT_CODE=$?
    set -e

    case "$EXIT_CODE" in
        0)
            # Check what the updated default partition is
            DEFAULT=$(rugpi-ctrl system info | grep Default | cut -d: -f2 | tr '[:lower:]' '[:upper:]' | xargs)

            log "Commit successful. New default partition is $DEFAULT"
            # Save firmware meta information to file (for reading on startup during normal operation)
            local_log "Saving firmware info to $FIRMWARE_META_FILE"
            printf 'FIRMWARE_NAME=%s\nFIRMWARE_VERSION=%s\nFIRMWARE_URL=%s\n' "$FIRMWARE_NAME" "$FIRMWARE_VERSION" "$FIRMWARE_URL" > "$FIRMWARE_META_FILE"
            ;;
        *)
            log "rugpi-ctrl returned code: $EXIT_CODE. Rolling back to previous partition"
            ;;
    esac
    exit "$EXIT_CODE"
}

case "$ACTION" in
    executing) executing; ;;
    download) download "$FIRMWARE_URL"; ;;
    install) install "$FIRMWARE_URL"; ;;
    verify) verify; ;;
    commit) commit; ;;
    restart) restart; ;;
    restarted)
	    wait_for_network ||:
        log "Device has been restarted...continuing workflow. partition=$HOT, default=$DEFAULT"
        ;;
    rollback_successful)
        log "Firmware update failed, but the rollback was successful. partition=$HOT, default=$DEFAULT"
        ;;
    failed_restart) ;;
    *)
        log "Unknown command. This script only accepts: download, install, commit, rollback, rollback_successful, failed_restart"
        exit "$FAILED"
        ;;
esac

# switch back to original directory
cd "$_WORKDIR" ||:

exit "$OK"
