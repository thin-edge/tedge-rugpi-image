#!/bin/sh
set -e

HARDWARE=$(cat /proc/cpuinfo  | grep Serial | cut -d: -f2 | xargs)
SERIAL_NO=$(cat /proc/cpuinfo  | grep Serial | cut -d: -f2 | xargs)
#MODEL=$(cat /proc/cpuinfo  | grep Model | cut -d: -f2- | xargs)

MODEL_HUMAN=
IMAGE_FAMILY=rugpi

case "$HARDWARE" in
    Raspberry\ Pi\ 5*)
        MODEL_HUMAN=rpi5
        ;;
    Raspberry\ Pi\ 4*)
        MODEL_HUMAN=rpi4
        ;;
    Raspberry\ Pi\ 3*)
        MODEL_HUMAN=rpi3
        ;;
    Raspberry\ Pi\ 2\ Rev*)
        MODEL_HUMAN=rpi2
        ;;
    Raspberry\ Pi\ Model*)
        MODEL_HUMAN=rpi1
        ;;
    Raspberry\ Pi\ Zero\ 2\ W\ Rev*)
        MODEL_HUMAN=rpizero2
        ;;
    Raspberry\ Pi\ Zero\ W\ Rev*)
        MODEL_HUMAN=rpizero
        ;;
    *)
        MODEL_HUMAN=unknown
        ;;
esac

echo "${MODEL_HUMAN}_${IMAGE_FAMILY}_${SERIAL_NO}" > /etc/hostname

# cat > /etc/hosts << EOF
# 127.0.0.1       localhost
# ::1             localhost ip6-localhost ip6-loopback
# ff02::1         ip6-allnodes
# ff02::2         ip6-allrouters
# EOF
