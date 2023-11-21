#!/bin/bash
set -e
echo "Creating Software Bill Of Materials"
if [ -n "$RECIPE_DIR" ]; then
    dpkg --list > "$RECIPE_DIR/debian-packages.list"
else
    dpkg --list
fi
