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
    # Handle npm configuration in a way that's compatible with nvm
    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm use default && npm config delete prefix 2>/dev/null || true'
    
    # Set up npm global directory without conflicting with nvm
    mkdir -p /data/npm_global
    chown $USERNAME:$USERNAME /data/npm_global
    
    # Configure npm to use persistent global directory in a nvm-compatible way
    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm use default && npm config set prefix /data/npm_global'
    
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

    # Add qwen-code CLI to PATH for user
    echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> /home/$USERNAME/.zshrc
    echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> /home/$USERNAME/.bashrc

    # Install Codex CLI for user
    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm use default >/dev/null && npm install -g @openai/codex@latest'

    # Install CLI Proxy API tooling
    sudo -u $USERNAME bash -c 'curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash'

    # Install git-ai-commit CLI for conventional commit generation
    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm use default >/dev/null && npm install -g @ksw8954/git-ai-commit'
    
    # Add a function to automatically fix nvm/npm conflicts
    echo 'fix_nvm_npm_conflict() {' >> /home/$USERNAME/.zshrc
    echo '  if [[ -f "$HOME/.npmrc" ]]; then' >> /home/$USERNAME/.zshrc
    echo '    local prefix=$(npm config get prefix 2>/dev/null)' >> /home/$USERNAME/.zshrc
    echo '    if [[ -n "$prefix" && "$prefix" != "undefined" ]]; then' >> /home/$USERNAME/.zshrc
    echo '      source /opt/nvm/nvm.sh 2>/dev/null' >> /home/$USERNAME/.zshrc
    echo '      nvm use --delete-prefix $(node -v 2>/dev/null || nvm current) --silent 2>/dev/null || true' >> /home/$USERNAME/.zshrc
    echo '    fi' >> /home/$USERNAME/.zshrc
    echo '  fi' >> /home/$USERNAME/.zshrc
    echo '}' >> /home/$USERNAME/.zshrc
    echo '' >> /home/$USERNAME/.zshrc
    echo '# Automatically fix nvm/npm conflicts on shell start' >> /home/$USERNAME/.zshrc
    echo 'fix_nvm_npm_conflict' >> /home/$USERNAME/.zshrc
    
    # Same for bash
    echo 'fix_nvm_npm_conflict() {' >> /home/$USERNAME/.bashrc
    echo '  if [[ -f "$HOME/.npmrc" ]]; then' >> /home/$USERNAME/.bashrc
    echo '    local prefix=$(npm config get prefix 2>/dev/null)' >> /home/$USERNAME/.bashrc
    echo '    if [[ -n "$prefix" && "$prefix" != "undefined" ]]; then' >> /home/$USERNAME/.bashrc
    echo '      source /opt/nvm/nvm.sh 2>/dev/null' >> /home/$USERNAME/.bashrc
    echo '      nvm use --delete-prefix $(node -v 2>/dev/null || nvm current) --silent 2>/dev/null || true' >> /home/$USERNAME/.bashrc
    echo '    fi' >> /home/$USERNAME/.bashrc
    echo '  fi' >> /home/$USERNAME/.bashrc
    echo '}' >> /home/$USERNAME/.bashrc
    echo '' >> /home/$USERNAME/.bashrc
    echo '# Automatically fix nvm/npm conflicts on shell start' >> /home/$USERNAME/.bashrc
    echo 'fix_nvm_npm_conflict' >> /home/$USERNAME/.bashrc
    
    # Add a function to automatically fix nvm/npm conflicts
    echo 'fix_nvm_npm_conflict() {' >> /home/$USERNAME/.zshrc
    echo '  if [[ -f "$HOME/.npmrc" ]]; then' >> /home/$USERNAME/.zshrc
    echo '    local prefix=$(npm config get prefix 2>/dev/null)' >> /home/$USERNAME/.zshrc
    echo '    if [[ -n "$prefix" && "$prefix" != "undefined" ]]; then' >> /home/$USERNAME/.zshrc
    echo '      source /opt/nvm/nvm.sh 2>/dev/null' >> /home/$USERNAME/.zshrc
    echo '      nvm use --delete-prefix $(node -v 2>/dev/null || nvm current) --silent 2>/dev/null || true' >> /home/$USERNAME/.zshrc
    echo '    fi' >> /home/$USERNAME/.zshrc
    echo '  fi' >> /home/$USERNAME/.zshrc
    echo '}' >> /home/$USERNAME/.zshrc
    echo '' >> /home/$USERNAME/.zshrc
    echo '# Automatically fix nvm/npm conflicts on shell start' >> /home/$USERNAME/.zshrc
    echo 'fix_nvm_npm_conflict' >> /home/$USERNAME/.zshrc

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
    GO_VERSION="1.25.4"
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

CLIPROXY_DIR="/home/$USERNAME/cliproxyapi"

if [ -d "$CLIPROXY_DIR" ]; then
    echo "Configuring CLIProxyAPI service..."

    # Ensure configuration directory exists and populate defaults if missing
    sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/cliproxyapi
    if [ ! -f "/home/$USERNAME/.config/cliproxyapi/config.yaml" ]; then
        cat <<'EOF' > /home/$USERNAME/.config/cliproxyapi/config.yaml
