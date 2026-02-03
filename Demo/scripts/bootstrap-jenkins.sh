#!/usr/bin/env bash
set -euo pipefail


sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo -e "net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1" \
| sudo tee /etc/sysctl.d/99-disable-ipv6.conf

sudo sysctl --system

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------
sudo mkdir -p /var/log
exec > >(sudo tee /var/log/bootstrap-jenkins.log) 2>&1

export DEBIAN_FRONTEND=noninteractive

echo "==> Bootstrap started at $(date)"

# ------------------------------------------------------------------------------
# Base packages
# ------------------------------------------------------------------------------


sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

# ------------------------------------------------------------------------------
# Ensure keyrings directory (Ubuntu 22.04 requirement)
# ------------------------------------------------------------------------------
sudo mkdir -p /etc/apt/keyrings
sudo chmod 0755 /etc/apt/keyrings

# ------------------------------------------------------------------------------
# Docker installation
# ------------------------------------------------------------------------------
echo "==> Installing Docker"

sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu jammy stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

# ------------------------------------------------------------------------------
# Java 17 (Jenkins runtime requirement)
# ------------------------------------------------------------------------------
echo "==> Installing Java 17"

sudo apt-get install -y openjdk-17-jre-headless

java -version
java -version 2>&1 | grep -q '17\.' || exit 1

# ------------------------------------------------------------------------------
# Jenkins signing key (extract actual repo signer)
# ------------------------------------------------------------------------------
echo "==> Resolving Jenkins signing key"

sudo rm -f /etc/apt/keyrings/jenkins.gpg
sudo rm -f /etc/apt/sources.list.d/jenkins.list

JENKINS_KEY_ID="$(curl -fsSL https://pkg.jenkins.io/debian-stable/binary/Release.gpg \
| gpg --list-packets \
| awk '/keyid/ {print $NF; exit}')"

[ -n "$JENKINS_KEY_ID" ]

echo "==> Jenkins signing key: $JENKINS_KEY_ID"

gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$JENKINS_KEY_ID"

gpg --export "$JENKINS_KEY_ID" \
| sudo gpg --dearmor -o /etc/apt/keyrings/jenkins.gpg

sudo chmod a+r /etc/apt/keyrings/jenkins.gpg

gpg --show-keys --with-fingerprint /etc/apt/keyrings/jenkins.gpg

# ------------------------------------------------------------------------------
# Jenkins repository
# ------------------------------------------------------------------------------
echo "==> Adding Jenkins repository"

echo "deb [signed-by=/etc/apt/keyrings/jenkins.gpg] \
https://pkg.jenkins.io/debian-stable binary/" \
| sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update

# ------------------------------------------------------------------------------
# Jenkins installation
# ------------------------------------------------------------------------------
echo "==> Installing Jenkins"

sudo apt-get install -y jenkins
sudo systemctl enable jenkins

# ------------------------------------------------------------------------------
# Trivy installation
# ------------------------------------------------------------------------------
echo "==> Installing Trivy"

sudo rm -f /etc/apt/keyrings/trivy.gpg
sudo rm -f /etc/apt/sources.list.d/trivy.list

curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
| sudo gpg --dearmor -o /etc/apt/keyrings/trivy.gpg

sudo chmod a+r /etc/apt/keyrings/trivy.gpg

echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb jammy main" \
| sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

sudo apt-get update
sudo apt-get install -y trivy


# ------------------------------------------------------------------------------
# Docker access for Jenkins
# ------------------------------------------------------------------------------
echo "==> Granting Docker access to Jenkins"

sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins


# ------------------------------------------------------------------------------
# Start Jenkins cleanly
# ------------------------------------------------------------------------------
sudo systemctl reset-failed jenkins
sudo systemctl start jenkins
sudo systemctl is-active jenkins

echo "==> Bootstrap completed successfully at $(date)"

