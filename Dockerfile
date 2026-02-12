FROM node:24-slim

LABEL org.opencontainers.image.source="https://github.com/feiskyer/openclaw-kubernetes"
LABEL org.opencontainers.image.description="All-in-one vibe coding environment"
LABEL org.opencontainers.image.licenses="MIT"

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
  iproute2 \
  jq \
  less \
  man-db \
  nano \
  procps \
  python3 \
  ripgrep \
  sudo \
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

# Install kubectl (latest stable)
RUN KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt) && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" -o /tmp/kubectl.sha256 && \
    echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum --check && \
    chmod +x /usr/local/bin/kubectl && \
    rm /tmp/kubectl.sha256

# Install Azure CLI (official install command)
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create vibe user
RUN groupadd --gid 1024 vibe && \
  useradd -s /bin/zsh --uid 1024 --gid 1024 -m vibe && \
  echo vibe ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/vibe && \
  chmod 0440 /etc/sudoers.d/vibe

# Ensure default vibe user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R vibe:vibe /usr/local/share

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace && chown -R vibe:vibe /workspace
WORKDIR /workspace

# Set up non-root user
USER vibe

# Setup NPM Paths
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin:/home/vibe/.local/bin

# Configure zsh with oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
ENV SHELL=/bin/zsh

# Allow Codex CLI running without sandboxing
ENV CODEX_UNSAFE_ALLOW_NO_SANDBOX=1

# Install npm global tools
RUN npm install -g @openai/codex openclaw clawhub && \
  npm cache clean --force

# Install openclaw channel plugins (Skipping now for security reasons)
# RUN openclaw plugins install @openclaw/feishu
# RUN openclaw plugins install @openclaw/msteams

# Install uv via official installer
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Claude Code (installs into ~/.local/bin, adds config into existing ~/.claude/)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    if [ -f ~/.claude.json ]; then \
      jq '. + {"hasCompletedOnboarding": true}' ~/.claude.json > /tmp/claude.json && mv /tmp/claude.json ~/.claude.json; \
    else \
      echo '{"hasCompletedOnboarding": true}' > ~/.claude.json; \
    fi

# Copy default local configs
RUN mkdir -p /home/vibe/.codex /home/vibe/.kube
COPY --chown=vibe:vibe configs/codex-config.toml /home/vibe/.codex/config.toml
COPY --chown=vibe:vibe configs/claude-settings.json /home/vibe/.claude/settings.json
COPY --chown=vibe:vibe configs/kubeconfig /home/vibe/.kube/config

# Environments for vibe-kanban
ENV FRONTEND_PORT=8080
ENV HOST=0.0.0.0
EXPOSE 8080

# Entrypoint starts openclaw gateway
ENTRYPOINT [ "openclaw", "gateway", "--allow-unconfigured"]
