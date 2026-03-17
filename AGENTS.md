# AGENTS.md - Coding Agent Guidelines

## Project Overview

Home Assistant add-on providing a multi-language development environment with SSH access, persistent storage, and modern dev tools. Debian Bookworm-based, amd64 only. Docker image published to `ksw8954/python-dev-env`.

## Build & Test Commands

```bash
# Build Docker image locally
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm -t dev-env python_dev_env/

# Test run.sh syntax
bash -n python_dev_env/run.sh

# Lint shell scripts
shellcheck python_dev_env/run.sh

# Validate YAML files
yamllint python_dev_env/config.yaml python_dev_env/build.yaml repository.yaml

# Test container startup
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock dev-env /run.sh
```

## Project Structure

```
.
├── repository.yaml                         # HA repository metadata
├── .github/workflows/docker-build.yaml     # CI: tag push → Docker Hub + GitHub Release
└── python_dev_env/                         # The add-on
    ├── config.yaml                         # Add-on metadata, options schema, port mappings
    ├── build.yaml                          # Base image (amd64 only)
    ├── Dockerfile                          # System packages, CLI tools, Neovim, Syncthing
    ├── run.sh                              # Main startup script (~1330 lines)
    └── rootfs/                             # Files copied to container root (COPY rootfs/ /)
        ├── etc/
        │   ├── shell/
        │   │   ├── env.sh                  # PATH, NVM, Rust, Go, Claude symlink repair
        │   │   ├── aliases.sh              # 150+ git aliases, lsd/nvim aliases, claude wrapper
        │   │   └── zsh-extra.sh            # zoxide, mcfly, custom scripts
        │   └── nvim/
        │       └── plugins/
        │           └── django.lua          # LazyVim Django LSP config (pyright, djlint, htmldjango)
        └── usr/local/bin/
            ├── setup-zsh.sh                # Zinit + theme + .zshrc/.bashrc generation
            ├── dashboard-server.py         # Status dashboard (ingress:8099)
            └── claude-token-refresh.sh     # OAuth token auto-refresh daemon
```

## Startup Flow (run.sh)

run.sh executes in this order:

1. **Config read**: SSH port, username, git identity from `/data/options.json`
2. **Docker access**: docker group, socket permissions, DOCKER_HOST
3. **User account**: create user, sudo, docker group membership
4. **First-run setup** (if `/data/user_local/share/zinit` missing): LazyVim, Node.js, npm packages, Claude CLI, Bun, Codex, OpenCode, OpenChamber, OpenClaw, CLIProxyAPI, Rust, git aliases, uv + Python tools, zoxide, remote docker context, SSH keys
5. **Shell config**: regenerate .zshrc/.bashrc via setup-zsh.sh (every start)
6. **Idempotent checks**: ensure LazyVim, Django LSP config, Node.js, Bun, Rust, Docker CLI, CLIProxyAPI, npm packages, GitUI, gh, Just, Dolt, Beads, act, Claude CLI, uv, Python tools (ruff, mypy, djlint), zoxide, Fresh, OpenChamber, OpenCode, Go are present
7. **Git config**: identity, SSH-for-GitHub
8. **Persistent storage**: symlinks for .config, .local, zsh_history, tool configs
9. **Passwords & SSH keys**: from options.json
10. **Workspace**: mount ubuntu_data volume or fallback to /data/workspace
11. **SSH config**: port, allowed users, host keys
12. **Supervisor config**: generate services.conf dynamically
13. **Start supervisord**: launches all services

## Supervisor Services

| Program | Command | Condition |
|---------|---------|-----------|
| sshd | `/usr/sbin/sshd -D` | always |
| syncthing | `syncthing serve --gui-address=0.0.0.0:8384` | always |
| dashboard | `python3 /usr/local/bin/dashboard-server.py` | always |
| cliproxyapi | `cli-proxy-api --config ...` | if CLIProxyAPI installed + config exists |
| openclaw | `openclaw gateway --port 18789` | if openclaw binary found |
| claude-token-refresh | `/usr/local/bin/claude-token-refresh.sh` | if `.claude/.credentials.json` exists |
| dolt | `dolt sql-server --port 3307` | if dolt binary found |

## Code Style Guidelines

### Shell Scripts (run.sh)

#### Error Handling
```bash
set -e                 # Exit on error (critical sections)
set -o pipefail        # Pipe failures propagate

FAIL_OK=0              # Toggle for optional sections
set +e; FAIL_OK=1      # Disable strict mode for optional installs
set -e; FAIL_OK=0      # Re-enable for critical sections
```

#### Logging
```bash
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Action description..."
log "Warning: Non-critical failure message"
log "FATAL: Critical error message"
```

#### Command Patterns
```bash
# Conditional execution with fallback
command || log "Warning: command failed (continuing)"

# Sudo for user operations
sudo -u $USERNAME bash -c 'command here'

# Config reading with defaults
VALUE=$(jq -r '.key // "default"' $CONFIG_PATH)

# Directory existence checks
if [ ! -d "/path/to/dir" ]; then
    mkdir -p /path/to/dir
fi

# Symlink creation (idempotent)
if [ ! -L "/path/to/link" ]; then
    ln -sf /target /path/to/link
fi
```

#### Section Structure
```bash
# Critical section (will exit on failure)
set -e
FAIL_OK=0
log "Starting critical operation..."
critical_command

# Optional section (failures logged but continue)
set +e
FAIL_OK=1
log "Installing optional tool..."
if ! optional_install_command; then
    log "Warning: Failed to install optional tool (continuing)"
fi

# Return to critical mode
set -e
FAIL_OK=0
```

