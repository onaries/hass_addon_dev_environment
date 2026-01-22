# AGENTS.md - Coding Agent Guidelines

## Project Overview

Home Assistant add-on providing a multi-language development environment with SSH access, persistent storage, and modern dev tools. Debian Bookworm-based, multi-architecture (amd64, aarch64, armhf, armv7, i386).

## Build & Test Commands

```bash
# Build Docker image locally (amd64)
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm -t dev-env .

# Build for arm64
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm -t dev-env-arm64 .

# Test run.sh syntax
bash -n run.sh

# Lint shell scripts with shellcheck
shellcheck run.sh

# Validate YAML files
yamllint config.yaml build.yaml repository.yaml

# Test container startup
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock dev-env /run.sh
```

## Project Structure

```
.
├── config.yaml       # Add-on metadata, options schema, port mappings
├── build.yaml        # Architecture-specific base images
├── repository.yaml   # Repository metadata
├── Dockerfile        # Multi-stage build with all tools
├── run.sh            # Main startup script (user setup, services)
├── README.md         # User documentation
├── CHANGELOG.md      # Version history
└── knowledge.md      # Internal architecture docs
```

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
| `/data/rust_cargo` | Rust/Cargo home |
| `/data/go_workspace` | Go modules and binaries |
| `/data/ssh_host_keys` | SSH host keys |
| `/data/user_ssh_keys` | User SSH keypair |

### NVM/npm Conflict Prevention
```bash
# CORRECT: Unset before loading NVM
echo 'unset NPM_CONFIG_PREFIX' >> ~/.zshrc
echo 'export NVM_DIR="/opt/nvm"' >> ~/.zshrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
echo 'export PATH="/data/npm_global/bin:$PATH"' >> ~/.zshrc

# WRONG: Setting NPM_CONFIG_PREFIX with NVM
echo 'export NPM_CONFIG_PREFIX="/data/npm_global"' >> ~/.zshrc  # Conflicts!
```

### User Setup Pattern
```bash
# Check if setup needed (idempotent)
if [ ! -d "/home/$USERNAME/.local/share/zinit" ]; then
    log "Setting up user environment..."
    # Setup commands here
fi
```

### Tool Installation Pattern
```bash
log "Installing ToolName..."
if ! sudo -u $USERNAME bash -c 'curl -fsSL https://example.com/install.sh | bash'; then
    log "Warning: Failed to install ToolName (continuing)"
fi
```

## Important Notes

1. **Protection Mode**: Add-on requires protection mode disabled for Docker API access
2. **First Run**: Initial setup is slow (installs many tools); subsequent runs are fast
3. **SSH Keys**: Host keys persist; user keys generated on first run
4. **Version Bumps**: Update `version` in `config.yaml` for each release
5. **Multi-arch**: Test changes on both amd64 and arm64 when possible

## Common Pitfalls

- Don't use `npm config set prefix` with nvm - causes conflicts
- Don't hardcode architecture - always detect with `dpkg --print-architecture`
- Don't forget to restore strict mode (`set -e`) after optional sections
- Don't create files in user home without `sudo -u $USERNAME`
- Don't assume tools exist - always check or use `|| true` fallback
