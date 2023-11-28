#!/bin/bash -e
# Install more recent version of mosquitto >= 2.0.18 from debian sid to avoid mosquitto following bugs:
# The mosquitto repo can't be used as it does not included builds for arm64/aarch64 (only amd64 and armhf)
# * https://github.com/eclipse/mosquitto/issues/2604 (2.0.11)
# * https://github.com/eclipse/mosquitto/issues/2634 (2.0.15)
echo 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://deb.debian.org/debian sid main' > /etc/apt/sources.list.d/debian-sid.list
apt-get update

DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    mosquitto \
    mosquitto-clients

# Remove sid afterwards to prevent unexpected packages from being installed
rm -f /etc/apt/sources.list.d/debian-sid.list
apt-get update ||:
