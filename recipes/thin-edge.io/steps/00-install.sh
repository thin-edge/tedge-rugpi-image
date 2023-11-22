#!/bin/bash -e

# install thin-edge.io
curl -fsSL https://thin-edge.io/install.sh | sh -s -- --channel main

# Install collectd
apt-get install -y --no-install-recommends \
    mosquitto-clients \
    c8y-command-plugin \
    tedge-collectd-setup \
    tedge-monit-setup \
    tedge-inventory-plugin

# custom tedge configuration
tedge config set apt.name "(tedge|c8y|python|wget|vim|curl|apt|mosquitto|ssh|sudo).*"


# Enable network manager by default
systemctl enable NetworkManager || true

# Enable services by default to have sensible default settings once tedge is configured
systemctl enable tedge-agent
systemctl enable tedge-mapper-c8y
systemctl enable tedge-mapper-collectd
systemctl enable collectd

# Custom mosquitto configuration
install -D -m 644 "${RECIPE_DIR}/files/custom.conf" -t /etc/tedge/mosquitto-conf/

# TODO: should overlay be persisted by default, otherwise someone can accidentally disable a service
# and leave it off, however otherwise it is a bit harder to control services during runtime
#rugpi-ctrl state overlay set-persist true
