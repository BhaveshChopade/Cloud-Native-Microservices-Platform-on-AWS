#!/bin/bash
# ------------------------------------------------------------------------------
# [Role]        K3s Master Node Bootstrap (Armored + Network Safe)
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


# --- Disable IPv6 early ---
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1" \
| sudo tee /etc/sysctl.d/99-disable-ipv6.conf
sudo sysctl --system

# --- Logging ---
exec > >(sudo tee /var/log/k3s-master.log) 2>&1
echo "==> [START] K3s Master Bootstrap"

# --- Wait for network (CRITICAL) ---
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

# --- APT update with retries (NON-FATAL) ---
echo "==> Updating apt (retry-safe)..."
  retry sudo apt-get update


# --- Install deps with retries ---
echo "==> Installing dependencies..."

 retry apt-get install -y curl unzip
   


#-----CA immutability and installer can never re-run and CA can never be regenerated---------
K3S_SERVER_DIR="/var/lib/rancher/k3s/server"

if sudo test -d "${K3S_SERVER_DIR}"; then
  echo "==> K3s server directory already exists. Skipping install to preserve CA."
  exit 0
fi

# --- Stable identity ---
NODE_IP=$(retry curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# --- Install K3s SERVER ---
curl -sfL https://get.k3s.io | sudo sh -s - server \
  --node-ip="$NODE_IP" \
  --advertise-address="$NODE_IP" \
  --tls-san="$NODE_IP" \
  --write-kubeconfig-mode 644 \
  --disable-cloud-controller
