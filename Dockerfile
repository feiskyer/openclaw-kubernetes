FROM node:25-slim

LABEL org.opencontainers.image.source="https://github.com/feiskyer/openclaw-kubernetes"
LABEL org.opencontainers.image.description="All-in-one vibe coding environment"
LABEL org.opencontainers.image.licenses="MIT"

ARG OPENCLAW_VERSION=2026.4.14
ARG CLAWHUB_VERSION=0.9.0
ARG TTYD_VERSION=1.7.7
ARG TAILSCALE_VERSION=1.94.2
ARG TZ=UTC
ENV TZ="$TZ"

# Install dependencies (ordered alphabetically for readability)
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  dnsutils \
  fzf \
  gh \
  git \
  gnupg2 \
  iptables \
  iproute2 \
  jq \
  less \
  man-db \
  nano \
  procps \
  python3 \
  python3-pip \
  ripgrep \
  sudo \
  supervisor \
  tmux \
  unzip \
  vim \
  wget \
  zsh \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Install Google Chrome stable
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Install headed Chrome GUI stack (Xvfb, VNC, noVNC)
RUN apt-get update && apt-get install -y --no-install-recommends \
  dbus-x11 \
  fluxbox \
  fonts-noto-cjk \
  novnc \
  websockify \
  x11vnc \
  xvfb \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Install kubectl (latest stable)
RUN KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt) && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" -o /tmp/kubectl.sha256 && \
    echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum --check && \
    chmod +x /usr/local/bin/kubectl && \
    rm /tmp/kubectl.sha256

# Install Azure CLI (official install command)
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install ttyd (web-based terminal)
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in amd64) TTYD_ARCH=x86_64 ;; arm64) TTYD_ARCH=aarch64 ;; *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; esac && \
    curl --retry 3 -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# Install Tailscale (mesh VPN — only activated when TAILSCALE_ENABLED=true)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_${ARCH}.tgz" | \
    tar xz -C /tmp && \
    install -m 755 /tmp/tailscale_${TAILSCALE_VERSION}_${ARCH}/tailscale /usr/local/bin/ && \
    install -m 755 /tmp/tailscale_${TAILSCALE_VERSION}_${ARCH}/tailscaled /usr/local/bin/ && \
    rm -rf /tmp/tailscale_*

# Create vibe user
RUN groupadd --gid 1024 vibe && \
  useradd -s /bin/zsh --uid 1024 --gid 1024 -m vibe && \
  echo vibe ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/vibe && \
  chmod 0440 /etc/sudoers.d/vibe

# Ensure default vibe user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R vibe:vibe /usr/local/share

WORKDIR /home/vibe

# Set up non-root user
USER vibe

# Setup NPM Paths
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin:/home/vibe/.local/bin
ENV OPENCLAW_SERVICE_VERSION=$OPENCLAW_VERSION

# Configure zsh with oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
ENV SHELL=/bin/zsh

# Allow Codex CLI running without sandboxing
ENV CODEX_UNSAFE_ALLOW_NO_SANDBOX=1

# ClawHub workdir for skill management
ENV CLAWHUB_WORKDIR=/home/vibe/.openclaw/

# Install npm global tools
RUN npm install -g @openai/codex openclaw@${OPENCLAW_VERSION} clawhub@${CLAWHUB_VERSION} && \
  npm cache clean --force

# Install uv via official installer
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Register ACPX plugin and install its npm deps so the gateway skips plugin-local install.
# Remove the generated openclaw.json so it doesn't conflict with our ConfigMap-rendered version.
RUN openclaw plugins install acpx && \
    rm -f /home/vibe/.openclaw/openclaw.json && \
    cd /usr/local/share/npm-global/lib/node_modules/openclaw/dist/extensions/acpx && npm install --omit=dev && \
    ln -sf /usr/local/share/npm-global/lib/node_modules/openclaw/dist/extensions/acpx/node_modules/.bin/acpx /usr/local/share/npm-global/bin/acpx

# Install Claude Code (installs into ~/.local/bin, adds config into existing ~/.claude/)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    if [ -f ~/.claude.json ]; then \
      jq '. + {"hasCompletedOnboarding": true}' ~/.claude.json > /tmp/claude.json && mv /tmp/claude.json ~/.claude.json; \
    else \
      echo '{"hasCompletedOnboarding": true}' > ~/.claude.json; \
    fi

# Copy default local configs
RUN mkdir -p /home/vibe/.codex /home/vibe/.kube
COPY --chown=vibe:vibe configs/kubeconfig /home/vibe/.kube/config

# Virtual display environment for headed Chrome
ENV DISPLAY=:99

# Environments for vibe-kanban
ENV FRONTEND_PORT=8080
ENV HOST=0.0.0.0
EXPOSE 8080

# noVNC web interface port
EXPOSE 6080

# ttyd web terminal port
EXPOSE 7681

# Copy entrypoint script
COPY --chown=vibe:vibe configs/entrypoint.sh /usr/local/bin/entrypoint.sh

# Copy skills into the OpenClaw skills directory (last COPY — skills change most often)
COPY --chown=vibe:vibe skills/ /home/vibe/.openclaw/skills/

# Entrypoint starts supervisord (manages Xvfb, VNC, noVNC, openclaw)
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
