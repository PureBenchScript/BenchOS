#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl git

# cleanup
rm -rf /var/lib/apt/lists/*

echo "Init inside chroot complete"
