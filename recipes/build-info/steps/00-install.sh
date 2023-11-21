#!/bin/sh
set -e

BUILD_INFO_HOST="$RECIPE_DIR/files/.build_info"
BUILD_INFO_TARGET=/etc/.build_info

if [ -f "$BUILD_INFO_HOST" ]; then
    echo "Adding build-info: $BUILD_INFO_TARGET"
    cat "$BUILD_INFO_HOST" > "$BUILD_INFO_TARGET"
fi
