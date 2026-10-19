################################################################################
# GitHub Actions ubuntu-24.04 self-hosted runner image
#
# Build context: images/ubuntu/
#   docker build -t ubuntu2404-runner:latest images/ubuntu/
#
# Optional build args:
#   IMAGE_VERSION   — embedded in /imagegeneration/imagedata.json  (default: dev)
#   RUNNER_VERSION  — actions/runner release tag without 'v'       (default: latest)
#
# Runtime env vars (required to start the runner):
#   RUNNER_URL    — https://github.com/<org>  or  https://github.com/<org>/<repo>
#   RUNNER_TOKEN  — registration token from GitHub Settings → Actions → Runners
#
# Runtime env vars (optional):
#   RUNNER_NAME       — defaults to container hostname
#   RUNNER_LABELS     — defaults to "self-hosted,Linux,X64,ubuntu-24.04"
#   RUNNER_WORKDIR    — defaults to /home/runner/actions-runner/_work
#   DOCKER_IN_DOCKER  — set to "true" + run with --privileged to enable DinD
#
# Example run:
#   docker run --privileged \
#     -e RUNNER_URL=https://github.com/my-org \
#     -e RUNNER_TOKEN=<token> \
#     -e DOCKER_IN_DOCKER=true \
#     ubuntu2404-runner:latest
################################################################################

FROM ubuntu:24.04

ARG IMAGE_VERSION=dev
ARG IMAGE_OS=ubuntu24

# ── Core environment variables ────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_OS=${IMAGE_OS} \
    ImageVersion=${IMAGE_VERSION} \
    ImageOS="Linux" \
    IMAGE_TARGET_PLATFORM="GitHub" \
    POWERSHELL_DISTRIBUTION_CHANNEL="GitHub-Actions-Linux" \
    # Canonical paths used by all build scripts (match Packer variable defaults)
    IMAGE_FOLDER=/imagegeneration \
    IMAGEDATA_FILE=/imagegeneration/imagedata.json \
    HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache \
    RUNNER_TOOL_CACHE=/opt/hostedtoolcache \
    NVM_DIR=/etc/skel/.nvm \
    # Allow the actions runner to run as root inside the container
    RUNNER_ALLOW_RUNASROOT=1

