#!/bin/bash -e

# install thin-edge.io
curl -fsSL https://thin-edge.io/install.sh | sh -s

# Install collectd
apt-get install -y --no-install-recommends collectd-core mosquitto-clients
cp /etc/tedge/contrib/collectd/collectd.conf /etc/collectd/collectd.conf

# custom tedge configuration
tedge config set apt.name "(tedge|c8y|python|wget|vim|curl|apt|mosquitto|ssh|sudo).*"

# setup thin-edge.io community repository
curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/setup.deb.sh' | bash
apt-get update
apt-get install -y c8y-command-plugin

# Enable network manager by default
systemctl enable NetworkManager || true

# Enable services by default to have sensible default settings once tedge is configured
systemctl enable tedge-agent
systemctl enable tedge-mapper-c8y
systemctl enable tedge-mapper-collectd
systemctl enable collectd

