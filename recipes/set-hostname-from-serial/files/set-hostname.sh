#!/bin/sh
set -e

MODEL=$(cat /proc/cpuinfo  | grep Model | cut -d: -f2 | xargs)
SERIAL_NO=$(cat /proc/cpuinfo  | grep Serial | cut -d: -f2 | xargs)

MODEL_PREFIX=
IMAGE_FAMILY=rugpi

case "$MODEL" in
    Raspberry\ Pi\ 5*)
        MODEL_PREFIX=rpi5
        ;;
    Raspberry\ Pi\ 4*)
        MODEL_PREFIX=rpi4
        ;;
    Raspberry\ Pi\ 3*)
        MODEL_PREFIX=rpi3
        ;;
    Raspberry\ Pi\ 2\ Rev*)
        MODEL_PREFIX=rpi2
        ;;
    Raspberry\ Pi\ Model*)
        MODEL_PREFIX=rpi1
        ;;
    Raspberry\ Pi\ Zero\ 2\ W\ Rev*)
        MODEL_PREFIX=rpizero2
        ;;
    Raspberry\ Pi\ Zero\ W\ Rev*)
        MODEL_PREFIX=rpizero
        ;;
    *)
        MODEL_PREFIX=unknown
        ;;
esac

NEW_HOSTNAME="${MODEL_PREFIX}-${IMAGE_FAMILY}-${SERIAL_NO}"
echo "Detected model: $MODEL"
echo "Detected serial no.: $SERIAL_NO"
echo "Using model prefix: $MODEL_PREFIX"
echo "Setting new hostname based on hardware: $NEW_HOSTNAME"

# Host name may only contain a-z, 0-9 and - (hypens)
echo "${MODEL_PREFIX}-${IMAGE_FAMILY}-${SERIAL_NO}" > /etc/hostname

# cat > /etc/hosts << EOF
# 127.0.0.1       localhost
# ::1             localhost ip6-localhost ip6-loopback
# ff02::1         ip6-allnodes
# ff02::2         ip6-allrouters
# EOF
