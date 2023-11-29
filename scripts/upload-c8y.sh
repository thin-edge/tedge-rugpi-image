#!/usr/bin/env bash
set -e
LATEST=
FIRMWARE=tedge_rugpi_45

if [ $# -gt 0 ]; then
    LATEST="$1"
fi

unset -v LATEST
for file in "build"/*; do
  [[ "$file" -nt "$LATEST" ]] && LATEST=$file
done

VERSION=$(echo "$LATEST" | sed 's/.*_//g' | sed 's/.img.xz//g')

if [ -z "$VERSION" ]; then
    echo "Could not detect version"
    exit
fi

c8y firmware versions create --firmware "$FIRMWARE" --file "$LATEST" --version "$VERSION"
