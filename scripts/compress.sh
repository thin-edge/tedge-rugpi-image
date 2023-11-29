#!/usr/bin/env bash
set -e

SUDO=
if [ -n "$CI" ]; then
    # use sudo when running in the CI otherwise the following error occurs
    # regardless of the owner of the file and folder.
    # xz: Cannot set the file group: Operation not permitted
    SUDO=sudo
fi

$SUDO xz -0 -v "$1"
