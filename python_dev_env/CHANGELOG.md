# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.24] - 2026-02-26

### Added

- HA ingress 기반 상태 대시보드 웹 UI 추가
  - Python HTTP 대시보드 서버 (`dashboard-server.py`, 포트 8099)
  - 다크 테마 대시보드 HTML (`index.html`, JetBrains Mono + DM Sans, 30초 자동 새로고침)
  - 도구 버전 확인 (29개 도구, 4개 카테고리: 언어/인프라/개발도구/AI)
  - supervisor 서비스 상태 실시간 표시 (RUNNING/STOPPED/STARTING)
  - 최근 SSH 접속 기록 (현재 세션 하이라이트)
  - tmux 세션 조회 (attached/detached 상태)
- `config.yaml`에 HA ingress 설정 추가 (`ingress: true`, `ingress_port: 8099`, `panel_icon: mdi:monitor-dashboard`, `panel_title: Dev Environment`)
- supervisord에 dashboard 프로세스 등록 (priority 15)

### Fixed

- `setup-zsh.sh` completion 생성 시 NVM 및 사용자 도구 PATH 누락 수정
  - completion 생성 전 NVM source 및 `~/.local/bin`, `~/.opencode/bin`, `~/.bun/bin`, `/data/rust_cargo/cargo/bin` 등을 PATH에 추가
  - 기존 4개(delta, docker, rg, zellij) → 12개 도구 completion 파일 정상 생성 (git-ai-commit, openclaw, opencode, gh, just, uv, bun, codex 추가)


## [1.2.22] - 2026-02-22

### Added

- fzf 바이너리 설치 추가 (Dockerfile, 아키텍처별 GitHub releases)
- 주요 CLI 도구 zsh 탭 완성 자동 생성: git-ai-commit, openclaw, opencode, gh, just, docker, rustup, uv, zellij, delta, bun, codex, rg
- `gac` alias에 `compdef gac=git-ai-commit` 완성 연결
- mcfly init을 `zsh-extra.sh`에 추가하여 Ctrl+R 히스토리 검색 활성화

## [1.2.21] - 2026-02-21

### Added

- first-run 이후에도 누락 도구 자동 설치: LazyVim, Node.js LTS, Bun, Rust, Docker CLI, CLIProxyAPI
  - 기존 first-run 블록에서만 설치되던 도구들을 매 시작 시 존재 여부 체크 후 설치

### Changed

- README 최신 기능 및 포트 정보 반영 (AI 도구, Syncthing, CLIProxyAPI 등)

### Removed

- `env.sh`에서 npm global path (`/data/npm_global/bin`) 제거

## [1.2.20] - 2026-02-21

### Fixed

- Claude Code 자가 업데이트 후 인증/설정 유실 방지: `~/.claude` 심링크 복구 로직 개선
  - 자가 업데이트로 심링크가 일반 디렉토리로 교체되는 경우 바이너리만 갱신하고 인증 정보 보존
- 누락 도구(Claude CLI, uv, pre-commit, zoxide, Fresh, OpenChamber, OpenCode, Go 등) 매 시작 시 자동 설치

## [1.2.19] - 2026-02-20

### Added

- 영구 저장소 개선: Bun, uv tools, Qwen Code 설정을 `/data` 하위로 영구 저장
- 바이너리 자동 복구: GitUI, gh, Just, act 등 시스템 바이너리 누락 시 자동 재설치

## [1.2.18] - 2026-02-20

### Changed

- `setup-zsh.sh`를 매 컨테이너 시작 시 `--force`로 실행하여 항상 최신 zsh/bash 설정 적용

## [1.2.17] - 2026-02-20

### Added

- zinit/zshrc 설정을 독립 스크립트(`setup-zsh.sh`)로 분리
  - `rootfs/usr/local/bin/setup-zsh.sh`로 zsh 테마, 플러그인, 키바인딩 설정 모듈화
  - `--force` 옵션으로 zinit 재설치 지원

## [1.2.16] - 2026-02-20

### Fixed

- supervisor 설정 생성 시 getcwd 오류 수정: 서비스에 `directory` 지시자 추가

## [1.2.15] - 2026-02-20

### Fixed

- 컨테이너 재시작 시 `.zshrc`/`.bashrc` 유실로 zinit 미작동 문제 수정

## [1.2.14] - 2026-02-20

### Fixed

- SSH authorized_keys 설정 시 `~/.ssh` 디렉토리 미존재로 인한 "No such file or directory" 오류 수정
  - 첫 실행이 아닌 재시작 시 `.ssh` 디렉토리가 없을 수 있는 문제 해결
  - root 및 일반 사용자 모두에 대해 `mkdir -p`로 디렉토리 생성 및 권한(700) 설정 추가

## [1.2.11] - 2026-02-15

### Added
- npm 전역 패키지 자동 설치: `config.yaml`의 패키지 목록을 컨테이너 시작 시 자동 설치
- OpenClaw 게이트웨이 서비스: 포트 18789 외부 노출 및 supervisor 서비스 등록
- SSH 설정 지속성 개선: `/data/ssh_config` → `~/.ssh/config` 영구 저장

### Changed
- Shell 환경 설정 rootfs 기반 모듈화 적용: 설정 파일을 `rootfs/` 구조로 분리
- 복잡한 git 별칭을 셸 함수로 변환: 인자 처리가 필요한 alias를 function으로 리팩터링

