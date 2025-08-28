#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

# Get SSH port from config (default: 2322)
SSH_PORT=$(jq -r '.ssh_port // 2322' $CONFIG_PATH)

# Get username from config (default: developer)
USERNAME=$(jq -r '.username // "developer"' $CONFIG_PATH)

# Create docker group if not exists and add root to docker group
if ! getent group docker > /dev/null 2>&1; then
    groupadd docker
fi
usermod -aG docker root

# Set docker socket permissions and create symlink if needed
DOCKER_SOCK=""
for sock in /run/docker.sock /var/run/docker.sock; do
    if [ -S "$sock" ]; then
        # Try to change ownership, but don't fail if it's read-only
        chown root:docker "$sock" 2>/dev/null || echo "Warning: Cannot change ownership of $sock (read-only filesystem)"
        chmod 660 "$sock" 2>/dev/null || echo "Warning: Cannot change permissions of $sock (read-only filesystem)"
        echo "Docker socket found and configured: $sock"
        DOCKER_SOCK="$sock"
        break
    fi
done

# Ensure both /var/run/docker.sock and /run/docker.sock exist for compatibility
if [ -n "$DOCKER_SOCK" ]; then
    if [ "$DOCKER_SOCK" = "/run/docker.sock" ] && [ ! -S "/var/run/docker.sock" ]; then
        echo "Creating symlink: /var/run/docker.sock -> /run/docker.sock"
        ln -sf /run/docker.sock /var/run/docker.sock
    elif [ "$DOCKER_SOCK" = "/var/run/docker.sock" ] && [ ! -S "/run/docker.sock" ]; then
        echo "Creating symlink: /run/docker.sock -> /var/run/docker.sock"
        ln -sf /var/run/docker.sock /run/docker.sock
    fi

    # Set DOCKER_HOST environment variable
    echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /etc/environment
    echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /root/.bashrc
    echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /root/.zshrc
else
    echo "Warning: No Docker socket found at /run/docker.sock or /var/run/docker.sock"
fi

# Create user if not exists
if ! id "$USERNAME" &>/dev/null; then
    echo "Creating user: $USERNAME"
    useradd -m -s /bin/zsh "$USERNAME"
fi

# Ensure user is in docker, sudo, and _ssh groups (for both new and existing users)
usermod -aG sudo,docker,_ssh "$USERNAME"

# Give user access to nvm directory
chown -R $USERNAME:$USERNAME /opt/nvm