# ── Bootstrap ─────────────────────────────────────────────────────────────────
# Mark as container environment (checked by os.sh helpers in several scripts)
RUN mkdir -p /imagegeneration && chmod 777 /imagegeneration && \
    touch /run/.containerenv && \
    # Base tools the build scripts assume exist on an Azure Ubuntu image but which the
    # stock ubuntu:24.04 image does not ship: sudo (scripts use `sudo tee`), lsb-release
    # (os.sh / install-ms-repos.sh call lsb_release), plus wget/curl/gpg for repo setup.
    apt-get update && apt-get install -y --no-install-recommends \
        sudo lsb-release ca-certificates curl wget gnupg apt-transport-https \
        software-properties-common jq dpkg && \
    rm -rf /var/lib/apt/lists/*

# ── Copy sources ──────────────────────────────────────────────────────────────
COPY scripts/helpers            /imagegeneration/helpers/
COPY scripts/build              /imagegeneration/installers/
COPY toolsets/toolset-2404.json /imagegeneration/installers/toolset.json
COPY assets/post-gen            /imagegeneration/post-generation/
COPY scripts/tests              /imagegeneration/tests/
COPY scripts/docs-gen           /imagegeneration/SoftwareReport/
COPY docker/                    /imagegeneration/docker/

RUN find /imagegeneration/installers /imagegeneration/helpers /imagegeneration/docker \
        -name "*.sh" -type f -exec chmod +x {} \; && \
    # No-op stub: individual install scripts call invoke_tests for Pester validation.
    # Skip those in-build test runs; run them separately with test.sh after the image is built.
    printf '#!/bin/bash\nexit 0\n' > /usr/local/bin/invoke_tests && \
    chmod +x /usr/local/bin/invoke_tests

# ── Step 1: apt lock-retry mock ───────────────────────────────────────────────
RUN /imagegeneration/installers/configure-apt-mock.sh

# ── Step 2: Microsoft repos + apt sources ────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    DEBIAN_FRONTEND=noninteractive \
    /imagegeneration/installers/install-ms-repos.sh

# configure-apt-sources.sh writes /etc/apt/apt-mirrors.txt and patches ubuntu.sources.
# The Azure-mirror sed substitution is a no-op on stock Docker images but the mirrors
# file is still required by configure-apt-docker.sh.
RUN mkdir -p /etc/cloud/templates && \
    HELPER_SCRIPTS=/imagegeneration/helpers \
    /imagegeneration/installers/configure-apt-sources.sh

# ── Step 3: apt configuration (Docker-safe — no systemctl) ───────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    /imagegeneration/docker/configure-apt-docker.sh

# ── Step 4: system limits ─────────────────────────────────────────────────────
RUN /imagegeneration/installers/configure-limits.sh

# ── Step 5: image metadata file ───────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGEDATA_FILE=/imagegeneration/imagedata.json \
    /imagegeneration/installers/configure-image-data.sh

# ── Step 6: environment variables (Docker-safe — no Azure/grub/systemctl) ────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_OS=${IMAGE_OS} \
    /imagegeneration/docker/configure-environment-docker.sh

# ── Step 7: vital base packages ───────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    /imagegeneration/installers/install-apt-vital.sh

# ── Step 8: PowerShell ────────────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    /imagegeneration/installers/install-powershell.sh

# ── Step 9: PowerShell modules ────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    pwsh -f /imagegeneration/installers/Install-PowerShellModules.ps1 && \
    HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    pwsh -f /imagegeneration/installers/Install-PowerShellAzModules.ps1

# ── Step 10: Cloud/DevOps CLI tools ───────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-actions-cache.sh && \
    /imagegeneration/installers/install-apt-common.sh && \
    /imagegeneration/installers/install-azcopy.sh && \
    /imagegeneration/installers/install-azure-cli.sh && \
    /imagegeneration/installers/install-azure-devops-cli.sh && \
    /imagegeneration/installers/install-bicep.sh && \
    /imagegeneration/installers/install-apache.sh && \
    /imagegeneration/installers/install-aws-tools.sh'

# ── Step 11: Compilers and build tools ────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-clang.sh && \
    /imagegeneration/installers/install-swift.sh && \
    /imagegeneration/installers/install-cmake.sh && \
    /imagegeneration/installers/install-gcc-compilers.sh && \
    /imagegeneration/installers/install-gfortran.sh && \
    /imagegeneration/installers/install-ninja.sh'

# ── Step 12: Code analysis and container tools ────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-codeql-bundle.sh && \
    /imagegeneration/installers/install-awf.sh && \
    /imagegeneration/installers/install-container-tools.sh'

# ── Step 13: .NET and browsers ────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-dotnetcore-sdk.sh && \
    /imagegeneration/installers/install-microsoft-edge.sh && \
    /imagegeneration/installers/install-firefox.sh && \
    /imagegeneration/installers/install-google-chrome.sh'

# ── Step 14: VCS and cloud CLI tools ──────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-git.sh && \
    /imagegeneration/installers/install-git-lfs.sh && \
    /imagegeneration/installers/install-github-cli.sh && \
    /imagegeneration/installers/install-google-cloud-cli.sh && \
    /imagegeneration/installers/install-copilot-cli.sh'

# ── Step 15: Language runtimes (JVM / functional / mobile) ───────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-haskell.sh && \
    /imagegeneration/installers/install-java-tools.sh && \
    /imagegeneration/installers/install-kotlin.sh && \
    /imagegeneration/installers/install-julia.sh && \
    /imagegeneration/installers/install-miniconda.sh'

# ── Step 16: Infrastructure tools ─────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-kubernetes-tools.sh && \
    /imagegeneration/installers/install-packer.sh && \
    /imagegeneration/installers/install-pulumi.sh && \
    /imagegeneration/installers/install-vcpkg.sh'

# ── Step 17: Databases and servers ────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-mysql.sh && \
    /imagegeneration/installers/install-postgresql.sh && \
    /imagegeneration/installers/install-nginx.sh'

# ── Step 18: Node.js ecosystem (+ bazel, which needs npm) ─────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-nvm.sh && \
    /imagegeneration/installers/install-nodejs.sh && \
    /imagegeneration/installers/install-bazel.sh'

# ── Step 19: Python ecosystem ─────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-pypy.sh && \
    /imagegeneration/installers/install-python.sh && \
    /imagegeneration/installers/install-pipx-packages.sh'

# ── Step 20: Ruby and PHP ─────────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-ruby.sh && \
    /imagegeneration/installers/install-php.sh'

# ── Step 21: Rust ─────────────────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    /imagegeneration/installers/install-rust.sh

# ── Step 22: Test and packaging tools ─────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    bash -c '\
    /imagegeneration/installers/install-selenium.sh && \
    /imagegeneration/installers/install-zstd.sh && \
    /imagegeneration/installers/install-yq.sh'

# ── Step 23: Android SDK ──────────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    DEBIAN_FRONTEND=noninteractive \
    /imagegeneration/installers/install-android-sdk.sh

# ── Step 24: dpkg hardening ───────────────────────────────────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    /imagegeneration/installers/configure-dpkg.sh

# ── Step 25: Docker (patched — no systemctl / daemon start) ───────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    /imagegeneration/docker/install-docker-docker.sh

# ── Step 26: Toolset (PowerShell-managed tool versions) ───────────────────────
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    pwsh -f /imagegeneration/installers/Install-Toolset.ps1 && \
    HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    pwsh -f /imagegeneration/installers/Configure-Toolset.ps1

# ── Step 27: Homebrew (must run as non-root) ───────────────────────────────────
# Create a dedicated user; set_etc_environment_variable uses `sudo tee` internally.
RUN useradd -m -s /bin/bash linuxbrew && \
    echo "linuxbrew ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chmod -R a+rwx /imagegeneration/helpers /imagegeneration/installers

USER linuxbrew
ENV HOME=/home/linuxbrew
RUN NONINTERACTIVE=1 \
    HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    /imagegeneration/installers/install-homebrew.sh

USER root

# ── Step 28: Cleanup ──────────────────────────────────────────────────────────
# cleanup.sh runs `journalctl --rotate/--vacuum` guarded only by `command -v`,
# but there is no journald daemon in the container so those calls fail under
# `set -e`. Patch them to be best-effort at build time (keeps docker/ unchanged
# so earlier build-cache layers stay valid).
RUN HELPER_SCRIPTS=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    /imagegeneration/installers/list-dpkg.sh && \
    sed -e 's#\(journalctl --rotate\)#\1 || true#' \
        -e 's#\(journalctl --vacuum-time=1s\)#\1 || true#' \
        /imagegeneration/installers/cleanup.sh > /tmp/cleanup-docker.sh && \
    bash /tmp/cleanup-docker.sh && rm -f /tmp/cleanup-docker.sh

# ── Step 29: Final system configuration ───────────────────────────────────────
RUN HELPER_SCRIPT_FOLDER=/imagegeneration/helpers \
    INSTALLER_SCRIPT_FOLDER=/imagegeneration/installers \
    IMAGE_FOLDER=/imagegeneration \
    /imagegeneration/docker/configure-system-docker.sh

# ── Step 30: GitHub Actions runner binary ─────────────────────────────────────
ARG RUNNER_VERSION
RUN ARCH=$(dpkg --print-architecture) && \
    if   [ "$ARCH" = "amd64"  ]; then RUNNER_ARCH="x64"; \
    elif [ "$ARCH" = "arm64"  ]; then RUNNER_ARCH="arm64"; \
    else echo "Unsupported arch: $ARCH" && exit 1; fi && \
    if [ -z "$RUNNER_VERSION" ]; then \
        RUNNER_VERSION=$(curl -sfSL "https://api.github.com/repos/actions/runner/releases/latest" \
            | jq -r '.tag_name' | sed 's/v//'); \
    fi && \
    echo "Installing actions/runner v${RUNNER_VERSION} (${RUNNER_ARCH})" && \
    mkdir -p /home/runner/actions-runner && \
    cd /home/runner/actions-runner && \
    curl -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
        | tar -xz && \
    ./bin/installdependencies.sh

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker/runner-entrypoint.sh /opt/runner-entrypoint.sh
RUN chmod +x /opt/runner-entrypoint.sh

ENTRYPOINT ["/opt/runner-entrypoint.sh"]
CMD ["bash"]