### Fixed
- Bun 설치를 Codex CLI 앞으로 이동하여 의존성 순서 해결
- 기존 Rust 설치 시 `rustup update` 사용하여 재설치 충돌 방지
- `ssh-copy-id` 전에 사용자 SSH 키 생성하도록 순서 변경
- OpenChamber 설치 시 NVM 소싱 누락 문제 해결

## [1.2.10] - 2026-02-06

### Added
- 사용자 스크립트 영구 저장소: `/data/user_scripts` → `~/scripts` (Syncthing 동기화 대상)
- zsh 단축 함수: `_server`, `_kid`, `_my` (서버 접속 스크립트 래퍼)

## [1.2.9] - 2026-02-06

### Added
- CLIProxyAPI 포트 8317 외부 노출: `config.yaml` 포트 매핑 추가

### Fixed
- CLIProxyAPI `auth-dir` 미설정으로 인한 빈 경로 오류 해결: config에 `auth-dir: /data/cli_proxy_api` 명시
- CLIProxyAPI 포트 0 바인딩 오류 해결: config에 `port: 8317` 명시

## [1.2.8] - 2026-02-04

### Fixed
- CLIProxyAPI auth 디렉토리 생성 실패 오류 해결
  - supervisor 환경변수에 `USER`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME` 추가
  - syncthing, cliproxyapi 모두 동일하게 적용

## [1.2.7] - 2026-02-04

### Fixed
- Supervisor 서비스 HOME 환경변수 미정의 오류 해결
  - syncthing: `directory`, `environment=HOME` 추가
  - cliproxyapi: `directory`, `environment=HOME` 추가

## [1.2.6] - 2026-02-04

### Added
- Syncthing 파일 동기화 도구 설치: Web GUI (포트 8384), 파일 전송 (포트 22000)
  - 설정 영구 저장소: `/data/syncthing_config` → `~/.config/syncthing`

### Changed
- 프로세스 관리를 supervisor로 전환: sshd, syncthing, cliproxyapi
  - 즉시 재시작, 로그 분리 (`/var/log/supervisor/`)
  - `supervisorctl status`로 서비스 상태 확인 가능

### Fixed
- Dockerfile 외부 도구 설치 안정성 개선: GitHub API 실패 시 fallback 버전 사용
  - ripgrep (15.1.0), delta (0.18.2), zellij (0.43.1), lsd (1.2.0), duf (0.9.1), mcfly (0.9.4)
- `[ -z "$VAR" ] && VAR="fallback" &&` 체인 오류 수정: `;`로 분리하여 조건 실패 시에도 계속 진행

## [1.2.5] - 2026-02-03

### Added
- CLIProxyAPI와 oh-my-opencode OAuth 토큰 자동 동기화: 컨테이너 시작 시 `~/.local/share/opencode/auth.json`에서 `~/.cli-proxy-api/`로 토큰 변환
  - anthropic → claude-opencode.json
  - openai → codex-opencode.json  
  - google → gemini-opencode.json (project_id 포함)

### Fixed
- root 사용자 git identity 설정 실패 문제 해결 (빈 배열 확장 오류)
- `just` 설치 실패 문제 해결: makedeb.org (502 에러) 대신 GitHub releases에서 직접 다운로드

## [1.2.4] - 2026-02-01

### Added
- OpenClaw AI 어시스턴트 설치: `npm install -g openclaw@latest`
- OpenClaw 설정 영구 저장소: `/data/openclaw_config` → `~/.openclaw`

## [1.2.3] - 2026-01-27

### Fixed
- SSH 터미널 프롬프트 잔상(ghosting) 문제 해결: UTF-8 로케일 설정 추가 (`LANG=C.UTF-8`)

## [1.2.2] - 2026-01-26

### Changed
- HA addon 저장소 구조 변경: addon 파일을 `python_dev_env/` 하위 디렉토리로 이동
- `image` 필드 수정: HA Supervisor 호환 형식으로 변경 (`ksw8954/python-dev-env`)
- 지원 아키텍처를 amd64 단일로 변경

## [1.2.1] - 2026-01-25

### Added
- GitHub Actions CI/CD 워크플로우: Docker 이미지 자동 빌드 및 Docker Hub 푸시
- Docker Hub 이미지 배포 지원: `ksw8954/python-dev-env` (amd64)

### Changed
- Home Assistant addon이 Docker Hub에서 이미지를 직접 pull하도록 설정

## [1.2.0] - 2026-01-22

### Added
- GitHub CLI (gh) 설치: PR, 이슈 관리를 위한 공식 GitHub CLI
- OpenChamber 설치: AI 코딩 도구
- Git aliases 80개+ 추가: oh-my-zsh 스타일 (gst, gaa, gcm, gp, grb 등)
- AGENTS.md: 코딩 에이전트를 위한 프로젝트 가이드라인 문서

### Changed
- oh-my-zsh를 Zinit으로 교체: 더 빠른 쉘 시작, 모듈화된 플러그인 관리
- NVM/NPM_CONFIG_PREFIX 충돌 해결: `unset NPM_CONFIG_PREFIX` 방식으로 변경
- 사용자 환경 체크 조건 변경: `.oh-my-zsh` → `.local/share/zinit`

### Fixed
- NVM과 npm global 패키지 충돌 문제 해결
- 불필요한 `fix_nvm_npm_conflict` 함수 제거

### Developer Experience
- Zinit 플러그인: zsh-completions, zsh-autosuggestions, fast-syntax-highlighting, fzf-history-search, zsh-autocomplete
- Git 워크플로우 개선: 포괄적인 git alias로 생산성 향상
- GitHub 통합: gh CLI로 터미널에서 PR/이슈 관리

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
