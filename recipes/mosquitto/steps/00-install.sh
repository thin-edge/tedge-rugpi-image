#!/bin/bash -e
# Install more recent version of mosquitto >= 2.0.18 from debian sid to avoid mosquitto following bugs:
# The mosquitto repo can't be used as it does not included builds for arm64/aarch64 (only amd64 and armhf)
# * https://github.com/eclipse/mosquitto/issues/2604 (2.0.11)
# * https://github.com/eclipse/mosquitto/issues/2634 (2.0.15)
echo 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://deb.debian.org/debian bookworm-backports main' > /etc/apt/sources.list.d/debian-bookworm-backports.list
apt-get update

DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Options::=--force-confold -y --no-install-recommends install -t bookworm-backports \
    mosquitto \
    mosquitto-clients
