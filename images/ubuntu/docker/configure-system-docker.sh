#!/bin/bash -e
################################################################################
##  File:  configure-system-docker.sh
##  Desc:  Docker-safe version of configure-system.sh.
##         Guards the needrestart config with a file existence check
##         (needrestart may or may not be installed in the container).
################################################################################

source $HELPER_SCRIPT_FOLDER/etc-environment.sh
source $HELPER_SCRIPT_FOLDER/os.sh

mv -f /imagegeneration/post-generation /opt

echo "chmod -R 777 /usr/share"
chmod -R 777 /usr/share
echo "chmod -R 777 /opt"
chmod -R 777 /opt

echo "Setting sticky bit on hostedtoolcache Ruby directories"
if [ -d /opt/hostedtoolcache/Ruby ]; then
    find /opt/hostedtoolcache/Ruby -type d -exec chmod +t {} +
fi

chmod 755 $IMAGE_FOLDER

ENVPATH=$(grep 'PATH=' /etc/environment | head -n 1 | sed -z 's/^PATH=*//')
ENVPATH=${ENVPATH#"\""}
ENVPATH=${ENVPATH%"\""}
replace_etc_environment_variable "PATH" "${ENVPATH}"
echo "Updated /etc/environment: $(cat /etc/environment)"

if yarn --version > /dev/null 2>&1; then
    yarn cache clean
fi

if npm --version > /dev/null 2>&1; then
    npm cache clean --force
fi

if ! is_ubuntu22 && [[ -f "/etc/needrestart/needrestart.conf" ]]; then
    sed -i '/^\s*};/i \    qr(^runner-provisioner) => 0,' /etc/needrestart/needrestart.conf
fi
