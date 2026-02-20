#!/bin/bash
# Exit on error for critical sections, but allow some failures
set -e
set -o pipefail
FAIL_OK=0

# Ensure HOME is set (HA addon containers may not set it)
export HOME="${HOME:-/root}"

# Emit failing command before exiting to help diagnose unexpected shutdowns
trap 'STATUS=$?; CMD=${BASH_COMMAND}; if [ "$FAIL_OK" = "1" ]; then log "Warning: command \"$CMD\" failed with status $STATUS (suppressed)"; else log "FATAL: command \"$CMD\" exited with status $STATUS"; exit $STATUS; fi' ERR

CONFIG_PATH=/data/options.json

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

TIMEZONE="Asia/Seoul"
export TZ="$TIMEZONE"
if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    echo "$TIMEZONE" > /etc/timezone
    log "Timezone set to $TIMEZONE"
else
    log "Warning: Timezone data not found for $TIMEZONE"
fi

configure_git_identity() {
    local target_user=$1
    local label=$2

    if [ -z "$GIT_NAME" ] && [ -z "$GIT_EMAIL" ]; then
        return 0
    fi

    local run_cmd
    if [ "$target_user" = "root" ]; then
        run_cmd=""
    else
        run_cmd="sudo -H -u $target_user"
    fi

    if [ -n "$GIT_NAME" ]; then
        if ! $run_cmd git config --global user.name "$GIT_NAME" 2>/dev/null; then
            log "Warning: Failed to set git user.name for $label"
        else
            log "Configured git user.name for $label"
        fi
    fi

    if [ -n "$GIT_EMAIL" ]; then
        if ! $run_cmd git config --global user.email "$GIT_EMAIL" 2>/dev/null; then
            log "Warning: Failed to set git user.email for $label"
        else
            log "Configured git user.email for $label"
        fi
    fi
}

log "Starting addon initialization..."

# Get SSH port from config (default: 2322)
SSH_PORT=$(jq -r '.ssh_port // 2322' $CONFIG_PATH)

# Get username from config (default: developer)
USERNAME=$(jq -r '.username // "developer"' $CONFIG_PATH)

# Optional git identity settings
GIT_NAME=$(jq -r '.git_name // ""' $CONFIG_PATH)
GIT_EMAIL=$(jq -r '.git_email // ""' $CONFIG_PATH)
CLIPROXY_API_KEYS=$(jq -r '.cliproxy_api_keys // [] | .[]' $CONFIG_PATH)

log "Configuring Docker access..."

# Create docker group if not exists and add root to docker group
if ! getent group docker > /dev/null 2>&1; then
    groupadd docker || log "Warning: Failed to create docker group"
fi
usermod -aG docker root 2>/dev/null || log "Warning: Failed to add root to docker group"

# Set docker socket permissions and create symlink if needed
log "Searching for Docker socket..."
DOCKER_SOCK=""
for sock in /run/docker.sock /var/run/docker.sock; do
    if [ -S "$sock" ]; then
        # Try to change ownership, but don't fail if it's read-only
        chown root:docker "$sock" 2>/dev/null || log "Warning: Cannot change ownership of $sock (read-only filesystem)"
        chmod 660 "$sock" 2>/dev/null || log "Warning: Cannot change permissions of $sock (read-only filesystem)"
        log "Docker socket found and configured: $sock"
        DOCKER_SOCK="$sock"
        break
    fi
done

# Ensure both /var/run/docker.sock and /run/docker.sock exist for compatibility
if [ -n "$DOCKER_SOCK" ]; then
    if [ "$DOCKER_SOCK" = "/run/docker.sock" ] && [ ! -S "/var/run/docker.sock" ]; then
        log "Creating symlink: /var/run/docker.sock -> /run/docker.sock"
        ln -sf /run/docker.sock /var/run/docker.sock
    elif [ "$DOCKER_SOCK" = "/var/run/docker.sock" ] && [ ! -S "/run/docker.sock" ]; then
        log "Creating symlink: /run/docker.sock -> /var/run/docker.sock"
        ln -sf /var/run/docker.sock /run/docker.sock
    fi

    # Set DOCKER_HOST environment variable
    echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /etc/environment
    echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /root/.bashrc
    echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /root/.zshrc
    log "DOCKER_HOST environment variable set to unix://$DOCKER_SOCK"
else
    log "Warning: No Docker socket found at /run/docker.sock or /var/run/docker.sock"
fi

