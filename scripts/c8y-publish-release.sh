#!/usr/bin/env bash
#
# Publish a release by creating the firmware and versions in Cumulocity
# and link to the github artifact (rather than hosting the artifact in c8y itself)
#
# Dependencies:
# * gh
# * go-c8y-cli
#
if [ $# -eq 0 ]; then
    echo "missing required positional argument: TAG" >&2
    echo
    echo "Usage:"
    echo
    echo "    $0 <TAG>"
    echo
    exit 1
fi

TAG="$1"

publish_version() {
    url="$1"
    filename=$(basename "$url")
    VERSION=$(echo "$filename" | sed 's/.img.xz$//' | rev | cut -d_ -f1 | rev)
    NAME=$(echo "$filename" | rev | cut -d_ -f2- | rev)
    #echo "name=$NAME, version=$VERSION, url=$url" >&2

    if [ -z "$NAME" ] || [ -z "$VERSION" ] || [ -z "$url" ]; then
        echo "Missing required information. Non empty values are required for name, version and url" >&2
        return 1
    fi

    # Create software name (if it does not already exist)
    c8y firmware get -n --id "$NAME" --silentStatusCodes 404 >/dev/null || c8y firmware create -n --name "$NAME" --delay "1s" --force

    if [ -n "$NAME" ] && [ -n "$VERSION" ] && [ -n "$url" ]; then
        # create version if it does not already exist
        if ! c8y firmware versions get -n --firmware "$NAME" --id "$VERSION" >/dev/null 2>&1; then
            c8y firmware versions create -n --firmware "$NAME" --version "$VERSION" --url "$url" --force
        else
            echo "Version already exists. firmware=$NAME, version=$VERSION, url=$url" >&2
        fi
    fi
}

# Get assets from given tag
FILES=$(gh release view "$TAG" --json assets --jq '.assets[].url' | grep ".xz")

# publish each version found
for file in $FILES; do
    publish_version "$file"
done
