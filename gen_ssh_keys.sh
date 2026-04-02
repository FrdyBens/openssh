#!/bin/bash
set -e
USERNAME=${1:-openssh}
OUTDIR=${2:-/keys}

mkdir -p "$OUTDIR"

# Check if keys already exist to prevent overwriting on container restart
if [ -f "$OUTDIR/$USERNAME" ]; then
    echo "SSH keys for $USERNAME already exist in $OUTDIR. Skipping generation."
    exit 0
fi

ssh-keygen -t ed25519 -C "$USERNAME" -f "$OUTDIR/$USERNAME" -N "" >/dev/null 2>&1
chmod 600 "$OUTDIR/$USERNAME"
chmod 644 "$OUTDIR/$USERNAME.pub"

echo "Keys generated for $USERNAME in $OUTDIR"
