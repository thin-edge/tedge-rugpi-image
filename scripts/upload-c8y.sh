#!/usr/bin/env bash
set -e
LATEST=

if [ $# -gt 0 ]; then
    LATEST="$1"
fi

unset -v LATEST
for file in "build"/*; do
  [[ "$file" -nt "$LATEST" ]] && LATEST=$file
done

FIRMWARE_NAME=$(basename "$LATEST" | rev | cut -d_ -f2- | rev)
VERSION=$(echo "$LATEST" | sed 's/.*_//g' | sed 's/.img.xz//g')

if [ -z "$VERSION" ]; then
    echo "Could not detect version"
    exit
fi

c8y firmware get --id "$FIRMWARE_NAME" 2>/dev/null || {
    echo "Creating firmware: $FIRMWARE_NAME"
    c8y firmware create --name "$FIRMWARE_NAME"
}

c8y firmware versions create --firmware "$FIRMWARE_NAME" --file "$LATEST" --version "$VERSION"
