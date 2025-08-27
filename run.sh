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
    
    # Install Claude CLI for user
    sudo -u $USERNAME bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    
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
    "/var/lib/docker/volumes/ubuntu_data/_data" \
    "/mnt/data/docker/volumes/ubuntu_data/_data" \
    "/host/var/lib/docker/volumes/ubuntu_data/_data" \
    "/host/mnt/data/docker/volumes/ubuntu_data/_data"; do
    if [ -d "$path" ]; then
        UBUNTU_DATA_PATH="$path"
        echo "Found ubuntu_data volume at: $path"
        break
    fi
done

if [ -n "$UBUNTU_DATA_PATH" ]; then
    echo "Using ubuntu_data volume as workspace: $UBUNTU_DATA_PATH"
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

# Configure SSH port and allow user
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/AllowUsers root/AllowUsers root $USERNAME/" /etc/ssh/sshd_config

# Generate SSH host keys if they don't exist
ssh-keygen -A

# Start SSH daemon
echo "Starting SSH daemon on port $SSH_PORT..."
/usr/sbin/sshd -D &

# Keep the container running
echo "Container is ready!"
tail -f /dev/null