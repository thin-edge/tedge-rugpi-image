#!/bin/sh
set -e
ON_SUCCESS="successful"
ON_ERROR="failed"
ON_RESTART="restart"
FIRMWARE_NAME=
FIRMWARE_VERSION=
FIRMWARE_URL=
CMD_ID=x
FIRMWARE_META_FILE=/etc/tedge/.firmware
LOG_FILE=/etc/tedge/firmware_update.log
MANUAL_DOWNLOAD=1
REBOOT_SPARE_REQUEST=/etc/rugpi/.reboot_spare

SUDO="sudo"

_WORKDIR=$(pwd)

# Change to a directory which is readable otherwise rugpi-ctrl can have problems reading the mounts
cd /

HOT=$(rugpi-ctrl system info | grep Hot | cut -d: -f2 | xargs)
DEFAULT=$(rugpi-ctrl system info | grep Default | cut -d: -f2 | xargs)

ACTION="$1"
shift


log() {
    msg="$(date +%Y-%m-%dT%H:%M:%S) [cmd=$CMD_ID, current=$ACTION] $*"
    echo "$msg" >&2

    # publish to pub for better resolution
    current_partition=$(get_current_partition)
    tedge mqtt pub -q 2 te/device/main///e/firmware_update "{\"text\":\"Firmware Workflow: [$ACTION] $*\",\"command_id\":\"$CMD_ID\",\"state\":\"$ACTION\",\"partition\":\"$current_partition\"}"
    sleep 1

    if [ -n "$LOG_FILE" ]; then
        echo "$msg" >> "$LOG_FILE"
    fi
}

local_log() {
    # Only log locally and don't push to the cloud
    msg="$(date +%Y-%m-%dT%H:%M:%S) [cmd=$CMD_ID, current=$ACTION] $*"
    echo "$msg" >&2

    if [ -n "$LOG_FILE" ]; then
        echo "$msg" >> "$LOG_FILE"
    fi
}

next_state() {
    status="$1"
    reason=

    if [ $# -gt 1 ]; then
        reason="$2"
    fi

    if [ -n "$reason" ]; then
        log "Moving to next State: $status. reason=$reason"
        printf '{"status":"%s","reason":"%s"}\n' "$status" "$reason"
    else
        log "Moving to next State: $status"
        printf '{"status":"%s"}\n' "$status"
    fi
    sleep 1
}

#
# main
#
while [ $# -gt 0 ]; do
    case "$1" in
        --id)
            CMD_ID="$2"
            shift
            ;;
        --firmware-name)
            FIRMWARE_NAME="$2"
            shift
            ;;
        --firmware-version)
            FIRMWARE_VERSION="$2"
            shift
            ;;
        --on-success)
            ON_SUCCESS="$2"
            shift
            ;;
        --on-error)
            ON_ERROR="$2"
            shift
            ;;
        --on-restart)
            ON_RESTART="$2"
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

get_current_partition() {
    current=$(rugpi-ctrl system info | grep Hot | cut -d: -f2 | xargs | tr '[:lower:]' '[:upper:]')
    echo "$current"
}

get_next_partition() {
    [ "$1" = "A" ] && echo "B" || echo "A"
}

executing() {
    current_partition=$(get_current_partition)
    next_partition=$(get_next_partition "$current_partition")
    {
        echo "---------------------------------------------------------------------------"
        echo "Firmware update (id=$CMD_ID): $current_partition -> $next_partition"
        echo "---------------------------------------------------------------------------"
    } >> "$LOG_FILE"
    log "Starting firmware update. Current partition is $(get_current_partition), so update will be applied to $next_partition"
}

download() {
    status="$1"
    url="$2"

    #
    # Change url to a local url using the c8y proxy
    #
    case "$url" in
        http://*)
            partial_path=$(echo "$url" | sed 's|https://[^/]*/||g')
            tedge_url="$url"
            ;;
        https://*)
            partial_path=$(echo "$url" | sed 's|https://[^/]*/||g')
            c8y_proxy_host=$(tedge config get c8y.proxy.client.host)
            c8y_proxy_port=$(tedge config get c8y.proxy.client.port)
            tedge_url="http://${c8y_proxy_host}:${c8y_proxy_port}/c8y/$partial_path"
            ;;
        *)
            # Assume url is actually a file and just go to the next state
            printf '{"status":"%s"}\n' "$status"
            return 0
            ;;
    esac

    TEDGE_DATA=$(tedge config get data.path)

    if [ "$MANUAL_DOWNLOAD" = 1 ]; then

        # Removing any older files to ensure space for next file to download
        # Note: busy box does not support -delete
        find "$TEDGE_DATA" -name "*.firmware" -exec rm {} \;

        last_part=$(echo "$partial_path" | rev | cut -d/ -f1 | rev)
        local_file="$TEDGE_DATA/${last_part}.firmware"
        log "Manually downloading artifact from $tedge_url and saving to $local_file"
        wget -c -O "$local_file" "$tedge_url" >&2
        log "Downloaded file from: $tedge_url"
        printf '{"status":"%s","url":"%s"}\n' "$status" "$local_file"
    else
        log "Converted to local url: $url => $tedge_url"
        printf '{"status":"%s","url":"%s"}\n' "$status" "$tedge_url"
    fi
}

