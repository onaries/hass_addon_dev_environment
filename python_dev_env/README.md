# Home Assistant Add-on: Multi-Language Development Environment

![Supports amd64 Architecture][amd64-shield]

A comprehensive multi-language development environment for Home Assistant with Python 3.11, Node.js, Rust, Go, AI tools, SSH access, modern shell (zsh + Zinit), Neovim with LazyVim, and essential development tools with persistent storage.

## About

This add-on provides a full-featured multi-language development environment including:

### Programming Languages
- **Python 3.11**: System Python with uv package manager and pre-commit
- **Node.js LTS**: Via nvm with persistent npm global packages
- **Rust**: Latest stable with Cargo and persistent crates storage
- **Go 1.25**: With persistent GOPATH and module cache

### AI Tools
- **Claude CLI**: AI-powered development assistant (`ccc` alias for quick access)
- **Codex CLI**: OpenAI Codex (`codex-yolo` alias)
- **OpenCode**: AI coding assistant
- **OpenChamber**: AI development tool
- **OpenClaw**: AI gateway (port 18789)
- **Qwen Code**: Alibaba AI assistant
- **git-ai-commit**: AI-powered conventional commit generation (`gac` alias)

### Development Tools
- **Neovim + LazyVim**: Pre-configured modern editor
- **GitUI**: Terminal-based Git interface
- **Just**: Command runner for project automation
- **act**: Run GitHub Actions locally
- **gh**: GitHub CLI
- **Docker CLI & Compose**: Container development support
- **pre-commit**: Git hook framework

### Infrastructure
- **SSH Access**: Secure remote access via configurable port with persistent keys
- **Syncthing**: File synchronization (Web GUI port 8384)
- **CLIProxyAPI**: API proxy service (port 8317)
- **Modern Shell**: zsh + Zinit + 150+ git aliases (oh-my-zsh style)
- **Terminal Tools**: zellij, tmux, ripgrep, delta, lsd, duf, mcfly, zoxide

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

### Option: `git_name` / `git_email`

Configure git identity for commits.

```yaml
git_name: "Your Name"
git_email: "you@example.com"
```

### Option: `cliproxy_api_keys`

API keys for CLIProxyAPI service.

```yaml
cliproxy_api_keys:
  - "your-api-key"
```

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 2322 | SSH | Configurable via `ssh_port` |
| 8317 | CLIProxyAPI | API proxy service |
| 8384 | Syncthing | Web GUI for file sync |
| 18789 | OpenClaw | AI gateway |
| 22000 | Syncthing | P2P file transfer (TCP/UDP) |

## Available Commands

Once connected via SSH, you have access to:

```bash
# Programming Languages
python3       # Python 3.11
uv            # Ultra-fast Python package manager
pre-commit    # Git hook framework
node          # Node.js LTS
npm           # Node package manager (persistent global packages)
rustc         # Rust compiler
cargo         # Rust package manager
go            # Go programming language

# AI Tools
claude        # Claude CLI for AI assistance
ccc           # Quick Claude access (--dangerously-skip-permissions)
codex         # OpenAI Codex CLI
opencode      # OpenCode AI assistant
gac           # git-ai-commit (conventional commits)

# Development Tools
nvim          # Neovim with LazyVim
gitui         # Terminal-based Git UI
just          # Command runner
act           # Run GitHub Actions locally
gh            # GitHub CLI
docker        # Docker CLI
docker compose # Docker Compose

# Terminal Tools
zellij        # Modern terminal multiplexer
tmux          # Traditional terminal multiplexer
rg            # ripgrep (fast search)
delta         # Git diff viewer
lsd           # Modern ls replacement
mcfly         # Shell history search
zoxide        # Smart directory jumper (z)
```

## Persistent Storage

All user data is automatically preserved across container rebuilds and add-on updates:

- **SSH Keys**: Both host keys and user SSH keys
- **Configurations**: ~/.config, ~/.local directories
- **Language Packages**: npm global, Cargo crates, Go modules
- **AI Settings**: Claude Code (인증, 설정, 플러그인, statusbar), Codex, OpenClaw, Qwen
- **Runtime**: Bun, uv tools (pre-commit 등)
- **Development Workspace**: Your projects and files
- **Shell History**: zoxide directory history

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

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[issue]: https://github.com/onaries/hass_addon_dev_environment/issues
