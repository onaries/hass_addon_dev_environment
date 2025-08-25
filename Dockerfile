ARG BUILD_FROM
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Python 3.13 and SSH server
RUN apt-get update && \
    apt-get install -y \
        software-properties-common \
        gpg-agent \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && \
    apt-get install -y \
        python3.13 \
        python3.13-dev \
        python3.13-venv \
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
        ripgrep \
        fd-find \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd \
    && mkdir -p /run/sshd

# Install nvm (Node Version Manager)
ENV NVM_DIR=/opt/nvm
ENV NODE_VERSION=lts/*
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default

# Install oh-my-zsh globally
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install neovim latest binary
RUN NVIM_VERSION=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | jq -r '.tag_name') && \
    curl -L "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz" -o /tmp/nvim.tar.gz && \
    tar -xzf /tmp/nvim.tar.gz -C /tmp && \
    mv /tmp/nvim-linux64 /opt/nvim && \
    ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim && \
    rm /tmp/nvim.tar.gz

# Install zellij latest binary
RUN ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    curl -L "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" -o /tmp/zellij.tar.gz && \
    tar -xzf /tmp/zellij.tar.gz -C /tmp && \
    mv /tmp/zellij /usr/local/bin/ && \
    chmod +x /usr/local/bin/zellij && \
    rm /tmp/zellij.tar.gz

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