# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Home Assistant add-on that provides a Debian Bookworm-based multi-language development environment (Python 3.11, Node.js LTS, Rust, Go) with SSH access, persistent storage, and modern dev tools. Docker image published to `ksw8954/python-dev-env` on Docker Hub.

## Build & Test Commands

```bash
# Build Docker image locally (run from repo root)
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm -t dev-env python_dev_env/

# Build for arm64
docker build --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm -t dev-env-arm64 python_dev_env/

# Lint shell scripts
shellcheck python_dev_env/run.sh

# Check run.sh syntax without executing
bash -n python_dev_env/run.sh

# Validate YAML
yamllint python_dev_env/config.yaml python_dev_env/build.yaml repository.yaml

# Test container startup
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock dev-env /run.sh
```

## Release Process

Update `version` in `python_dev_env/config.yaml`, then push a git tag matching `v*.*.*` to trigger GitHub Actions CI/CD which builds and pushes to Docker Hub.

## Architecture

The add-on code lives entirely in `python_dev_env/`. Key files:

- **`Dockerfile`** — Multi-arch image build. Installs system packages, detects architecture via `dpkg --print-architecture` for binary downloads, sets up NVM/Node.js, configures locale and git delta pager.
- **`run.sh`** — Main entrypoint (~900 lines). Handles timezone, Docker socket, user creation, SSH setup, and first-run initialization (LazyVim, zsh/Zinit, Node.js, AI tools). First run is slow; subsequent runs restore from persistent `/data/` storage.
- **`config.yaml`** — Add-on metadata, version, port mappings (SSH:2322, Syncthing:8384, CLIProxyAPI:8317), and user-configurable options schema.
- **`build.yaml`** — Maps architectures to base images.
- **`rootfs/etc/shell/`** — Shell environment modules: `env.sh` (PATH/env vars), `aliases.sh` (150+ git aliases, tool aliases), `zsh-extra.sh` (zoxide, tab completion).

## Key Patterns

**Error handling in run.sh**: Critical sections use `set -e` with `FAIL_OK=0`. Optional tool installations wrap with `set +e; FAIL_OK=1` and restore afterward. A trap handler logs failing commands.

**User operations**: Always use `sudo -H -u $USERNAME bash -c 'command'` for operations in the dev user context.

**Config reading**: `jq -r '.key // "default"' $CONFIG_PATH` for reading add-on options with defaults.

**Persistent storage**: All user data lives in `/data/` and is symlinked into the user home (`/data/user_config` → `~/.config`, `/data/user_local` → `~/.local`, `/data/npm_global`, `/data/rust_cargo`, `/data/go_workspace`, `/data/ssh_host_keys`, `/data/user_ssh_keys`).

**NVM/npm conflict**: Never set `NPM_CONFIG_PREFIX` — it breaks NVM. The shell startup unsets it before sourcing NVM, and global packages go in `/data/npm_global` via PATH.

**Architecture detection**: Never hardcode arch. Always detect with `dpkg --print-architecture` and branch for binary downloads.

**Idempotent setup**: First-run detection checks for `/home/$USERNAME/.local/share/zinit`. Directory/symlink creation uses existence checks before acting.

## Pitfalls

- Restore `set -e; FAIL_OK=0` after every optional section
- Files created in user home must use `sudo -u $USERNAME` or they'll be owned by root
- The add-on requires `full_access: true` and `docker_api: true` plus protection mode disabled
- Test on both amd64 and arm64 when modifying architecture-dependent code
