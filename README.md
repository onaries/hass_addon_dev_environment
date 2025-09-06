# Home Assistant Add-on: Multi-Language Development Environment

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

A comprehensive multi-language development environment for Home Assistant with Python 3.13, Node.js, Rust, Go, AI tools, SSH access, modern shell (zsh + oh-my-zsh), Neovim with LazyVim, and essential development tools with persistent storage.

## About

This add-on provides a full-featured multi-language development environment including:

### Programming Languages
- **Python 3.11**: System Python version with package management tools
- **Node.js LTS**: Via nvm with persistent npm global packages
- **Rust**: Latest stable with Cargo and persistent crates storage
- **Go 1.21.5**: With persistent GOPATH and module cache

### Development Tools
- **Claude CLI**: AI-powered development assistant with `ccc` alias
- **GitUI**: Terminal-based Git interface
- **Just**: Command runner for project automation
- **Neovim + LazyVim**: Pre-configured modern editor
- **Docker CLI & Compose**: Container development support

### Infrastructure
- **SSH Access**: Secure remote access via configurable port with persistent keys
- **Modern Shell**: zsh with oh-my-zsh configuration
- **Terminal Multiplexer**: Zellij for session management
- **Persistent Storage**: All configurations and packages survive rebuilds
- **File Access**: Home Assistant config, addons, and shared directories

## Important Setup Requirements

⚠️ **This addon requires Home Assistant Protection Mode to be disabled** due to its need for Docker API access and system-level permissions.

1. Go to **Settings** → **Add-ons** → **Advanced**
2. Disable **Protection mode**
3. Restart Home Assistant
4. Install and configure this addon

## Configuration

### Option: `ssh_keys`

Add one or more SSH public keys to allow passwordless SSH access.

```yaml
ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEa+wW1Vb5pEJ2qQ..."
```

### Option: `password`

Set a password for the root user (optional if using SSH keys).

```yaml
password: "mypassword"
```

### Option: `ssh_port`

Configure the SSH port (default: 2322).

```yaml
ssh_port: 2322
```

### Option: `username`

Set the development user name (default: "developer").

```yaml
username: "developer"
```

### Option: `user_password`

Set a password for the development user.

```yaml
user_password: "devpassword"
```

## Available Commands

Once connected via SSH, you have access to:

```bash
# Programming Languages
python3       # Python 3.11
uv            # Ultra-fast Python package manager
node          # Node.js LTS
npm           # Node package manager (persistent global packages)
rustc         # Rust compiler
cargo         # Rust package manager
go            # Go programming language

# Development Tools
nvim          # Neovim with LazyVim
vim           # Alias to nvim
claude        # Claude CLI for AI assistance
ccc           # Quick Claude access (alias)
gitui         # Terminal-based Git UI
just          # Command runner
docker        # Docker CLI
docker-compose # Docker Compose

# Terminal Tools
zellij        # Modern terminal multiplexer (amd64)
tmux          # Traditional terminal multiplexer
htop          # Process monitor
tree          # Directory structure viewer
```

## Persistent Storage

All user data is automatically preserved across container rebuilds:

- **SSH Keys**: Both host keys and user SSH keys
- **Configurations**: ~/.config, ~/.local directories
- **Language Packages**: npm global, Cargo crates, Go modules
- **Claude Settings**: Authentication and configuration
- **Development Workspace**: Your projects and files

## Multi-Language Development Examples

```bash
# Python with uv
uv init my-python-project
cd my-python-project
uv add fastapi uvicorn

# Node.js project
npm init -y
npm install -g typescript
npm install express

# Rust project
cargo new my-rust-app
cd my-rust-app
cargo add serde tokio

# Go project
go mod init my-go-app
go get github.com/gin-gonic/gin

# Use AI assistance
ccc "Help me optimize this function"
```

## Support

Got questions?

You could [open an issue here][issue] on GitHub.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[issue]: https://github.com/yourusername/hass-python-dev-addon/issues
