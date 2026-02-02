# Home Assistant Add-on Repository: Development Environment

![amd64][amd64-shield]

Home Assistant add-on repository providing a multi-language development environment with SSH access, persistent storage, and modern dev tools.

## Installation

1. **Home Assistant** > **Settings** > **Add-ons** > **Add-on Store**
2. 우측 상단 **...** > **Repositories**
3. 아래 URL 추가:

```
https://github.com/onaries/hass_addon_dev_environment
```

4. **Python Development Environment** 설치
5. **Protection mode** 비활성화 (Settings > Add-ons > 톱니바퀴)
6. Add-on 시작

## Add-ons

| Add-on | Description |
|--------|-------------|
| [Python Development Environment](./python_dev_env) | Python, Node.js, Rust, Go, AI tools, SSH, zsh, Neovim |

## Features

- **Languages**: Python 3.11, Node.js LTS, Rust, Go
- **AI Tools**: Claude CLI, Qwen Code
- **Editor**: Neovim + LazyVim
- **Shell**: zsh + Zinit + fzf + autosuggestions
- **Tools**: Docker CLI, GitUI, ripgrep, delta, lsd, mcfly
- **Persistent**: SSH keys, configs, packages all survive rebuilds
- **SSH**: Port 2322 (configurable)

## Development

```bash
# Build locally
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm \
  -t dev-env \
  python_dev_env/

# Test
docker run --rm dev-env /run.sh

# Lint
shellcheck python_dev_env/run.sh
```

## CI/CD

Git tag push (`v*.*.*`) triggers GitHub Actions to build and push to Docker Hub:

```
ksw8954/python-dev-env:{version}
```

## License

MIT

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
