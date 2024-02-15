#!/usr/bin/env bash
#
# Publish a release by creating the firmware and versions in Cumulocity
# and link to the github artifact (rather than hosting the artifact in c8y itself)
#
# Dependencies:
# * gh
# * go-c8y-cli
#

set -e

help() {
    cat << EOT
Publish github releases

USAGE
    $0 <TAG> [OPTIONS]

FLAGS
    --pre-release       Publish release as a pre-release (only if it set to draft)

EXAMPLES
    $0 1.0.0 --pre-release

EOT
}

# Defaults
PRE_RELEASE=0

# Parse arguments
REST_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            help
            exit 0
            ;;

        --pre-release)
            PRE_RELEASE=1
            ;;

        *)
            REST_ARGS+=("$1")
            ;;
    esac
    shift
done

# Only set if rest arguments are defined
if [ ${#REST_ARGS[@]} -gt 0 ]; then
    set -- "${REST_ARGS[@]}"
fi

TAG=
if [ $# -eq 0 ]; then
    echo "Missing required argument" >&2
    help
    exit 1
fi
TAG="$1"

publish_version() {
    url="$1"
    filename=$(basename "$url")
    VERSION=$(echo "$filename" | sed 's/.img.xz$//' | rev | cut -d_ -f1 | rev)
    NAME=$(echo "$filename" | rev | cut -d_ -f2- | rev)
    DEVICE_TYPE=$NAME
    #echo "name=$NAME, version=$VERSION, url=$url" >&2

    if [ -z "$NAME" ] || [ -z "$VERSION" ] || [ -z "$url" ]; then
        echo "Missing required information. Non empty values are required for name, version and url" >&2
        return 1
    fi

    if [ -n "$NAME" ] && [ -n "$VERSION" ] && [ -n "$url" ]; then
        # Create/Update firmware name (if it does not already exist)
        if c8y firmware get -n --id "$NAME"  >/dev/null 2>&1; then
            c8y firmware update -n --id "$NAME" --deviceType "$DEVICE_TYPE" --delay "1s" --force 
        else
            c8y firmware create -n --name "$NAME" --deviceType "$DEVICE_TYPE" --delay "1s" --force
        fi
        # create version if it does not already exist
        if ! c8y firmware versions get -n --firmware "$NAME" --id "$VERSION" >/dev/null 2>&1; then
            c8y firmware versions create -n --firmware "$NAME" --version "$VERSION" --url "$url" --force
        else
            echo "Version already exists. firmware=$NAME, version=$VERSION, url=$url" >&2
        fi
    fi
}

# Set from draft to pre-release
if [[ $PRE_RELEASE = 1 ]]; then
    IS_DRAFT=$(gh release view "$TAG" --json isDraft  --template "{{.isDraft}}")
    if [ "$IS_DRAFT" = "true" ]; then
        echo "Update $TAG to prerelease."
        gh release edit --draft=false --prerelease "$TAG"
    fi
    sleep 3
    IS_PRERELEASE=$(gh release view "$TAG" --json isPrerelease --template "{{.isPrerelease}}")
    if ! [ "$IS_PRERELEASE" = "true" ]; then
        echo "Could not update $TAG to prerelease. Exiting."
        exit 5
    fi
fi
# Get assets from given tag
FILES=$(gh release view "$TAG" --json assets --jq '.assets[].url' | grep ".xz")

# publish each version found
for file in $FILES; do
    publish_version "$file"
done