install() {
    url="$1"
    set +e
    case "$url" in
        http*.xz)
            log "Executing: wget -c -q -t 0 -O - '$url' | xz -d | $SUDO rugpi-ctrl update install --stream --no-reboot -"
            wget -c -q -t 0 -O - "$url" | xz -d | $SUDO rugpi-ctrl update install --stream --no-reboot - >>"$LOG_FILE" 2>&1
            ;;
        http*.img)
            log "Executing: wget -c -q -t 0 -O - '$url' | $SUDO rugpi-ctrl update install --stream --no-reboot -"
            wget -c -q -t 0 -O - "$url" | $SUDO rugpi-ctrl update install --stream --no-reboot - >>"$LOG_FILE" 2>&1
            ;;
        # It is a file
        *.xz)
            # Decode the file and stream it into rugpi (decompressing on the fly)
            log "TODO: Executing: xz -d -T0 -c '$url' | $SUDO rugpi-ctrl update install --stream --no-reboot -"
            xz --decompress --stdout -T0 "$url" | $SUDO rugpi-ctrl update install --stream --no-reboot - >>"$LOG_FILE" 2>&1
            ;;
        *.img)
            # Uncompressed file
            log "Executing: rugpi-ctrl update install --no-reboot '$url'"
            $SUDO rugpi-ctrl update install --no-reboot "$url" >>"$LOG_FILE" 2>&1
            ;;
        *)
            log "Unsupported firmware file format. file=$url. Only xz and img files are supported"
            ;;
    esac
    EXIT_CODE=$?
    set -e

    case "$EXIT_CODE" in
        0)
            log "OK, RESTART required"
            next_state "$ON_SUCCESS"
            ;;
        *)
            log "ERROR. Unexpected return code. code=$EXIT_CODE"
            next_state "$ON_ERROR" "ERROR. Unexpected return code. code=$EXIT_CODE"
            ;;
    esac

    # Create mark file which is used by the restart state to reboot into the spare partition
    touch "$REBOOT_SPARE_REQUEST"
}

restart() {
    # NOTE: This function should not be called in the script directly but rather via the system.toml
    if [ -f "$REBOOT_SPARE_REQUEST" ]; then
        rm -f "$REBOOT_SPARE_REQUEST"

        message=$(printf '{"text":"Rebooting into spare partition (%s -> %s)"}' "$(get_current_partition)" "$(get_next_partition)")
        tedge mqtt pub -q 1 "te/device/main///e/reboot_spare" "$message" ||:
        sleep 5
        $SUDO rugpi-ctrl system reboot --spare
    else
        message=$(printf '{"text":"Rebooting into default partition (%s -> %s)"}' "$(get_current_partition)" "$DEFAULT")
        tedge mqtt pub -q 1 "te/device/main///e/reboot_default" "$message" ||:
        sleep 5
        $SUDO rugpi-ctrl system reboot
    fi
    exit 0
}

verify() {
    log "Checking device health"

    if [ "$HOT" = "$DEFAULT" ]; then
        # Don't both to reboot if no partition swap occurred because we are already in the ok partition
        next_state "$ON_ERROR" "Partition swap did not occur. Reasons could be, corrupt/non-bootable image, someone did a manual rollback or the machine was restarted manually before the health check was run"
        return
    fi

    # Allow users to also call addition logic by adding their scripts to the /etc/health.d/ directory
    if /usr/bin/healthcheck.sh; then
        next_state "$ON_SUCCESS"
    else
        next_state "$ON_RESTART"
    fi
}

commit() {
    log "Executing: rugpi-ctrl system commit"
    set +e
    $SUDO rugpi-ctrl system commit >> "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    set -e

    case "$EXIT_CODE" in
        0)
            log "Commit successful. New default partition is $(get_current_partition)"

            # Save firmware meta information to file (for reading on startup during normal operation)
            local_log "Saving firmware info to $FIRMWARE_META_FILE"
            printf 'FIRMWARE_NAME=%s\nFIRMWARE_VERSION=%s\nFIRMWARE_URL=%s\n' "$FIRMWARE_NAME" "$FIRMWARE_VERSION" "$FIRMWARE_URL" > "$FIRMWARE_META_FILE"

            next_state "$ON_SUCCESS"
            ;;
        *)
            log "rugpi-ctrl returned code: $EXIT_CODE. Rolling back to previous partition"
            next_state "$ON_RESTART"
            ;;
    esac
}

case "$ACTION" in
    executing)
        executing
        next_state "$ON_SUCCESS"
        ;;
    download) download "$ON_SUCCESS" "$FIRMWARE_URL"; ;;
    install) install "$FIRMWARE_URL"; ;;
    verify) verify; ;;
    commit) commit; ;;
    restart) restart; ;;
    restarted)
	    wait_for_network ||:
        log "Device has been restarted...continuing workflow. partition=$(get_current_partition)"
        next_state "$ON_SUCCESS"
        ;;
    rollback_successful)
        next_state "$ON_SUCCESS" "Firmware update failed, but the rollback was successful. partition=$(get_current_partition)"
        ;;
    failed_restart)
        # There is no success/failed action here, we always transition to the next state
        # Only an error reason is added
        next_state "$ON_SUCCESS" "Device failed to restart"
        ;;
    *)
        log "Unknown command. This script only accepts: download, install, commit, rollback, rollback_successful, failed_restart"
        exit 1
        ;;
esac

# switch back to original directory
cd "$_WORKDIR" ||:

exit 0
