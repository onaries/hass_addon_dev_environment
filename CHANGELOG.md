# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2025-08-25

### Added
- Docker CLI and Docker Compose support
- System monitoring tools (htop, tree)
- tmux terminal multiplexer as alternative to zellij

### Fixed
- Multi-architecture binary installation issues
- Dockerfile build errors with package dependencies
- AppImage support for neovim (latest version with LazyVim compatibility)
- External image reference removed for local builds
- Improved stability across different architectures

### Changed
- Switched from package manager neovim to AppImage for better version control
- zellij now only installs on amd64 architecture to prevent build failures

## [1.0.0] - 2025-08-25

### Added
- Initial release
- Python 3.13 development environment
- SSH access with configurable port (default: 2322)
- zsh shell with oh-my-zsh configuration
- Neovim with LazyVim pre-configured
- Node.js via nvm (latest LTS)
- Zellij terminal multiplexer
- Docker socket access
- Configurable user account with passwordless sudo
- SSH key and password authentication support
- Home Assistant directory mapping (config, addons, share, etc.)

### Features
- Multi-architecture support (aarch64, amd64, armhf, armv7, i386)
- Automatic tool installation and configuration
- Modern development tools pre-installed
- Secure SSH access with customizable settings