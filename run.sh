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

# Set docker socket permissions
for sock in /var/run/docker.sock /run/docker.sock; do
    if [ -S "$sock" ]; then
        chown root:docker "$sock"
        chmod 660 "$sock"
        echo "Docker socket found and configured: $sock"
    fi
done

# Create user if not exists
if ! id "$USERNAME" &>/dev/null; then
    echo "Creating user: $USERNAME"
    useradd -m -s /bin/zsh "$USERNAME"
    usermod -aG sudo,docker "$USERNAME"
    
    # Configure passwordless sudo for user
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
    chmod 440 /etc/sudoers.d/$USERNAME
    
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
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
    chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc
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

# Setup workspace directory - use ubuntu_data if available, otherwise use addon data
if [ -d "/ubuntu_data" ]; then
    echo "Using ubuntu_data volume as workspace"
    if [ ! -L "/workspace" ]; then
        rm -rf /workspace
        ln -s /ubuntu_data /workspace
    fi
    # Also link share/workspace for compatibility
    if [ ! -L "/share/workspace" ]; then
        rm -rf /share/workspace
        ln -s /ubuntu_data /share/workspace
    fi
else
    echo "Using addon data directory as workspace"
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