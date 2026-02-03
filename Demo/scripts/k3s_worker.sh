#!/bin/bash
# ------------------------------------------------------------------------------
# [Role]        K3s Worker Node Bootstrap (Armored + Network Safe)
# ------------------------------------------------------------------------------

set -euo pipefail

retry() {
  local retries=10
  local delay=10
  local n=1

  until "$@"; do
    if [ "$n" -ge "$retries" ]; then
      echo "Command failed after $n attempts: $*"
      return 1
    fi
    echo "Command failed. Attempt $n/$retries. Retrying ..."
    n=$((n+1))
    sleep "$delay"
  done
}

# --- Disable IPv6 ---
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1" \
| sudo tee /etc/sysctl.d/99-disable-ipv6.conf
sudo sysctl --system

# --- Logging ---
exec > >(sudo tee /var/log/k3s-worker.log) 2>&1
echo "==> [START] K3s Worker Bootstrap"

# Stop any stale agent
systemctl stop k3s-agent || true

# FULL reset to avoid CA poisoning
rm -rf /var/lib/rancher
rm -rf /run/k3s
rm -f /etc/systemd/system/k3s-agent.service*

systemctl daemon-reexec
systemctl daemon-reload


# --- Wait for network ---
echo "==> Waiting for network-online.target..."
sudo systemctl is-active --wait network-online.target

# --- APT lock waiter ---
wait_for_apt_lock() {
  while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
        sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
        pgrep -f "apt" >/dev/null 2>&1; do
    echo "Waiting for apt lock..."
    sleep 5
  done
}

export DEBIAN_FRONTEND=noninteractive

# --- Enforce mirrors ---
sudo rm -f /etc/apt/sources.list
sudo tee /etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: https://archive.ubuntu.com/ubuntu
Suites: jammy jammy-updates jammy-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://security.ubuntu.com/ubuntu
Suites: jammy-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

# --- Stop auto-upgrades ---
sudo systemctl stop unattended-upgrades || true
wait_for_apt_lock

# --- APT update (retry-safe) ---
echo "==> Updating apt..."
retry sudo apt-get update

# --- Install deps ---
echo "==> Installing dependencies..."

retry sudo apt-get install -y curl unzip
  
