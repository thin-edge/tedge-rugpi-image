#!/bin/sh
set -eu

install -D -m 755 "${RECIPE_DIR}/files/tedge-identity" -t /usr/bin/tedge-identity
install -D -m 755 "${RECIPE_DIR}/files/tedge-bootstrap" -t /usr/bin/tedge-bootstrap
