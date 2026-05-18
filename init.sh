#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl git jq dnsutils bc procps dmidecode lm-sensors pciutils smartmontools fio sysbench iproute2 netcat-openbsd imagemagick mtr-tiny iperf3 stun

# cleanup
rm -rf /var/lib/apt/lists/*

echo "Init inside chroot complete"
