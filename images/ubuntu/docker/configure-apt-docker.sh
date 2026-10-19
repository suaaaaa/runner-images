#!/bin/bash -e
################################################################################
##  File:  configure-apt-docker.sh
##  Desc:  Docker-safe version of configure-apt.sh.
##         Skips systemctl apt-daily timer management (no init system in Docker).
################################################################################

source $HELPER_SCRIPTS/os.sh

if is_ubuntu22_arm64 || is_ubuntu24_arm64; then
    apt_retries=3
    apt_timeout=30
else
    apt_retries=1
    apt_timeout=15
fi

cat <<EOF > /etc/apt/apt.conf.d/zz-retries
Acquire::Retries "$apt_retries";
Acquire::http::Timeout "$apt_timeout";
Acquire::https::Timeout "$apt_timeout";
EOF

echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes
echo 'APT::Get::Always-Include-Phased-Updates "true";' > /etc/apt/apt.conf.d/99-phased-updates
echo 'Acquire::IndexTargets::deb::DEP-11::DefaultEnabled "false";' > /etc/apt/apt.conf.d/90-index-targets

cat <<EOF >> /etc/apt/apt.conf.d/99bad_proxy
Acquire::http::Pipeline-Depth 0;
Acquire::http::No-Cache true;
Acquire::https::Pipeline-Depth 0;
Acquire::https::No-Cache true;
Acquire::BrokenProxy    true;
EOF

# unattended-upgrades is not installed in the base Docker image, ignore if absent
apt-get purge -y unattended-upgrades || true

echo 'APT sources'
if is_ubuntu22; then
    cat /etc/apt/sources.list
else
    cat /etc/apt/sources.list.d/ubuntu.sources
fi

echo 'APT mirrors'
cat /etc/apt/apt-mirrors.txt

apt-get update
apt-get upgrade -y
apt-get install -y jq
