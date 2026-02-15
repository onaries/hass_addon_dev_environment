# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.12] - 2026-02-15

### Fixed

- HOME 환경변수 미설정으로 인한 git config 실패 수정

## [1.2.11] - 2026-02-15

### Added

- npm 전역 패키지 자동 설치 로직 추가
- OpenClaw 게이트웨이 서비스 추가
- SSH 설정 지속성 개선

### Changed

- Shell 환경 설정 구조 개선 및 rootfs 기반 모듈화 적용
- 복잡한 git 별칭을 셸 함수로 변환

### Fixed

- Bun 설치를 Codex CLI 앞으로 이동하여 의존성 해결
- 기존 Rust 설치 시 rustup update 사용하여 충돌 방지
- ssh-copy-id 전에 사용자 SSH 키 생성하도록 순서 변경
- OpenChamber 설치 시 NVM 소싱 추가

## [1.2.10] - 2026-02-06

### Added

- 사용자 스크립트 영구 저장소 설정 및 zsh 단축 함수 추가

## [1.2.9] - 2026-02-06

### Fixed

- CLIProxyAPI 포트 바인딩 및 경로 설정 오류 수정

## [1.2.8] - 2026-02-04

### Fixed

- Supervisor 서비스에 XDG 환경변수 추가

## [1.2.7] - 2026-02-04

### Added

- Syncthing 파일 동기화 도구 추가
- Supervisor 프로세스 관리 도입

### Fixed

- Supervisor 서비스에 HOME 환경변수 및 working directory 추가

## [1.2.5] - 2026-02-04

### Added

- CLIProxyAPI 토큰 동기화 기능 추가

### Changed

- 외부 도구 버전 추출 로직의 에러 처리 개선

### Fixed

- 도구 설치 로직의 안정성 개선 및 최적화
- 설치 오류 수정

## [1.2.4] - 2026-02-02

### Added

- OpenClaw AI 어시스턴트 추가
- CLIProxyAPI 설정 및 opencode 토큰 동기화 기능 추가
- Zsh 탭 완성 순환 설정 추가

## [1.2.3] - 2026-01-27

### Fixed

- SSH 터미널 UTF-8 로케일 설정 추가
- 터미널 렌더링을 위한 UTF-8 로캘 설정 추가

## [1.2.2] - 2026-01-26

### Changed

- HA addon 저장소 구조 변경 및 Docker Hub 설정 수정

## [1.2.1] - 2026-01-25

### Added

- GitHub Actions CI/CD 및 Docker Hub 배포 설정

## [1.2.0] - 2026-01-25

### Added

- Zinit 플러그인 매니저로 전환
- GitHub CLI (gh) 설치
- Git aliases 추가

## [1.1.0] - 2026-01-25

### Added

- rsync 설치
- Bun 런타임 설치
- 개발용 패키지 추가 (net-tools, iputils-ping, sqlite3, libssl-dev, libffi-dev)
- gac, codex-update, codex-yolo alias 추가

### Changed

- Codex CLI 설치를 npm에서 bun으로 변경

### Fixed

- Bun 설치를 위한 unzip 패키지 추가

## [1.0.5] - 2026-01-25

### Added

- 현대적인 CLI 도구 추가 (lsd, duf, ripgrep, delta, mcfly, glances)
- Git 사용자 이름/이메일 설정 기능 추가
- qwen-code CLI 도구 및 .qwen 경로 지원 추가
- Rust, Go, Just 개발 도구 추가 및 영구 저장소 설정
- GitUI 터미널 Git 인터페이스 도구 추가
- 사용자 ~/.local 디렉토리 영구 저장
- NVM 사용자 권한 및 npm global 패키지 영구 저장 설정
- 사용자 .config 디렉토리를 영구 저장소에 마운트
- 사용자 SSH 키를 영구 저장소에 마운트
- Claude CLI 단축 명령어 alias와 uv Python 패키지 매니저 설치
- SSH 호스트 키와 Claude CLI 설정을 영구 저장소에 마운트

### Fixed

- zsh 시작 시 nvm/npm 충돌 경고 해결
- SSH 호스트 키 권한을 600으로 설정
- 서비스 안정성 개선 및 오류 처리 강화
- 스크립트 오류 처리 및 설치 단계 견고성 향상
- root 사용자용 Claude Code 인증 영구 저장 추가

## [1.0.2] - 2026-01-25

### Added

- 볼륨 마운트 시스템 개선 및 자동 마이그레이션 기능 추가
- Docker 완전 접근 권한 및 그룹 권한 관리 추가
- Node.js LTS 및 Claude CLI 자동 설치 추가
- 일반 사용자의 Docker CLI 사용을 위한 그룹 권한 설정 개선
- Claude CLI 설치 후 사용자 PATH에 ~/.local/bin 자동 추가
- Workspace 디렉토리에 사용자 접근 권한 부여

### Changed

- ubuntu_data 볼륨 직접 매핑 및 워크스페이스 구조 개선
- full_access 모드 전환 및 Docker 통합 개선

### Fixed

- Docker 소켓 권한 변경 시 read-only 파일 시스템 에러 처리 개선
- ubuntu_data 볼륨 마운트 권한 및 디바이스 매핑 추가

## [1.0.1] - 2026-01-25

### Added

- Docker 및 추가 개발 도구 지원 추가

### Fixed

- 멀티 아키텍처 지원을 위한 바이너리 설치 방식 개선
- Dockerfile 빌드 오류 해결
- 로컬 빌드를 위한 외부 이미지 참조 제거

## [1.0.0] - 2026-01-25

### Added

- Home Assistant Python 개발환경 애드온 초기 구현
- SSH 접근 기능
- 멀티 아키텍처 지원 (amd64, aarch64, armhf, armv7, i386)
- Debian Bookworm 기반 개발 환경
