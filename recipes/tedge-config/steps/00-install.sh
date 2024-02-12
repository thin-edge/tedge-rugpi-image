#!/bin/bash
set -e

if [ -n "$RECIPE_PARAM_MQTT_BIND_ADDRESS" ]; then
    echo "Setting mqtt.bind.address to $RECIPE_PARAM_MQTT_BIND_ADDRESS" >&2
    tedge config set mqtt.bind.address "$RECIPE_PARAM_MQTT_BIND_ADDRESS"
fi