log "Configuring user account: $USERNAME"
# Create user if not exists
if ! id "$USERNAME" &>/dev/null; then
    log "Creating user: $USERNAME"
    useradd -m -s /bin/zsh "$USERNAME"
else
    log "User $USERNAME already exists"
fi

# Ensure user is in docker, sudo, and _ssh groups (for both new and existing users)
usermod -aG sudo,docker,_ssh "$USERNAME" 2>/dev/null || log "Warning: Failed to add user to groups"

# Give user access to nvm directory
chown -R $USERNAME:$USERNAME /opt/nvm 2>/dev/null || log "Warning: Failed to set nvm directory ownership"

# Configure passwordless sudo for user
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# Setup user environment (only on first-ever run; check persistent storage)
if [ ! -d "/data/user_local/share/zinit" ]; then
    log "Setting up user environment for $USERNAME (this may take a while)..."

    # Temporarily disable exit on error for non-critical setup
    set +e
    FAIL_OK=1

    # Create SSH directory for user
    mkdir -p /home/$USERNAME/.ssh
    chmod 700 /home/$USERNAME/.ssh
    chown $USERNAME:$USERNAME /home/$USERNAME/.ssh

    log "Setting up zsh with Zinit..."
    if ! sudo -u $USERNAME bash -c 'curl -fsSL https://gist.githubusercontent.com/onaries/7ccb745f920f31cdda03850a9a431d2a/raw/setup-zsh.sh | bash'; then
        log "Warning: Failed to setup zsh configuration (continuing)"
    fi

    # Install LazyVim for user
    log "Installing LazyVim for user..."
    sudo -u $USERNAME git clone https://github.com/LazyVim/starter /home/$USERNAME/.config/nvim
    sudo -u $USERNAME rm -rf /home/$USERNAME/.config/nvim/.git

    echo 'source /etc/shell/env.sh' >> /home/$USERNAME/.zshrc
    echo 'source /etc/shell/aliases.sh' >> /home/$USERNAME/.zshrc
    echo 'source /etc/shell/zsh-extra.sh' >> /home/$USERNAME/.zshrc
    echo 'source /etc/shell/env.sh' >> /home/$USERNAME/.bashrc
    echo 'source /etc/shell/aliases.sh' >> /home/$USERNAME/.bashrc

    if [ -n "$DOCKER_SOCK" ]; then
        echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /home/$USERNAME/.zshrc
        echo "export DOCKER_HOST=unix://$DOCKER_SOCK" >> /home/$USERNAME/.bashrc
    fi

    # Install Node.js LTS for user
    log "Installing Node.js LTS for user..."
    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm install --lts && (nvm use --lts || nvm use --delete-prefix --lts --silent) && nvm alias default lts/*'

    # Clean up npm configs that conflict with nvm and set up persistent globals
    log "Configuring npm global packages storage..."
    mkdir -p /data/npm_global
    chown $USERNAME:$USERNAME /data/npm_global

    sudo -u $USERNAME bash -c "
        if [ -f \"\$HOME/.npmrc\" ]; then
            sed -i '/^prefix=/d' \"\$HOME/.npmrc\"
            sed -i '/^globalconfig=/d' \"\$HOME/.npmrc\"
        fi
    "

    sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && (nvm use default >/dev/null || nvm use --delete-prefix default --silent >/dev/null || true) && npm config delete prefix 2>/dev/null || true && npm config delete globalconfig 2>/dev/null || true'

    log "Installing Claude CLI for user..."
    if ! sudo -u $USERNAME bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
        log "Warning: Failed to install Claude CLI (continuing)"
    fi

    # Install Bun for user (needed by Codex CLI)
    log "Installing Bun for user..."
    if ! sudo -u $USERNAME bash -c 'curl -fsSL https://bun.sh/install | bash'; then
        log "Warning: Failed to install Bun (continuing)"
    fi

    echo 'export BUN_INSTALL="$HOME/.bun"' >> /home/$USERNAME/.zshrc
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /home/$USERNAME/.zshrc
    echo 'export BUN_INSTALL="$HOME/.bun"' >> /home/$USERNAME/.bashrc
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /home/$USERNAME/.bashrc

    log "Installing Codex CLI for user..."
    if ! sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm use default >/dev/null && npm install -g @openai/codex@latest'; then
        log "Warning: Failed to install Codex CLI (continuing)"
    fi

    rm -f /data/npm_global/bin/codex 2>/dev/null || true

    # Install OpenCode for user
    log "Installing OpenCode for user..."
    if ! sudo -u $USERNAME bash -c 'curl -fsSL https://opencode.ai/install | bash'; then
        log "Warning: Failed to install OpenCode (continuing)"
    fi

    # Install Fresh editor for user
    log "Installing Fresh editor for user..."
    if ! sudo -u $USERNAME bash -c 'curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh'; then
        log "Warning: Failed to install Fresh editor (continuing)"
    fi

    # Install OpenChamber for user
    log "Installing OpenChamber for user..."
    if ! sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && curl -fsSL https://raw.githubusercontent.com/btriapitsyn/openchamber/main/scripts/install.sh | bash'; then
        log "Warning: Failed to install OpenChamber (continuing)"
    fi

    # Install OpenClaw for user (requires Node.js >= 22)
    log "Installing OpenClaw for user..."
    if ! sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && npm install -g openclaw@latest'; then
        log "Warning: Failed to install OpenClaw (continuing)"
    fi

    # Install CLI Proxy API tooling
    log "Installing CLI Proxy API tooling..."
    if ! sudo -u $USERNAME bash -c 'curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash'; then
        log "Warning: Failed to install CLI Proxy API tooling (continuing)"
    fi

    # Install git-ai-commit CLI for conventional commit generation
    log "Installing git-ai-commit CLI..."
    if ! sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && nvm use default >/dev/null && npm install -g @ksw8954/git-ai-commit'; then
        log "Warning: Failed to install git-ai-commit (continuing)"
    fi

    # Add git-ai-commit alias
    echo 'alias gac="git-ai-commit"' >> /home/$USERNAME/.zshrc
    echo 'alias gac="git-ai-commit"' >> /home/$USERNAME/.bashrc

    # Add comprehensive git aliases (oh-my-zsh style)
    cat >> /home/$USERNAME/.aliases << 'GITALIASES'

# Git aliases (oh-my-zsh style)
alias gst="git status"
alias gss="git status -s"
alias gaa="git add --all"
alias gapa="git add --patch"
alias gcam="git commit -a -m"
alias gca="git commit -a"
alias gc!="git commit --amend"
alias gca!="git commit -a --amend"
alias gcn!="git commit --amend --no-edit"
alias gcan!="git commit -a --amend --no-edit"
alias gcmsg="git commit -m"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gcd="git checkout develop"
alias gcm="git checkout main || git checkout master"
alias gcp="git cherry-pick"
alias gcpa="git cherry-pick --abort"
alias gcpc="git cherry-pick --continue"
alias gd="git diff"
alias gds="git diff --staged"
alias gdw="git diff --word-diff"
alias gf="git fetch"
alias gfa="git fetch --all --prune"
alias gfo="git fetch origin"
alias gl="git pull"
alias gpr="git pull --rebase"
alias gpra="git pull --rebase --autostash"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gpf!="git push --force"
alias gpoat="git push origin --all && git push origin --tags"
alias gpu="git push -u origin HEAD"
alias gb="git branch"
alias gba="git branch -a"
alias gbd="git branch -d"
alias gbD="git branch -D"
alias gbr="git branch -r"
alias gbnm="git branch --no-merged"
alias gm="git merge"
alias gma="git merge --abort"
alias gmc="git merge --continue"
alias grb="git rebase"
alias grba="git rebase --abort"
alias grbc="git rebase --continue"
alias grbi="git rebase -i"
alias grbm="git rebase main || git rebase master"
alias grbd="git rebase develop"
alias grbs="git rebase --skip"
alias grs="git restore"
alias grss="git restore --staged"
alias grst="git reset"
alias grsth="git reset --hard"
alias grstsh="git reset --soft HEAD~1"
alias gsta="git stash"
alias gstaa="git stash apply"
alias gstd="git stash drop"
alias gstl="git stash list"
alias gstp="git stash pop"
alias gsts="git stash show --text"
alias gstc="git stash clear"
alias glog="git log --oneline --graph --decorate"
alias gloga="git log --oneline --graph --decorate --all"
alias glo="git log --oneline"
alias glol="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'"
alias glola="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all"
alias gt="git tag"
alias gta="git tag -a"
alias gtd="git tag -d"
alias gtl="git tag -l"
alias gts="git tag -s"
alias gtv="git tag | sort -V"
alias gsh="git show"
alias gsw="git switch"
alias gswc="git switch -c"
alias gswd="git switch develop"
alias gswm="git switch main || git switch master"
alias gbl="git blame -b -w"
alias gcl="git clone --recurse-submodules"
alias gclean="git clean -id"
alias gcf="git config --list"
alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'
alias gdt="git diff-tree --no-commit-id --name-only -r"
alias gdnolock="git diff $@ -- . ':(exclude)package-lock.json' ':(exclude)*.lock'"
alias gdup="git diff @{upstream}"
alias gfg="git ls-files | grep"
alias gg="git gui citool"
alias gga="git gui citool --amend"
alias ghh="git help"
alias glg="git log --stat"
alias glgp="git log --stat -p"
alias glgg="git log --graph"
alias glgga="git log --graph --decorate --all"
alias glgm="git log --graph --max-count=10"
alias glods="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' --date=short"
alias gcount="git shortlog -sn"
alias grev="git revert"
alias grh="git reset"
alias grhh="git reset --hard"
alias grhk="git reset --keep"
alias grhs="git reset --soft"
alias groh='git reset origin/$(git branch --show-current) --hard'
alias gru="git reset --"
alias grup="git remote update"
alias grv="git remote -v"
alias gsb="git status -sb"
alias gsd="git svn dcommit"
alias gsr="git svn rebase"
alias gsi="git submodule init"
alias gsu="git submodule update"
alias gpsup='git push --set-upstream origin $(git branch --show-current)'
alias ghp="git help"
alias gwch="git whatchanged -p --abbrev-commit --pretty=medium"
alias gwt="git worktree"
alias gwta="git worktree add"
alias gwtls="git worktree list"
alias gwtmv="git worktree move"
alias gwtrm="git worktree remove"
alias gam="git am"
alias gamc="git am --continue"
alias gams="git am --skip"
alias gama="git am --abort"
alias gap="git apply"
alias gapt="git apply --3way"
alias gbs="git bisect"
alias gbsb="git bisect bad"
alias gbsg="git bisect good"
alias gbsn="git bisect new"
alias gbso="git bisect old"
alias gbsr="git bisect reset"
alias gbss="git bisect start"
alias gwip='git add -A && git rm $(git ls-files --deleted) 2>/dev/null; git commit --no-verify -m "WIP [skip ci]"'
alias gunwip="git log -1 --pretty=%B | grep -q 'WIP' && git reset HEAD~1"
alias gignore="git update-index --assume-unchanged"
alias gunignore="git update-index --no-assume-unchanged"
alias gignored="git ls-files -v | grep '^[[:lower:]]'"
alias gpristine="git reset --hard && git clean -dffx"
GITALIASES

    # Install Bun for user
    log "Installing Bun for user..."
    if ! sudo -u $USERNAME bash -c 'curl -fsSL https://bun.sh/install | bash'; then
        log "Warning: Failed to install Bun (continuing)"
    fi


    # Install uv for user
    log "Installing uv for user..."
    if ! sudo -u $USERNAME bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'; then
        log "Warning: Failed to install uv (continuing)"
    fi

    # Install pre-commit for user
    log "Installing pre-commit for user..."
    if ! sudo -u $USERNAME bash -c 'export PATH="$HOME/.local/bin:$PATH" && uv tool install pre-commit'; then
        log "Warning: Failed to install pre-commit (continuing)"
    fi

    log "Installing zoxide for user..."
    if ! sudo -u $USERNAME bash -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'; then
        log "Warning: Failed to install zoxide (continuing)"
    fi

    # Install GitUI
    log "Installing GitUI..."
    if curl -L https://github.com/gitui-org/gitui/releases/download/v0.27.0/gitui-linux-x86_64.tar.gz -o /tmp/gitui.tar.gz; then
        if tar -xzf /tmp/gitui.tar.gz -C /tmp && mv /tmp/gitui /usr/local/bin/; then
            chmod +x /usr/local/bin/gitui
        else
            log "Warning: Failed to install GitUI (tar/mv stage)"
        fi
        rm -f /tmp/gitui.tar.gz
    else
        log "Warning: Failed to download GitUI"
    fi

    log "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt update
    apt install -y gh

    log "Installing Just..."
    JUST_VERSION=$(curl -s https://api.github.com/repos/casey/just/releases/latest | jq -r '.tag_name')
    if [ -n "$JUST_VERSION" ]; then
        curl -sSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" | tar -xz -C /usr/local/bin just
        chmod +x /usr/local/bin/just
    else
        log "Warning: Failed to fetch just version from GitHub"
    fi

    # Install act for running GitHub Actions locally
    log "Installing act..."
    curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | BINDIR=/usr/local/bin bash

    # Setup remote docker context: remote-arm64
    log "Configuring remote docker context: remote-arm64 (ubuntu@131.186.27.53)..."
    REMOTE_USER="ubuntu"
    REMOTE_IP="131.186.27.53"

    # Add remote host to known_hosts to avoid interactive prompts
    sudo -u $USERNAME mkdir -p /home/$USERNAME/.ssh
    sudo -u $USERNAME ssh-keyscan -H $REMOTE_IP >> /home/$USERNAME/.ssh/known_hosts 2>/dev/null

    # Create or update the docker context
    if sudo -u $USERNAME docker context ls | grep -q "remote-arm64"; then
        sudo -u $USERNAME docker context update remote-arm64 --docker "host=ssh://$REMOTE_USER@$REMOTE_IP"
    else
        sudo -u $USERNAME docker context create remote-arm64 --docker "host=ssh://$REMOTE_USER@$REMOTE_IP"
    fi

    # Set as default context
    sudo -u $USERNAME docker context use remote-arm64
    log "Remote docker context 'remote-arm64' set as default."

    # Generate user SSH key before ssh-copy-id so the identity exists
    mkdir -p /data/user_ssh_keys
    chown $USERNAME:$USERNAME /data/user_ssh_keys
    if [ ! -f "/data/user_ssh_keys/id_ed25519" ]; then
        log "Generating SSH key for user $USERNAME..."
        sudo -u $USERNAME ssh-keygen -t ed25519 -C "$USERNAME@hass-addon-dev" -f /data/user_ssh_keys/id_ed25519 -N ""
    fi
    sudo -u $USERNAME ln -sf /data/user_ssh_keys/id_ed25519 /home/$USERNAME/.ssh/id_ed25519
    sudo -u $USERNAME ln -sf /data/user_ssh_keys/id_ed25519.pub /home/$USERNAME/.ssh/id_ed25519.pub

    log "Attempting to copy SSH ID to $REMOTE_USER@$REMOTE_IP..."
    log "If this hangs, please run 'ssh-copy-id $REMOTE_USER@$REMOTE_IP' manually from the terminal."
    sudo -u $USERNAME timeout 10s ssh-copy-id -i /data/user_ssh_keys/id_ed25519.pub -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" || log "Warning: ssh-copy-id timed out or failed. Manual setup may be required."
    
    # Install Rust for user with persistent storage
    log "Installing Rust..."
    mkdir -p /data/rust_cargo
    chown $USERNAME:$USERNAME /data/rust_cargo

    if [ -f "/data/rust_cargo/cargo/bin/rustup" ]; then
        log "Rust already installed, updating..."
        sudo -u $USERNAME bash -c 'export RUSTUP_HOME="/data/rust_cargo/rustup" CARGO_HOME="/data/rust_cargo/cargo" PATH="/data/rust_cargo/cargo/bin:$PATH" && rustup update' || \
            log "Warning: Failed to update Rust (continuing)"
    else
        sudo -u $USERNAME bash -c 'export RUSTUP_HOME="/data/rust_cargo/rustup" CARGO_HOME="/data/rust_cargo/cargo" && curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    fi

    # Install Go with persistent GOPATH
    log "Installing Go..."
    GO_VERSION="1.25.4"
    wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go.tar.gz
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    
    # Setup persistent GOPATH
    mkdir -p /data/go_workspace
    chown $USERNAME:$USERNAME /data/go_workspace
    
    # Install Docker CLI for user (if not already available)
    if ! command -v docker >/dev/null 2>&1; then
        log "Installing Docker CLI..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm -f get-docker.sh
    fi

    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
    chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc /home/$USERNAME/.bashrc

    # Re-enable exit on error for critical sections
    set -e
    FAIL_OK=0
    log "User environment setup completed"
fi

log "Ensuring npm global packages are available..."
set +e
FAIL_OK=1
sudo -u $USERNAME bash -c '
    source /opt/nvm/nvm.sh
    nvm use default >/dev/null 2>&1 || nvm use --delete-prefix default --silent >/dev/null 2>&1

    npm install -g @openai/codex@latest 2>/dev/null || true
    npm install -g openclaw@latest 2>/dev/null || true
    npm install -g @ksw8954/git-ai-commit@latest 2>/dev/null || true
' || log "Warning: Failed to ensure npm global packages"
set -e
FAIL_OK=0

if [ -n "$GIT_NAME" ] || [ -n "$GIT_EMAIL" ]; then
    log "Applying configured git identity..."
    configure_git_identity "$USERNAME" "$USERNAME user"
    configure_git_identity "root" "root user"
else
    log "Git identity options not provided; skipping git config"
fi

log "Configuring git to use SSH for GitHub..."
sudo -H -u $USERNAME git config --global url."git@github.com:".insteadOf "https://github.com/"
git config --global url."git@github.com:".insteadOf "https://github.com/"

echo 'source /etc/shell/env.sh' >> /root/.zshrc
echo 'source /etc/shell/aliases.sh' >> /root/.zshrc
echo 'source /etc/shell/env.sh' >> /root/.bashrc
echo 'source /etc/shell/aliases.sh' >> /root/.bashrc

log "Configuring CLIProxyAPI..."
CLIPROXY_DIR="/home/$USERNAME/cliproxyapi"

set +e
FAIL_OK=1

if [ -d "$CLIPROXY_DIR" ]; then
    log "Found CLIProxyAPI directory, configuring..."

    sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/cliproxyapi
    if [ ! -f "/home/$USERNAME/.config/cliproxyapi/config.yaml" ] || [ -n "$CLIPROXY_API_KEYS" ]; then
        {
            echo "debug: false"
            echo "logging-to-file: false"
            echo "auth-dir: /data/cli_proxy_api"
            echo "port: 8317"
            if [ -n "$CLIPROXY_API_KEYS" ]; then
                echo "api-keys:"
                echo "$CLIPROXY_API_KEYS" | while read -r key; do
                    [ -n "$key" ] && echo "  - \"$key\""
                done
            fi
        } > /home/$USERNAME/.config/cliproxyapi/config.yaml
        chown $USERNAME:$USERNAME /home/$USERNAME/.config/cliproxyapi/config.yaml
    fi
else
    log "CLIProxyAPI directory not found at $CLIPROXY_DIR; skipping."
fi

# Re-enable exit on error for critical sections
set -e
FAIL_OK=0

log "Setting up persistent storage..."
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

# Setup OpenClaw persistent storage
mkdir -p /data/openclaw_config
chown $USERNAME:$USERNAME /data/openclaw_config

if [ ! -L "/home/$USERNAME/.openclaw" ]; then
    if [ -d "/home/$USERNAME/.openclaw" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.openclaw/. /data/openclaw_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.openclaw
    fi
    sudo -u $USERNAME ln -sf /data/openclaw_config /home/$USERNAME/.openclaw
fi

if [ ! -L "/root/.openclaw" ]; then
    if [ -d "/root/.openclaw" ]; then
        cp -r /root/.openclaw/. /data/openclaw_config/ 2>/dev/null || true
        rm -rf /root/.openclaw
    fi
    ln -sf /data/openclaw_config /root/.openclaw
fi

# Setup Claude CLI persistent storage for all users
mkdir -p /data/claude_config
chown $USERNAME:$USERNAME /data/claude_config

# Setup .qwen persistent storage for all users
mkdir -p /data/qwen_config
chown $USERNAME:$USERNAME /data/qwen_config

# Create symlinks for Claude CLI configuration (user)
if [ ! -L "/home/$USERNAME/.claude" ]; then
    if [ -d "/home/$USERNAME/.claude" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.claude/. /data/claude_config/ 2>/dev/null || true
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

# Create symlinks for Claude CLI configuration (root)
if [ ! -L "/root/.claude" ]; then
    if [ -d "/root/.claude" ]; then
        cp -r /root/.claude/. /data/claude_config/ 2>/dev/null || true
        rm -rf /root/.claude
    fi
    ln -sf /data/claude_config /root/.claude
fi

if [ ! -L "/root/.claude.json" ] && [ -f "/root/.claude.json" ]; then
    mv /root/.claude.json /data/claude_config/
fi
if [ ! -L "/root/.claude.json" ]; then
    ln -sf /data/claude_config/.claude.json /root/.claude.json
fi

# Create symlinks for .qwen configuration
if [ ! -L "/home/$USERNAME/.qwen" ]; then
    if [ -d "/home/$USERNAME/.qwen" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.qwen/* /data/qwen_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.qwen
    fi
    sudo -u $USERNAME ln -sf /data/qwen_config /home/$USERNAME/.qwen
fi

# Setup Bun persistent storage
mkdir -p /data/bun_home
chown $USERNAME:$USERNAME /data/bun_home

if [ ! -L "/home/$USERNAME/.bun" ]; then
    if [ -d "/home/$USERNAME/.bun" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.bun/. /data/bun_home/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.bun
    fi
    sudo -u $USERNAME ln -sf /data/bun_home /home/$USERNAME/.bun
fi

# Setup user scripts persistent storage (synced via Syncthing)
mkdir -p /data/user_scripts
chown $USERNAME:$USERNAME /data/user_scripts

if [ ! -L "/home/$USERNAME/scripts" ]; then
    if [ -d "/home/$USERNAME/scripts" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/scripts/. /data/user_scripts/ 2>/dev/null || true
        rm -rf /home/$USERNAME/scripts
    fi
    sudo -u $USERNAME ln -sf /data/user_scripts /home/$USERNAME/scripts
fi

mkdir -p /data/syncthing_config
chown $USERNAME:$USERNAME /data/syncthing_config

if [ ! -L "/home/$USERNAME/.config/syncthing" ]; then
    if [ -d "/home/$USERNAME/.config/syncthing" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.config/syncthing/. /data/syncthing_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.config/syncthing
    fi
    sudo -u $USERNAME mkdir -p /home/$USERNAME/.config
    sudo -u $USERNAME ln -sf /data/syncthing_config /home/$USERNAME/.config/syncthing
fi

log "Setting up passwords and SSH keys..."

# Set user password if provided
if [ "$(jq -r '.user_password // empty' $CONFIG_PATH)" ]; then
    log "Setting password for user $USERNAME"
    echo "$USERNAME:$(jq -r '.user_password' $CONFIG_PATH)" | chpasswd
fi

# Set root password if provided
if [ "$(jq -r '.password // empty' $CONFIG_PATH)" ]; then
    log "Setting password for root"
    echo "root:$(jq -r '.password' $CONFIG_PATH)" | chpasswd
fi

# Add SSH keys if provided
SSH_KEYS=$(jq -r '.ssh_keys[]? // empty' $CONFIG_PATH)
if [ -n "$SSH_KEYS" ]; then
    log "Adding SSH keys for root..."
    echo "$SSH_KEYS" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    log "Adding SSH keys for $USERNAME..."
    echo "$SSH_KEYS" > /home/$USERNAME/.ssh/authorized_keys
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/authorized_keys
fi

log "Configuring workspace directory..."
# Setup workspace directory - find ubuntu_data volume with full_access
UBUNTU_DATA_PATH=""
for path in \
    "/mnt/data/docker/volumes/ubuntu_data/_data" \
    "/host/mnt/data/docker/volumes/ubuntu_data/_data"; do
    if [ -d "$path" ]; then
        UBUNTU_DATA_PATH="$path"
        log "Found ubuntu_data volume at: $path"
        break
    fi
done

if [ -n "$UBUNTU_DATA_PATH" ]; then
    log "Using ubuntu_data volume as workspace: $UBUNTU_DATA_PATH"
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
    log "Ubuntu_data volume not found, using addon data directory as workspace"
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

log "Configuring SSH..."
# Configure SSH port and allow user
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/AllowUsers root/AllowUsers root $USERNAME/" /etc/ssh/sshd_config

log "Setting up SSH host keys..."
# Generate SSH host keys if they don't exist - persist in data directory
if [ ! -d "/data/ssh_host_keys" ]; then
    mkdir -p /data/ssh_host_keys
    ssh-keygen -A
    # Move generated keys to persistent storage
    mv /etc/ssh/ssh_host_* /data/ssh_host_keys/
    cp /data/ssh_host_keys/ssh_host_* /etc/ssh/
else
    # Restore keys from persistent storage
    cp /data/ssh_host_keys/ssh_host_* /etc/ssh/
fi

chmod 600 /etc/ssh/ssh_host_* 2>/dev/null || true

# Setup user SSH keys persistent storage
mkdir -p /data/user_ssh_keys
chown $USERNAME:$USERNAME /data/user_ssh_keys

# Generate or restore user SSH key
if [ ! -f "/data/user_ssh_keys/id_ed25519" ]; then
    log "Generating SSH key for user $USERNAME..."
    sudo -u $USERNAME ssh-keygen -t ed25519 -C "$USERNAME@hass-addon-dev" -f /data/user_ssh_keys/id_ed25519 -N ""
    log "Generated SSH key for user $USERNAME:"
    cat /data/user_ssh_keys/id_ed25519.pub
fi

# Create symlinks for user SSH keys
sudo -u $USERNAME ln -sf /data/user_ssh_keys/id_ed25519 /home/$USERNAME/.ssh/id_ed25519
sudo -u $USERNAME ln -sf /data/user_ssh_keys/id_ed25519.pub /home/$USERNAME/.ssh/id_ed25519.pub

# Persist SSH config file
if [ -f "/home/$USERNAME/.ssh/config" ] && [ ! -L "/home/$USERNAME/.ssh/config" ]; then
    cp /home/$USERNAME/.ssh/config /data/user_ssh_keys/config
fi
if [ -f "/data/user_ssh_keys/config" ]; then
    sudo -u $USERNAME ln -sf /data/user_ssh_keys/config /home/$USERNAME/.ssh/config
    chmod 600 /data/user_ssh_keys/config
    log "Restored persistent SSH config"
fi

# Pre-add known SSH hosts to avoid interactive prompts during git operations
log "Adding known SSH hosts..."
mkdir -p /data/user_ssh_keys/known_hosts.d
if [ ! -f "/data/user_ssh_keys/known_hosts.d/safemotion" ]; then
    ssh-keyscan -p 6012 git.safemotion.kr >> /data/user_ssh_keys/known_hosts.d/safemotion 2>/dev/null || true
fi
if [ ! -f "/data/user_ssh_keys/known_hosts.d/github" ]; then
    ssh-keyscan github.com >> /data/user_ssh_keys/known_hosts.d/github 2>/dev/null || true
fi
# Merge all known hosts into user's known_hosts file
cat /data/user_ssh_keys/known_hosts.d/* > /home/$USERNAME/.ssh/known_hosts 2>/dev/null || true
chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/known_hosts 2>/dev/null || true

log "Generating supervisord configuration..."
mkdir -p /var/log/supervisor
cat > /etc/supervisor/conf.d/services.conf << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/sshd.log
stderr_logfile=/var/log/supervisor/sshd_err.log
priority=10

[program:syncthing]
command=/usr/local/bin/syncthing serve --no-browser --gui-address=0.0.0.0:8384 --home=/data/syncthing_config
directory=/home/$USERNAME
environment=HOME="/home/$USERNAME",USER="$USERNAME",XDG_CONFIG_HOME="/home/$USERNAME/.config",XDG_DATA_HOME="/home/$USERNAME/.local/share"
user=$USERNAME
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/syncthing.log
stderr_logfile=/var/log/supervisor/syncthing_err.log
priority=20
EOF

CLIPROXY_DIR="/home/$USERNAME/cliproxyapi"
CLIPROXY_CONFIG="/home/$USERNAME/.config/cliproxyapi/config.yaml"
if [ -d "$CLIPROXY_DIR" ] && [ -f "$CLIPROXY_CONFIG" ]; then
    cat >> /etc/supervisor/conf.d/services.conf << EOF

[program:cliproxyapi]
command=$CLIPROXY_DIR/cli-proxy-api --config $CLIPROXY_CONFIG
directory=/home/$USERNAME
environment=HOME="/home/$USERNAME",USER="$USERNAME",XDG_CONFIG_HOME="/home/$USERNAME/.config",XDG_DATA_HOME="/home/$USERNAME/.local/share"
user=$USERNAME
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/cliproxyapi.log
stderr_logfile=/var/log/supervisor/cliproxyapi_err.log
priority=30
EOF
    log "CLIProxyAPI added to supervisor"
fi

OPENCLAW_BIN=$(sudo -u $USERNAME bash -c 'source /opt/nvm/nvm.sh && which openclaw 2>/dev/null')
if [ -n "$OPENCLAW_BIN" ]; then
    OPENCLAW_NODE_DIR=$(dirname "$OPENCLAW_BIN")
    cat >> /etc/supervisor/conf.d/services.conf << EOF

[program:openclaw]
command=$OPENCLAW_BIN gateway --port 18789
directory=/home/$USERNAME
environment=HOME="/home/$USERNAME",USER="$USERNAME",PATH="$OPENCLAW_NODE_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",XDG_CONFIG_HOME="/home/$USERNAME/.config",XDG_DATA_HOME="/home/$USERNAME/.local/share"
user=$USERNAME
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/openclaw.log
stderr_logfile=/var/log/supervisor/openclaw_err.log
priority=40
EOF
    log "OpenClaw gateway added to supervisor (port 18789)"
fi

log "Starting services via supervisord..."
log "SSH is available on port $SSH_PORT"
log "Syncthing GUI is available on port 8384"
log "Use 'supervisorctl status' to check service status"

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
