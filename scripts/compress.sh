#!/usr/bin/env bash
set -e

SUDO=

requires_sudo() {
    if stat --help >/dev/null 2>&1; then
        IMAGE_OWNER=$(stat -c "%u" "$1")
    else
        # bsd variant
        IMAGE_OWNER=$(stat -f "%u" "$1")
    fi
    [ "$IMAGE_OWNER" = 0 ]
}

# On some systems docker creates the image as the root user which
# requires running xz with sudo otherwise the following error occurs:
# xz: Cannot set the file group: Operation not permitted
if requires_sudo "$1"; then
    echo "Image is owned by root, so compressing using sudo" >&2
    SUDO=sudo
fi

$SUDO xz -0 -v "$1"
