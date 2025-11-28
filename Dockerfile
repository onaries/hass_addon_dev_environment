ARG BUILD_FROM
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install packages (use available Python in base image)
RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-dev \
        python3-venv \
        python3-pip \
        openssh-server \
        sudo \
        git \
        curl \
        nano \
        vim \
        wget \
        build-essential \
        jq \
        zsh \
        ca-certificates \
        gnupg \
        lsb-release \
        htop \
        tree \
        tmux \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd \
    && mkdir -p /run/sshd

# Install Docker CLI and Docker Compose
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install fd-find from package manager
RUN apt-get update && \
    (apt-get install -y fd-find || echo "fd-find not available via apt") && \
    rm -rf /var/lib/apt/lists/*

# Install ripgrep from pre-compiled binary
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        RG_ARCH="x86_64-unknown-linux-musl"; \
    elif [ "$ARCH" = "arm64" ]; then \
        RG_ARCH="aarch64-unknown-linux-gnu"; \
    else \
        RG_ARCH=""; \
    fi && \
    if [ -n "$RG_ARCH" ]; then \
        RG_VERSION=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq -r '.tag_name') && \
        curl -L "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-${RG_ARCH}.tar.gz" -o /tmp/ripgrep.tar.gz && \
        tar -xzf /tmp/ripgrep.tar.gz -C /tmp && \
        mv /tmp/ripgrep-${RG_VERSION}-${RG_ARCH}/rg /usr/local/bin/ && \
        chmod +x /usr/local/bin/rg && \
        rm -rf /tmp/ripgrep.tar.gz /tmp/ripgrep-${RG_VERSION}-${RG_ARCH}; \
    fi

# Install glances (system monitoring tool)
RUN pip3 install --break-system-packages glances[all] || pip3 install glances[all]

# Install delta (git-delta) from pre-compiled binary
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        DELTA_ARCH="x86_64-unknown-linux-musl"; \
    elif [ "$ARCH" = "arm64" ]; then \
        DELTA_ARCH="aarch64-unknown-linux-gnu"; \
    else \
        DELTA_ARCH=""; \
    fi && \
    if [ -n "$DELTA_ARCH" ]; then \
        DELTA_VERSION=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | jq -r '.tag_name') && \
        curl -L "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-${DELTA_ARCH}.tar.gz" -o /tmp/delta.tar.gz && \
        tar -xzf /tmp/delta.tar.gz -C /tmp && \
        mv /tmp/delta-${DELTA_VERSION}-${DELTA_ARCH}/delta /usr/local/bin/ && \
        chmod +x /usr/local/bin/delta && \
        rm -rf /tmp/delta.tar.gz /tmp/delta-${DELTA_VERSION}-${DELTA_ARCH}; \
    fi

# Install nvm (Node Version Manager)
ENV NVM_DIR=/opt/nvm
ENV NODE_VERSION=lts/*
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default && \
    chmod -R 755 $NVM_DIR

# Install additional tool as requested (Note: claude.ai/install.sh URL may need verification)
RUN curl -fsSL https://claude.ai/install.sh | bash || echo "Warning: claude.ai install script failed or URL not available"

# Install qwen-code CLI tool
RUN npm install -g @qwen-code/qwen-code || echo "Warning: Failed to install qwen-code CLI tool"

# Install oh-my-zsh globally
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install neovim from tarball (x86_64 only, fallback to AppImage on other architectures)
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
        rm -rf /opt/nvim && \
        tar -C /opt -xzf nvim-linux-x86_64.tar.gz && \
        ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim && \
        rm nvim-linux-x86_64.tar.gz; \
    else \
        curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage && \
        chmod +x nvim.appimage && \
        mv nvim.appimage /usr/local/bin/nvim && \
        apt-get update && \
        apt-get install -y fuse && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Install zellij from pre-compiled binary (x86_64 only, skip on other architectures)
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
        curl -L "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" -o /tmp/zellij.tar.gz && \
        tar -xzf /tmp/zellij.tar.gz -C /tmp && \
        mv /tmp/zellij /usr/local/bin/ && \
        chmod +x /usr/local/bin/zellij && \
        rm /tmp/zellij.tar.gz; \
    fi

# Install lsd (LSDeluxe) from pre-compiled binary
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        LSD_ARCH="x86_64-unknown-linux-musl"; \
    elif [ "$ARCH" = "arm64" ]; then \
        LSD_ARCH="aarch64-unknown-linux-musl"; \
    else \
        LSD_ARCH=""; \
    fi && \
    if [ -n "$LSD_ARCH" ]; then \
        LSD_VERSION=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
        curl -L "https://github.com/lsd-rs/lsd/releases/download/v${LSD_VERSION}/lsd-v${LSD_VERSION}-${LSD_ARCH}.tar.gz" -o /tmp/lsd.tar.gz && \
        tar -xzf /tmp/lsd.tar.gz -C /tmp && \
        mv /tmp/lsd-v${LSD_VERSION}-${LSD_ARCH}/lsd /usr/local/bin/ && \
        chmod +x /usr/local/bin/lsd && \
        rm -rf /tmp/lsd.tar.gz /tmp/lsd-v${LSD_VERSION}-${LSD_ARCH}; \
    fi

# Install duf (Disk Usage/Free Utility) from pre-compiled binary
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        DUF_ARCH="linux_x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        DUF_ARCH="linux_arm64"; \
    else \
        DUF_ARCH=""; \
    fi && \
    if [ -n "$DUF_ARCH" ]; then \
        DUF_VERSION=$(curl -s https://api.github.com/repos/muesli/duf/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
        curl -L "https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/duf_${DUF_VERSION}_${DUF_ARCH}.tar.gz" -o /tmp/duf.tar.gz && \
        tar -xzf /tmp/duf.tar.gz -C /tmp && \
        mv /tmp/duf /usr/local/bin/ && \
        chmod +x /usr/local/bin/duf && \
        rm -rf /tmp/duf.tar.gz; \
    fi

# Install mcfly (Ctrl+R shell history search) from pre-compiled binary
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        MCFLY_ARCH="x86_64-unknown-linux-musl"; \
    elif [ "$ARCH" = "arm64" ]; then \
        MCFLY_ARCH="aarch64-unknown-linux-musl"; \
    else \
        MCFLY_ARCH=""; \
    fi && \
    if [ -n "$MCFLY_ARCH" ]; then \
        MCFLY_VERSION=$(curl -s https://api.github.com/repos/cantino/mcfly/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
        curl -L "https://github.com/cantino/mcfly/releases/download/v${MCFLY_VERSION}/mcfly-v${MCFLY_VERSION}-${MCFLY_ARCH}.tar.gz" -o /tmp/mcfly.tar.gz && \
        tar -xzf /tmp/mcfly.tar.gz -C /tmp && \
        mv /tmp/mcfly /usr/local/bin/ && \
        chmod +x /usr/local/bin/mcfly && \
        rm -rf /tmp/mcfly.tar.gz; \
    fi

# Configure git to use delta as pager
RUN git config --system core.pager delta && \
    git config --system interactive.diffFilter "delta --color-only" && \
    git config --system delta.navigate true && \
    git config --system delta.line-numbers true && \
    git config --system delta.side-by-side false && \
    git config --system merge.conflictstyle diff3 && \
    git config --system diff.colorMoved default

# Configure mcfly for bash and zsh
RUN echo 'eval "$(mcfly init bash)"' >> /etc/bash.bashrc && \
    echo 'eval "$(mcfly init zsh)"' >> /etc/zsh/zshrc

# Create vim alias for nvim
RUN echo 'alias vim="nvim"' >> /etc/zsh/zshrc && \
    echo 'alias vi="nvim"' >> /etc/zsh/zshrc && \
    echo 'alias vim="nvim"' >> /etc/bash.bashrc && \
    echo 'alias vi="nvim"' >> /etc/bash.bashrc

# Add nvm to PATH for all users (both bash and zsh)
RUN echo 'export NVM_DIR="/opt/nvm"' >> /etc/profile && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /etc/profile && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /etc/profile && \
    echo 'export NVM_DIR="/opt/nvm"' >> /etc/zsh/zshrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /etc/zsh/zshrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /etc/zsh/zshrc

# Create SSH directory and set proper permissions
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'AllowUsers root' >> /etc/ssh/sshd_config

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Copy startup script
COPY run.sh /
RUN chmod a+x /run.sh

# Expose SSH port (default 2322, configurable)
EXPOSE 2322

CMD [ "/run.sh" ]