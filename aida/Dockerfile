ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV LANG=C.UTF-8

# Install system packages, dev tools, terminal, and bridge dependencies.
# ttyd is baked in here (not installed at runtime) so startup never depends
# on a reachable Alpine mirror.
#
# gcompat + libstdc++ + libgcc provide the glibc compatibility Claude Code needs
# on Alpine/musl. Without them the CLI (and its bundled native helpers) hangs on
# startup instead of running — even `claude --version` never returns.
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    jq \
    yq \
    nano \
    vim \
    tree \
    tmux \
    ttyd \
    nodejs \
    npm \
    python3 \
    py3-pip \
    py3-requests \
    py3-aiohttp \
    py3-yaml \
    uv \
    gcompat \
    libstdc++ \
    libgcc

# Install the Claude Code CLI. Version is pinned via build arg for
# reproducible images (see build.yaml). Installed via npm to avoid musl
# binary incompatibilities.
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
