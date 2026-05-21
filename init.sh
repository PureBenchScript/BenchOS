#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nodequality_root="/opt/nodequality"
nodequality_modules_dir="$nodequality_root/modules"

apt-get update
apt-get install -y ca-certificates curl git jq dnsutils bc procps dmidecode lm-sensors pciutils smartmontools fio sysbench iproute2 netcat-openbsd imagemagick mtr-tiny iperf3 stun

install_nodequality_runtime() {
    mkdir -p "$nodequality_root/common" "$nodequality_root/bin" "$nodequality_modules_dir"

    install -m 0644 "$script_dir/common/runtime.sh" "$nodequality_root/common/runtime.sh"
    install -m 0755 "$script_dir/bin/nq-run-module" "$nodequality_root/bin/nq-run-module"
    install -m 0755 "$script_dir/bin/nq-hardware" /usr/local/bin/nq-hardware
    install -m 0755 "$script_dir/bin/nq-ip" /usr/local/bin/nq-ip
    install -m 0755 "$script_dir/bin/nq-net" /usr/local/bin/nq-net
}

install_quality_module() {
    local name="$1"
    local repo="$2"
    local target="$nodequality_modules_dir/$name"
    local local_source="/tmp/local-modules/$name"

    rm -rf "$target"
    if [[ -d "$local_source" ]]; then
        mkdir -p "$target"
        cp -a "$local_source/." "$target/"
    else
        git clone --depth 1 "$repo" "$target"
    fi
}

install_netquality_tools() {
    local arch
    local speedtest_src=""
    arch="$(uname -m)"

    case "$arch" in
        x86_64|amd64)
            speedtest_src="$nodequality_modules_dir/NetQuality/ref/speedtest/speedtest-x86_64"
            curl -fsSL -o /usr/local/bin/nexttrace https://github.com/nxtrace/NTrace-core/releases/download/v1.3.7/nexttrace_linux_amd64
            ;;
        i386|i686)
            speedtest_src="$nodequality_modules_dir/NetQuality/ref/speedtest/speedtest-i386"
            curl -fsSL -o /usr/local/bin/nexttrace https://github.com/nxtrace/NTrace-core/releases/download/v1.3.7/nexttrace_linux_386
            ;;
        aarch64|arm64)
            speedtest_src="$nodequality_modules_dir/NetQuality/ref/speedtest/speedtest-aarch64"
            curl -fsSL -o /usr/local/bin/nexttrace https://github.com/nxtrace/NTrace-core/releases/download/v1.3.7/nexttrace_linux_arm64
            ;;
    esac

    if [[ -n "$speedtest_src" && -f "$speedtest_src" ]]; then
        install -m 0755 "$speedtest_src" /usr/local/bin/speedtest
    fi
    chmod 0755 /usr/local/bin/nexttrace 2>/dev/null || true
}

install_nodequality_modules() {
    install_quality_module HardwareQuality https://github.com/PureBenchScript/HardwareQuality.git
    install_quality_module IPQuality https://github.com/PureBenchScript/IPQuality.git
    install_quality_module NetQuality https://github.com/PureBenchScript/NetQuality.git
    install_netquality_tools
}

install_nodequality_runtime
install_nodequality_modules

# cleanup
rm -rf /var/lib/apt/lists/*

echo "Init inside chroot complete"
