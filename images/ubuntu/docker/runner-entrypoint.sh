#!/bin/bash
set -e

# Load /etc/environment (set by image build scripts)
set -a
source /etc/environment 2>/dev/null || true
set +a

# ── Docker-in-Docker ──────────────────────────────────────────────────────────
# Set DOCKER_IN_DOCKER=true and run with --privileged to enable DinD.
if [ "${DOCKER_IN_DOCKER:-false}" = "true" ]; then
    echo "[entrypoint] Starting Docker daemon..."
    mkdir -p /var/log
    dockerd \
        --host=unix:///var/run/docker.sock \
        --storage-driver=overlay2 \
        > /var/log/dockerd.log 2>&1 &

    echo "[entrypoint] Waiting for Docker daemon..."
    timeout 60 sh -c 'until docker info > /dev/null 2>&1; do sleep 1; done' || {
        echo "[entrypoint] Docker daemon failed to start:"
        cat /var/log/dockerd.log
        exit 1
    }
    echo "[entrypoint] Docker daemon ready."
fi

# ── GitHub Actions runner ─────────────────────────────────────────────────────
# Required env vars:
#   RUNNER_URL    — e.g. https://github.com/my-org  or  https://github.com/my-org/my-repo
#   RUNNER_TOKEN  — registration token from GitHub (Settings → Actions → Runners → New runner)
# Optional:
#   RUNNER_NAME    (default: container hostname)
#   RUNNER_LABELS  (default: self-hosted,Linux,X64,ubuntu-24.04)
#   RUNNER_WORKDIR (default: /home/runner/work)

RUNNER_HOME="${RUNNER_HOME:-/home/runner/actions-runner}"

if [ -n "${RUNNER_TOKEN}" ] && [ -n "${RUNNER_URL}" ]; then
    cd "$RUNNER_HOME"

    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        DEFAULT_LABELS="self-hosted,Linux,X64,ubuntu-24.04"
    else
        DEFAULT_LABELS="self-hosted,Linux,ARM64,ubuntu-24.04"
    fi

    echo "[entrypoint] Configuring runner for ${RUNNER_URL}..."
    ./config.sh \
        --url "${RUNNER_URL}" \
        --token "${RUNNER_TOKEN}" \
        --name "${RUNNER_NAME:-$(hostname)}" \
        --labels "${RUNNER_LABELS:-$DEFAULT_LABELS}" \
        --work "${RUNNER_WORKDIR:-$RUNNER_HOME/_work}" \
        --unattended \
        --replace

    cleanup() {
        echo "[entrypoint] Deregistering runner..."
        ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || true
    }
    trap cleanup EXIT SIGTERM SIGINT

    echo "[entrypoint] Runner starting."
    ./run.sh
else
    echo "[entrypoint] RUNNER_TOKEN or RUNNER_URL not set — dropping to shell."
    exec "$@"
fi
