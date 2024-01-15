#!/usr/bin/env bash
set -e

ENV_FILE=".env"

if [ -d ~/.ssh ]; then
    echo "Looking for public keys in ~/.ssh" >&2
    
    for file in ~/.ssh/*.pub; do
        CONTENTS=$(head -n1 "$file" | tr -d '\r\n')
        
        if grep -qF "$CONTENTS" "$ENV_FILE"; then
            echo "Key ($file) already exists in $ENV_FILE"
        else
            echo "Adding $file" >&2
            ssh_id=$(basename "$file" | md5sum | cut -d' ' -f1)
            echo SSH_KEYS_"$ssh_id"=\""$CONTENTS"\" >> "$ENV_FILE"
        fi
    done
fi