# Configure passwordless sudo for user
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# Setup user environment (only if user was just created)
if [ ! -d "/home/$USERNAME/.oh-my-zsh" ]; then

    # Create SSH directory for user
    mkdir -p /home/$USERNAME/.ssh
    chmod 700 /home/$USERNAME/.ssh
    chown $USERNAME:$USERNAME /home/$USERNAME/.ssh

    # Install oh-my-zsh for user
    sudo -u $USERNAME sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    # Install LazyVim for user
    sudo -u $USERNAME git clone https://github.com/LazyVim/starter /home/$USERNAME/.config/nvim
    sudo -u $USERNAME rm -rf /home/$USERNAME/.config/nvim/.git

    # Add vim aliases to user's zshrc
    echo 'alias vim="nvim"' >> /home/$USERNAME/.zshrc
    echo 'alias vi="nvim"' >> /home/$USERNAME/.zshrc

    # Add nvm to user's zshrc
    echo 'export NVM_DIR="/opt/nvm"' >> /home/$USERNAME/.zshrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/$USERNAME/.zshrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/$USERNAME/.zshrc

    # Add Docker environment variable for user
    if [ -n "$DOCKER_SOCK" ]; then
        echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /home/$USERNAME/.zshrc
        echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /home/$USERNAME/.bashrc
    fi

    # Install Node.js LTS for user
    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm install --lts && nvm use --lts && nvm alias default lts/*'
    
    # Setup npm global packages persistent storage
    mkdir -p /data/npm_global
    chown $USERNAME:$USERNAME /data/npm_global
    
    # Configure npm to use persistent global directory
    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && npm config set prefix /data/npm_global'
    
    # Add npm global bin to PATH
    echo 'export PATH="/data/npm_global/bin:$PATH"' >> /home/$USERNAME/.zshrc
    echo 'export PATH="/data/npm_global/bin:$PATH"' >> /home/$USERNAME/.bashrc

    # Install Claude CLI for user
    sudo -u $USERNAME bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

    # Add Claude CLI to PATH for user
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/$USERNAME/.zshrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/$USERNAME/.bashrc

    # Add Claude CLI alias
    echo 'alias ccc="claude --dangerously-skip-permissions"' >> /home/$USERNAME/.zshrc
    echo 'alias ccc="claude --dangerously-skip-permissions"' >> /home/$USERNAME/.bashrc

    # Install uv for user
    sudo -u $USERNAME bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
    
    # Install GitUI
    echo "Installing GitUI..."
    curl -L https://github.com/gitui-org/gitui/releases/download/v0.27.0/gitui-linux-x86_64.tar.gz -o /tmp/gitui.tar.gz
    tar -xzf /tmp/gitui.tar.gz -C /tmp
    mv /tmp/gitui /usr/local/bin/
    chmod +x /usr/local/bin/gitui
    rm -f /tmp/gitui.tar.gz
    
    # Install Just command runner
    echo "Installing Just..."
    wget -qO - 'https://proget.makedeb.org/debian-feeds/prebuilt-mpr.pub' | gpg --dearmor | tee /usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg 1> /dev/null
    echo "deb [arch=all,$(dpkg --print-architecture) signed-by=/usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg] https://proget.makedeb.org prebuilt-mpr $(lsb_release -cs)" | tee /etc/apt/sources.list.d/prebuilt-mpr.list
    apt update
    apt install -y just
    
    # Install Rust for user with persistent storage
    echo "Installing Rust..."
    mkdir -p /data/rust_cargo
    chown $USERNAME:$USERNAME /data/rust_cargo
    
    # Set RUSTUP_HOME and CARGO_HOME to persistent storage
    echo 'export RUSTUP_HOME="/data/rust_cargo/rustup"' >> /home/$USERNAME/.zshrc
    echo 'export CARGO_HOME="/data/rust_cargo/cargo"' >> /home/$USERNAME/.zshrc
    echo 'export PATH="/data/rust_cargo/cargo/bin:$PATH"' >> /home/$USERNAME/.zshrc
    echo 'export RUSTUP_HOME="/data/rust_cargo/rustup"' >> /home/$USERNAME/.bashrc
    echo 'export CARGO_HOME="/data/rust_cargo/cargo"' >> /home/$USERNAME/.bashrc
    echo 'export PATH="/data/rust_cargo/cargo/bin:$PATH"' >> /home/$USERNAME/.bashrc
    
    sudo -u $USERNAME bash -c 'export RUSTUP_HOME="/data/rust_cargo/rustup" CARGO_HOME="/data/rust_cargo/cargo" && curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    
    # Install Go with persistent GOPATH
    echo "Installing Go..."
    GO_VERSION="1.21.5"
    wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go.tar.gz
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    
    # Setup persistent GOPATH
    mkdir -p /data/go_workspace
    chown $USERNAME:$USERNAME /data/go_workspace
    
    echo 'export PATH="/usr/local/go/bin:$PATH"' >> /home/$USERNAME/.zshrc
    echo 'export GOPATH="/data/go_workspace"' >> /home/$USERNAME/.zshrc
    echo 'export PATH="/data/go_workspace/bin:$PATH"' >> /home/$USERNAME/.zshrc
    echo 'export PATH="/usr/local/go/bin:$PATH"' >> /home/$USERNAME/.bashrc
    echo 'export GOPATH="/data/go_workspace"' >> /home/$USERNAME/.bashrc
    echo 'export PATH="/data/go_workspace/bin:$PATH"' >> /home/$USERNAME/.bashrc


    # Install Docker CLI for user (if not already available)
    if ! command -v docker >/dev/null 2>&1; then
        echo "Installing Docker CLI..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm -f get-docker.sh
    fi

    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
    chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc /home/$USERNAME/.bashrc
fi

# Setup user .config persistent storage
mkdir -p /data/user_config
chown $USERNAME:$USERNAME /data/user_config

# Create symlink for .config directory
if [ ! -L "/home/$USERNAME/.config" ]; then
    if [ -d "/home/$USERNAME/.config" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.config/* /data/user_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.config
    fi
    sudo -u $USERNAME ln -sf /data/user_config /home/$USERNAME/.config
fi

# Setup user .local persistent storage
mkdir -p /data/user_local
chown $USERNAME:$USERNAME /data/user_local

# Create symlink for .local directory
if [ ! -L "/home/$USERNAME/.local" ]; then
    if [ -d "/home/$USERNAME/.local" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.local/* /data/user_local/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.local
    fi
    sudo -u $USERNAME ln -sf /data/user_local /home/$USERNAME/.local
fi

# Setup Claude CLI persistent storage for all users
mkdir -p /data/claude_config
chown $USERNAME:$USERNAME /data/claude_config

# Create symlinks for Claude CLI configuration
if [ ! -L "/home/$USERNAME/.claude" ]; then
    if [ -d "/home/$USERNAME/.claude" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.claude/* /data/claude_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.claude
    fi
    sudo -u $USERNAME ln -sf /data/claude_config /home/$USERNAME/.claude
fi

if [ ! -L "/home/$USERNAME/.claude.json" ] && [ -f "/home/$USERNAME/.claude.json" ]; then
    sudo -u $USERNAME mv /home/$USERNAME/.claude.json /data/claude_config/
fi
if [ ! -L "/home/$USERNAME/.claude.json" ]; then
    sudo -u $USERNAME ln -sf /data/claude_config/.claude.json /home/$USERNAME/.claude.json
fi

# Set user password if provided
if [ "$(jq -r '.user_password // empty' $CONFIG_PATH)" ]; then
    echo "$USERNAME:$(jq -r '.user_password' $CONFIG_PATH)" | chpasswd
fi

# Set root password if provided
if [ "$(jq -r '.password // empty' $CONFIG_PATH)" ]; then
    echo "root:$(jq -r '.password' $CONFIG_PATH)" | chpasswd
fi

# Add SSH keys if provided
SSH_KEYS=$(jq -r '.ssh_keys[]? // empty' $CONFIG_PATH)
if [ -n "$SSH_KEYS" ]; then
    echo "Adding SSH keys for root..."
    echo "$SSH_KEYS" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    echo "Adding SSH keys for $USERNAME..."
    echo "$SSH_KEYS" > /home/$USERNAME/.ssh/authorized_keys
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/authorized_keys
fi

# Setup workspace directory - find ubuntu_data volume with full_access
UBUNTU_DATA_PATH=""
for path in \
    "/mnt/data/docker/volumes/ubuntu_data/_data" \
    "/host/mnt/data/docker/volumes/ubuntu_data/_data"; do
    if [ -d "$path" ]; then
        UBUNTU_DATA_PATH="$path"
        echo "Found ubuntu_data volume at: $path"
        break
    fi
done

if [ -n "$UBUNTU_DATA_PATH" ]; then
    echo "Using ubuntu_data volume as workspace: $UBUNTU_DATA_PATH"
    chown -R $USERNAME:$USERNAME "$UBUNTU_DATA_PATH" 2>/dev/null || true
    if [ ! -L "/workspace" ]; then
        rm -rf /workspace
        ln -s "$UBUNTU_DATA_PATH" /workspace
    fi
    # Also link share/workspace for compatibility
    if [ ! -L "/share/workspace" ]; then
        rm -rf /share/workspace
        ln -s "$UBUNTU_DATA_PATH" /share/workspace
    fi
else
    echo "Ubuntu_data volume not found, using addon data directory as workspace"
    mkdir -p /data/workspace
    chown $USERNAME:$USERNAME /data/workspace
    if [ ! -L "/workspace" ]; then
        rm -rf /workspace
        ln -s /data/workspace /workspace
    fi
    # Also create share/workspace link
    mkdir -p /share/workspace
    if [ ! -L "/share/workspace" ]; then
        rm -rf /share/workspace
        ln -s /data/workspace /share/workspace
    fi
fi

# Ensure user has access to workspace
chown -R $USERNAME:$USERNAME /data/workspace 2>/dev/null || true

# Configure SSH port and allow user
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/AllowUsers root/AllowUsers root $USERNAME/" /etc/ssh/sshd_config

# Generate SSH host keys if they don't exist - persist in data directory
if [ ! -d "/data/ssh_host_keys" ]; then
    mkdir -p /data/ssh_host_keys
    ssh-keygen -A
    # Move generated keys to persistent storage
    mv /etc/ssh/ssh_host_* /data/ssh_host_keys/
else
    # Restore keys from persistent storage
    cp /data/ssh_host_keys/ssh_host_* /etc/ssh/
fi

# Setup user SSH keys persistent storage
mkdir -p /data/user_ssh_keys
chown $USERNAME:$USERNAME /data/user_ssh_keys

# Generate or restore user SSH key
if [ ! -f "/data/user_ssh_keys/id_ed25519" ]; then
    sudo -u $USERNAME ssh-keygen -t ed25519 -C "$USERNAME@hass-addon-dev" -f /data/user_ssh_keys/id_ed25519 -N ""
    echo "Generated SSH key for user $USERNAME:"
    cat /data/user_ssh_keys/id_ed25519.pub
fi

# Create symlinks for user SSH keys
sudo -u $USERNAME ln -sf /data/user_ssh_keys/id_ed25519 /home/$USERNAME/.ssh/id_ed25519
sudo -u $USERNAME ln -sf /data/user_ssh_keys/id_ed25519.pub /home/$USERNAME/.ssh/id_ed25519.pub

# Start SSH daemon
echo "Starting SSH daemon on port $SSH_PORT..."
/usr/sbin/sshd -D &

# Keep the container running
echo "Container is ready!"
tail -f /dev/null
