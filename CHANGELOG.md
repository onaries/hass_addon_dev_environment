# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-01-05

### Added
- `rsync` 설치: 파일 동기화 및 전송을 위한 도구 추가

## [1.0.9] - 2025-12-26

### Added
- `gac` alias for `git-ai-commit` command
- `codex-update` alias for updating Codex CLI (`bun i -g @openai/codex@latest`)
- `codex-yolo` alias for running Codex in yolo mode (`codex --yolo`)

## [1.0.8] - 2025-12-24

### Added
- Pre-add known SSH hosts (git.safemotion.kr, github.com) to avoid interactive prompts during git operations
- Project architecture and workflow documentation in knowledge.md
- Codebuff project configuration template (codebuff.json)

## [1.0.7] - 2025-12-21

### Added
- OpenCode CLI 자동 설치

## [1.0.6] - 2025-11-28

### Added
- lsd (LSDeluxe) - 아이콘이 포함된 현대적인 ls 대체 도구
- duf - 직관적인 디스크 사용량 표시 도구
- ripgrep (rg) - 빠른 코드 검색 도구 (GitHub releases에서 설치)
- delta (git-delta) - 향상된 git diff 뷰어
- mcfly - AI 기반 Ctrl+R 히스토리 검색 도구
- glances - 종합 시스템 모니터링 도구 (htop 대체)

### Changed
- git 기본 pager를 delta로 설정하여 diff 가독성 향상
- bash/zsh에 mcfly 자동 초기화 설정 추가
- delta 설정: 라인 번호, diff3 충돌 스타일, colorMoved 활성화

## [1.0.5] - 2025-11-07

### Added
- Codex CLI 자동 설치 및 `/data/codex_config` 영구 저장소 연동으로 API 자격 증명 보존
- CLIProxyAPI 설치 스크립트 실행 및 사용자 수준 systemd 서비스 자동 구성
- CLIProxyAPI 설정(`~/.config/cliproxyapi`)과 런타임 캐시(`~/.cli-proxy-api`)를 `/data` 하위로 백업하여 재빌드 후에도 유지
- git-ai-commit CLI 자동 설치 및 `.git-ai-commit/config.json`을 `/data/git_ai_commit_config`로 리다이렉트해 API 설정 유지

### Changed
- Go 툴체인을 v1.25.4로 업데이트하여 최신 언어 기능과 보안 패치 적용
- CLIProxyAPI 서비스가 `loginctl enable-linger`와 함께 항상 부팅 시 시작되도록 자동화

## [1.0.4] - 2025-08-28

### Added
- GitUI 터미널 Git 인터페이스 도구 (v0.27.0)
- Just command runner - 프로젝트 작업 자동화 도구
- Rust 프로그래밍 언어 및 Cargo 패키지 매니저
- Go 프로그래밍 언어 (v1.21.5) 및 Go 워크스페이스

### Changed
- Rust 툴체인을 `/data/rust_cargo`에 영구 저장 (`RUSTUP_HOME`, `CARGO_HOME`)
- Go 워크스페이스를 `/data/go_workspace`에 영구 저장 (`GOPATH`)
- 사용자 `.local` 디렉토리를 `/data/user_local`에 영구 저장
- npm global 패키지를 `/data/npm_global`에 영구 저장
- `/opt/nvm` 디렉토리에 사용자 소유권 부여

### Developer Experience
- 다중 프로그래밍 언어 지원 (Python, Node.js, Rust, Go)
- 터미널 기반 Git 관리 (`gitui` 명령어)
- 작업 자동화 (`just` 명령어로 Justfile 실행)
- 모든 언어별 패키지와 툴체인이 재빌드 시에도 유지
- Cargo crates, Go modules, pip packages 영구 저장

## [1.0.3] - 2025-08-27

### Added
- Claude CLI 자동 설치 및 설정 (`claude` 명령어 지원)
- Claude CLI 단축 명령어 alias (`ccc="claude --dangerously-skip-permissions"`)
- uv Python 패키지 매니저 설치
- 사용자별 SSH 키 자동 생성 (`$USERNAME@hass-addon-dev` 형태)
- Docker CLI 설치 및 일반 사용자 접근 권한 설정
- Node.js LTS 자동 설치 (NVM 통해)

### Fixed
- Docker 소켓 권한 변경 시 read-only 파일 시스템 에러 처리 개선
- 일반 사용자의 Docker CLI 사용을 위한 그룹 권한 설정 (`_ssh` 그룹 추가)
- 기존 사용자도 docker 그룹에 자동 추가되도록 개선

### Changed
- SSH 호스트 키를 `/data/ssh_host_keys`에 영구 저장하여 재빌드 시 일관성 유지
- 사용자 SSH 키를 `/data/user_ssh_keys`에 영구 저장
- Claude CLI 설정을 `/data/claude_config`에 영구 저장 (`~/.claude`, `~/.claude.json`)
- 사용자 `.config` 디렉토리를 `/data/user_config`에 영구 저장
- workspace 디렉토리에 사용자 접근 권한 부여 및 소유권 설정
- 사용자 PATH에 `~/.local/bin` 자동 추가
- Neovim installation method: switched to tarball distribution on amd64 architecture for better performance and compatibility
- AppImage installation retained as fallback for non-amd64 architectures

### Developer Experience
- 개발 환경 재빌드 시에도 모든 설정과 키가 유지됨
- Claude CLI를 통한 AI 개발 지원
- Docker 컨테이너 빌드 및 실행 지원
- Python 프로젝트를 위한 uv 패키지 매니저
- SSH 키 재생성 불필요로 GitHub 등 외부 서비스 재설정 최소화

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