### Dockerfile

#### Layer Optimization
- Combine related apt-get commands
- Clean up in same layer: `&& rm -rf /var/lib/apt/lists/*`
- Use multi-stage builds for large tool installations

#### Architecture Handling
```dockerfile
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        TOOL_ARCH="x86_64-unknown-linux-musl"; \
    elif [ "$ARCH" = "arm64" ]; then \
        TOOL_ARCH="aarch64-unknown-linux-gnu"; \
    fi && \
    # Install logic here
```

### YAML Files (config.yaml)

- Use quotes for string values with special characters
- Schema types: `str?`, `int(min,max)?`, `bool?`
- Ports format: `"2322/tcp": 2322`

## Key Conventions

### Persistent Storage
All user data MUST persist in `/data/`:
| Path | Purpose |
|------|---------|
| `/data/user_config` | `~/.config` symlink target |
| `/data/user_local` | `~/.local` symlink target |
| `/data/npm_global` | npm global packages |
| `/data/rust_cargo` | Rust/Cargo home (RUSTUP_HOME + CARGO_HOME) |
| `/data/go_workspace` | Go modules and binaries (GOPATH) |
| `/data/ssh_host_keys` | SSH host keys |
| `/data/user_ssh_keys` | User SSH keypair + config + known_hosts |
| `/data/claude_config` | `~/.claude` + `~/.claude.json` |
| `/data/codex_config` | `~/.codex` |
| `/data/openclaw_config` | `~/.openclaw` |
| `/data/qwen_config` | `~/.qwen` |
| `/data/cli_proxy_api` | `~/.cli-proxy-api` |
| `/data/git_ai_commit_config` | `~/.git-ai-commit` |
| `/data/bun_home` | `~/.bun` |
| `/data/syncthing_config` | `~/.config/syncthing` |
| `/data/user_scripts` | `~/scripts` (synced via Syncthing) |
| `/data/zsh_history` | `~/.zsh_history` |
| `/data/dolt_db` | Dolt database files |

### Persistent Storage Pattern
```bash
mkdir -p /data/some_config
chown $USERNAME:$USERNAME /data/some_config

if [ ! -L "/home/$USERNAME/.some_config" ]; then
    if [ -d "/home/$USERNAME/.some_config" ]; then
        sudo -u $USERNAME cp -r /home/$USERNAME/.some_config/. /data/some_config/ 2>/dev/null || true
        rm -rf /home/$USERNAME/.some_config
    fi
    sudo -u $USERNAME ln -sf /data/some_config /home/$USERNAME/.some_config
fi
```

### NVM/npm Conflict Prevention
```bash
# CORRECT: Unset before loading NVM (handled in env.sh)
unset NPM_CONFIG_PREFIX
export NVM_DIR="/opt/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# WRONG: Setting NPM_CONFIG_PREFIX with NVM
export NPM_CONFIG_PREFIX="/data/npm_global"  # Conflicts with NVM!
```

### Shell Config Management
Shell config is regenerated every startup via `setup-zsh.sh --force`. Static environment goes in rootfs:
- `rootfs/etc/shell/env.sh` — PATH, tool homes, Claude symlink repair
- `rootfs/etc/shell/aliases.sh` — all aliases and shell functions
- `rootfs/etc/shell/zsh-extra.sh` — zoxide, mcfly init, custom scripts

### Tool Installation Pattern
```bash
# Idempotent: check before installing
if ! command -v toolname >/dev/null 2>&1; then
    log "Installing ToolName..."
    set +e
    FAIL_OK=1
    # install commands here
    set -e
    FAIL_OK=0
fi
```

### Neovim/LazyVim Config
- LazyVim starter cloned to `~/.config/nvim/` on first run
- Django LSP plugin copied from `/etc/nvim/plugins/django.lua`
- `lazyvim.json` updated to enable `lang.python` extras
- Config persists via `/data/user_config/nvim/` (through `~/.config` symlink)

## CI/CD

Git tag push (`v*.*.*`) triggers `.github/workflows/docker-build.yaml`:
1. Build with `docker/build-push-action` (context: `python_dev_env/`)
2. Push to Docker Hub: `ksw8954/python-dev-env:{version}` + `:latest`
3. Create GitHub Release with auto-generated changelog

## Important Notes

1. **Protection Mode**: Add-on requires protection mode disabled for Docker API access
2. **First Run**: Initial setup is slow (installs many tools); subsequent runs are fast
3. **SSH Keys**: Host keys persist; user keys generated on first run
4. **Version Bumps**: Update `version` in `python_dev_env/config.yaml` for each release
5. **Architecture**: Currently amd64 only (Dockerfile handles arm64 for some tools but config.yaml restricts to amd64)
6. **Claude Token Refresh**: Daemon auto-refreshes OAuth token before expiry if credentials exist

## Common Pitfalls

- Don't use `npm config set prefix` with nvm — causes conflicts
- Don't hardcode architecture — always detect with `dpkg --print-architecture`
- Don't forget to restore strict mode (`set -e`) after optional sections
- Don't create files in user home without `sudo -u $USERNAME`
- Don't assume tools exist — always check or use `|| true` fallback
- Don't edit `.zshrc`/`.bashrc` directly — they're regenerated every startup by `setup-zsh.sh`; put persistent config in `rootfs/etc/shell/`
- Don't write to `~/.config` before persistent storage symlinks are set up in run.sh
