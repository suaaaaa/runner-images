#!/bin/bash -e
################################################################################
##  File:  install-docker-docker.sh
##  Desc:  Docker-safe wrapper for install-docker.sh.
##         Neutralizes operations that need a running init system or docker
##         daemon at build time, so the CLI + plugins still get installed:
##           - systemctl / systemd-tmpfiles  -> replaced by `true` (keeps
##             if/then/fi structure intact; `true` ignores trailing args)
##           - docker info / docker pull      -> replaced by `true`
##           - sleep N (daemon warm-up wait)  -> replaced by `true`
################################################################################

PATCHED=$(mktemp)

sed \
    -e 's/systemd-tmpfiles/true/g' \
    -e 's/systemctl/true/g' \
    -e 's/^\([[:space:]]*\)docker info[[:space:]]*$/\1true/' \
    -e 's/^\([[:space:]]*\)docker pull .*/\1true/' \
    -e 's/^\([[:space:]]*\)sleep [0-9].*/\1true/' \
    "$INSTALLER_SCRIPT_FOLDER/install-docker.sh" > "$PATCHED"

chmod +x "$PATCHED"
HELPER_SCRIPTS="$HELPER_SCRIPTS" INSTALLER_SCRIPT_FOLDER="$INSTALLER_SCRIPT_FOLDER" bash "$PATCHED"
rm "$PATCHED"