api-keys:
  - "sk-ZMY74pYQPH5LMtYCNWJvkutzy9e4wgHZdkzcWrWV6VIUc"
  - "sk-x8ltawZvBMXufZ95uvWS1EM3CAEN3LzTtBPf6drxLtD5A"
debug: false
logging-to-file: false
EOF
        chown $USERNAME:$USERNAME /home/$USERNAME/.config/cliproxyapi/config.yaml
    fi

    # Create systemd user service definition
    sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/systemd/user
    cat <<EOF > /home/$USERNAME/.config/systemd/user/cliproxyapi.service
[Unit]
Description=CLIProxyAPI Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$CLIPROXY_DIR
ExecStart=$CLIPROXY_DIR/cli-proxy-api --config /home/$USERNAME/.config/cliproxyapi/config.yaml
Restart=on-failure
Environment=HOME=/home/$USERNAME

[Install]
WantedBy=default.target
EOF
    chown $USERNAME:$USERNAME /home/$USERNAME/.config/systemd/user/cliproxyapi.service

    # Allow user services to run without interactive login if supported
    if command -v loginctl >/dev/null 2>&1; then
        loginctl enable-linger "$USERNAME" || true
    fi

    if command -v systemctl >/dev/null 2>&1; then
        sudo -u $USERNAME systemctl --user daemon-reload || true
        sudo -u $USERNAME systemctl --user enable cliproxyapi.service || true
        sudo -u $USERNAME systemctl --user restart cliproxyapi.service || sudo -u $USERNAME systemctl --user start cliproxyapi.service || true
    else
        echo "systemctl not available; CLIProxyAPI service must be started manually."
    fi
else
    echo "CLIProxyAPI directory not found at $CLIPROXY_DIR; skipping service configuration."
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

# Setup git-ai-commit persistent storage
mkdir -p /data/git_ai_commit_config
chown $USERNAME:$USERNAME /data/git_ai_commit_config

if [ ! -f "/data/git_ai_commit_config/config.json" ]; then
    cat <<'EOF' > /data/git_ai_commit_config/config.json
{
  "language": "ko",
  "apiKey": "4f5275be-2f52-4c07-8e9d-a591851c581b",
  "baseURL": "https://nano-gpt.com/api/v1",
  "model": "openai/gpt-oss-120b"
}
EOF
    chown $USERNAME:$USERNAME /data/git_ai_commit_config/config.json
fi

if [ ! -L "/home/$USERNAME/.git-ai-commit" ]; then
    if [ -d "/home/$USERNAME/.git-ai-commit" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.git-ai-commit/. /data/git_ai_commit_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.git-ai-commit
    fi
    sudo -u $USERNAME ln -sf /data/git_ai_commit_config /home/$USERNAME/.git-ai-commit
fi

if [ ! -L "/root/.git-ai-commit" ]; then
    if [ -d "/root/.git-ai-commit" ]; then
        cp -r /root/.git-ai-commit/. /data/git_ai_commit_config/ 2>/dev/null || true
        rm -rf /root/.git-ai-commit
    fi
    ln -sf /data/git_ai_commit_config /root/.git-ai-commit
fi

# Setup .cli-proxy-api persistent storage
mkdir -p /data/cli_proxy_api
chown $USERNAME:$USERNAME /data/cli_proxy_api

if [ ! -L "/home/$USERNAME/.cli-proxy-api" ]; then
    if [ -d "/home/$USERNAME/.cli-proxy-api" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.cli-proxy-api/. /data/cli_proxy_api/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.cli-proxy-api
    fi
    sudo -u $USERNAME ln -sf /data/cli_proxy_api /home/$USERNAME/.cli-proxy-api
fi

if [ ! -L "/root/.cli-proxy-api" ]; then
    if [ -d "/root/.cli-proxy-api" ]; then
        cp -r /root/.cli-proxy-api/. /data/cli_proxy_api/ 2>/dev/null || true
        rm -rf /root/.cli-proxy-api
    fi
    ln -sf /data/cli_proxy_api /root/.cli-proxy-api
fi

# Setup Codex CLI persistent storage
mkdir -p /data/codex_config
chown $USERNAME:$USERNAME /data/codex_config

if [ ! -L "/home/$USERNAME/.codex" ]; then
    if [ -d "/home/$USERNAME/.codex" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.codex/. /data/codex_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.codex
    fi
    sudo -u $USERNAME ln -sf /data/codex_config /home/$USERNAME/.codex
fi

if [ ! -L "/root/.codex" ]; then
    if [ -d "/root/.codex" ]; then
        cp -r /root/.codex/. /data/codex_config/ 2>/dev/null || true
        rm -rf /root/.codex
    fi
    ln -sf /data/codex_config /root/.codex
fi

# Setup Claude CLI persistent storage for all users
mkdir -p /data/claude_config
chown $USERNAME:$USERNAME /data/claude_config

# Setup .qwen persistent storage for all users
mkdir -p /data/qwen_config
chown $USERNAME:$USERNAME /data/qwen_config

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

# Create symlinks for .qwen configuration
if [ ! -L "/home/$USERNAME/.qwen" ]; then
    if [ -d "/home/$USERNAME/.qwen" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.qwen/* /data/qwen_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.qwen
    fi
    sudo -u $USERNAME ln -sf /data/qwen_config /home/$USERNAME/.qwen
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
