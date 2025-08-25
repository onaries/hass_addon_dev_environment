# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2025-08-25

### Added
- DAC_READ_SEARCH 권한 추가로 Docker 접근 개선
- ubuntu_data 볼륨에서 share/workspace로 자동 데이터 마이그레이션 기능
- 일회성 마이그레이션 방지를 위한 .migrated 플래그 파일

### Changed
- 볼륨 마운트 방식을 Home Assistant 표준 share 볼륨 사용으로 변경
- /workspace가 /share/workspace로 심볼릭 링크되도록 개선

### Fixed
- ubuntu_data 커스텀 볼륨 마운트 문제 해결
- Docker 소켓 접근을 위한 적절한 권한 설정

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