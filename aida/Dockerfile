ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Debian (glibc) base — Claude Code and its bundled native helpers do NOT run
# reliably on Alpine/musl (even `claude --version` hangs). glibc is the
# environment Claude Code is built for.

# System packages, dev tools, and bridge dependencies via apt.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    wget \
    gnupg \
    git \
    jq \
    nano \
    vim \
    tree \
    tmux \
    xz-utils \
    python3 \
    python3-pip \
    python3-requests \
    python3-aiohttp \
    python3-yaml \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 (glibc build) via NodeSource.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# uv / uvx (used by the ha-mcp integration) via pip.
RUN pip3 install --break-system-packages --no-cache-dir uv

# ttyd — static prebuilt binary (per-arch) from upstream releases. The static
# build runs regardless of the base libc.
ARG TTYD_VERSION=1.7.7
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64)  ttyd_arch="x86_64" ;; \
      aarch64) ttyd_arch="aarch64" ;; \
      *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/bin/ttyd "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ttyd_arch}"; \
    chmod +x /usr/bin/ttyd; \
    ttyd --version

# Install the Claude Code CLI. Version is pinned via build arg for reproducible
# images (see build.yaml).
ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && npm cache clean --force

# Create runtime directories
RUN mkdir -p /config/aida /opt/aida/scripts /opt/aida/claude

# Copy startup script, modular scripts, and Claude Code policy files
COPY run.sh /run.sh
COPY scripts/ /opt/aida/scripts/
COPY claude/ /opt/aida/claude/
RUN chmod +x /run.sh /opt/aida/scripts/*.sh

WORKDIR /config

# Use exec form for correct signal handling
CMD ["/run.sh"]
