#!/bin/bash -e
################################################################################
##  File:  configure-environment-docker.sh
##  Desc:  Docker-safe version of configure-environment.sh.
##         Skips Azure VM-specific parts: waagent, cloud-init, grub, systemctl.
################################################################################

source $HELPER_SCRIPTS/os.sh
source $HELPER_SCRIPTS/etc-environment.sh

set_etc_environment_variable "ImageVersion" "${IMAGE_VERSION}"
set_etc_environment_variable "ImageOS" "${IMAGE_OS}"
set_etc_environment_variable "ACCEPT_EULA" "Y"

mkdir -p /etc/skel/.config/configstore
set_etc_environment_variable "XDG_CONFIG_HOME" '$HOME/.config'

# IPv6 localhost alias.
# /etc/hosts is a read-only bind mount during `docker build`, so it cannot be edited
# in the build layer at all. This is a cosmetic alias; skip it if the file is not writable.
# (Docker manages /etc/hosts per-container at runtime anyway.)
if [ -w /etc/hosts ]; then
    tmp_hosts=$(mktemp)
    sed 's/::1 ip6-localhost ip6-loopback/::1     localhost ip6-localhost ip6-loopback/g' /etc/hosts > "$tmp_hosts"
    cat "$tmp_hosts" > /etc/hosts
    rm -f "$tmp_hosts"
else
    echo "Skipping /etc/hosts IPv6 alias: read-only during docker build"
fi

# Tool cache directory
AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
mkdir -p $AGENT_TOOLSDIRECTORY
set_etc_environment_variable "AGENT_TOOLSDIRECTORY" "${AGENT_TOOLSDIRECTORY}"
set_etc_environment_variable "RUNNER_TOOL_CACHE" "${AGENT_TOOLSDIRECTORY}"
chmod -R 777 $AGENT_TOOLSDIRECTORY

# Write sysctl settings to file; apply at container runtime if host kernel permits
# (sysctl calls inside a Docker build layer do not persist anyway)
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_watches=655360' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_instances=1280' >> /etc/sysctl.conf
echo 'vm.mmap_rnd_bits=28' >> /etc/sysctl.conf

# Write udev rules for completeness (not applied in Docker, but preserved for parity)
mkdir -p /etc/udev/rules.d
echo 'ACTION=="add", SUBSYSTEM=="module", KERNEL=="nf_conntrack", RUN+="/usr/sbin/sysctl net.netfilter.nf_conntrack_tcp_be_liberal=1"' \
    > /etc/udev/rules.d/50-netfilter.rules
if ! is_ubuntu22; then
    echo 'ACTION=="add|change", KERNEL=="sd*|nvme*n*", ATTR{queue/read_ahead_kb}="128"' \
        > /etc/udev/rules.d/99-readahead.rules
fi

# invoke_tests symlink: install scripts call this for in-place validation.
# In the Dockerfile we install a no-op stub so those calls succeed silently
# and Pester tests are run separately (see test.sh).
chmod +x $HELPER_SCRIPTS/invoke-tests.sh
ln -sf /usr/local/bin/invoke_tests /usr/local/bin/invoke_tests 2>/dev/null || true

# Disable motd-news periodic updates
sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news || true

# Suppress man-db auto-update on package install (saves minutes per apt-get)
echo "set man-db/auto-update false" | debconf-communicate || true
dpkg-reconfigure man-db || true
