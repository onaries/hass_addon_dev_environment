#!/bin/bash
# update-packages.sh - 실행 중인 컨테이너 내에서 패키지 및 도구 업데이트
# Usage: update-packages.sh [--all|--system|--bun|--python|--binary|--cli]
#   옵션 없이 실행하면 --all과 동일

set -o pipefail

log() {
    echo -e "\033[1;34m[UPDATE $(date '+%H:%M:%S')]\033[0m $1"
}

ok() {
    echo -e "\033[1;32m  ✓\033[0m $1"
}

warn() {
    echo -e "\033[1;33m  ⚠\033[0m $1"
}

fail() {
    echo -e "\033[1;31m  ✗\033[0m $1"
}

ARCH=$(dpkg --print-architecture)

# Detect dev user (non-root user with home directory)
if [ -n "$USERNAME" ]; then
    DEV_USER="$USERNAME"
elif [ -f /data/options.json ]; then
    DEV_USER=$(jq -r '.username // "developer"' /data/options.json)
else
    DEV_USER="developer"
fi

run_as_user() {
    sudo -H -u "$DEV_USER" bash -c "$1"
}

# GitHub latest release tag helper
gh_latest_tag() {
    local repo=$1
    curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name // empty'
}

##############################
# 1. System packages (apt)
##############################
update_system() {
    log "시스템 패키지 업데이트 중..."
    if apt-get update -qq && apt-get upgrade -y -qq; then
        apt-get autoremove -y -qq 2>/dev/null
        apt-get clean 2>/dev/null
        rm -rf /var/lib/apt/lists/*
        ok "시스템 패키지 업데이트 완료"
    else
        fail "시스템 패키지 업데이트 실패"
    fi
}

##############################
# 2. bun global packages
##############################
update_bun() {
    log "bun 글로벌 패키지 업데이트 중..."

    run_as_user '
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"

        echo "  Bun: $(bun --version)"

        for pkg in @openai/codex oh-my-codex openclaw @ksw8954/git-ai-commit pyright typescript typescript-language-server @qwen-code/qwen-code; do
            if [ -f "$BUN_INSTALL/install/global/node_modules/${pkg##*/}/package.json" ] || ls "$BUN_INSTALL/bin/${pkg##*/}" >/dev/null 2>&1; then
                if bun install -g "${pkg}@latest" 2>/dev/null; then
                    echo "  ✓ ${pkg} 업데이트 완료"
                else
                    echo "  ✗ ${pkg} 업데이트 실패"
                fi
            fi
        done

        if command -v omx >/dev/null 2>&1; then
            if omx setup --scope user --skill-target codex-home >/dev/null 2>&1; then
                echo "  ✓ OhMyCodex 설정 갱신 완료"
            else
                echo "  ⚠ OhMyCodex 설정 갱신 실패"
            fi
        fi
    ' || warn "bun 패키지 업데이트 중 일부 실패"

    ok "bun 글로벌 패키지 업데이트 완료"
}

##############################
# 3. Python tools (uv)
##############################
update_python() {
    log "Python 도구 업데이트 중..."

    # uv 자체 업데이트
    if run_as_user 'command -v uv >/dev/null 2>&1'; then
        if run_as_user 'curl -LsSf https://astral.sh/uv/install.sh | sh' 2>/dev/null; then
            ok "uv 업데이트 완료"
        else
            warn "uv 업데이트 실패"
        fi
    fi

    # uv tool 업데이트
    for tool in prek ruff mypy djlint basedpyright; do
        if run_as_user "command -v $tool" >/dev/null 2>&1; then
            if run_as_user "export PATH=\"\$HOME/.local/bin:\$PATH\" && uv tool upgrade $tool" 2>/dev/null; then
                ok "$tool 업데이트 완료"
            else
                warn "$tool 업데이트 실패"
            fi
        fi
    done

    # glances 업데이트
    if command -v glances >/dev/null 2>&1; then
        if pip3 install --break-system-packages --upgrade glances[all] 2>/dev/null || pip3 install --upgrade glances[all] 2>/dev/null; then
            ok "glances 업데이트 완료"
        else
            warn "glances 업데이트 실패"
        fi
    fi
}

##############################
# 4. Binary tools (GitHub releases)
##############################
update_binary_tool() {
    local name=$1 repo=$2 current_cmd=$3 install_fn=$4

    if ! command -v "$current_cmd" >/dev/null 2>&1; then
        return
    fi

    log "${name} 업데이트 중..."
    if eval "$install_fn"; then
        ok "${name} 업데이트 완료"
    else
        fail "${name} 업데이트 실패"
    fi
}

install_neovim() {
    if [ "$ARCH" = "amd64" ]; then
        curl -fsSL -o /tmp/nvim.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz &&
        rm -rf /opt/nvim-linux-x86_64 &&
        tar -C /opt -xzf /tmp/nvim.tar.gz &&
        ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim &&
        rm -f /tmp/nvim.tar.gz
    fi
}

install_ripgrep() {
    local ver arch
    if [ "$ARCH" = "amd64" ]; then arch="x86_64-unknown-linux-musl"
    elif [ "$ARCH" = "arm64" ]; then arch="aarch64-unknown-linux-gnu"
    else return 1; fi
    ver=$(gh_latest_tag BurntSushi/ripgrep)
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${ver}/ripgrep-${ver}-${arch}.tar.gz" | tar -xz -C /tmp &&
    mv "/tmp/ripgrep-${ver}-${arch}/rg" /usr/local/bin/ &&
    rm -rf "/tmp/ripgrep-${ver}-${arch}"
}

install_delta() {
    local ver arch
    if [ "$ARCH" = "amd64" ]; then arch="x86_64-unknown-linux-musl"
    elif [ "$ARCH" = "arm64" ]; then arch="aarch64-unknown-linux-gnu"
    else return 1; fi
    ver=$(gh_latest_tag dandavison/delta)
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${ver}/delta-${ver}-${arch}.tar.gz" | tar -xz -C /tmp &&
    mv "/tmp/delta-${ver}-${arch}/delta" /usr/local/bin/ &&
    rm -rf "/tmp/delta-${ver}-${arch}"
}

install_fzf() {
    local ver fzf_arch
    if [ "$ARCH" = "amd64" ]; then fzf_arch="linux_amd64"
    elif [ "$ARCH" = "arm64" ]; then fzf_arch="linux_arm64"
    else return 1; fi
    ver=$(gh_latest_tag junegunn/fzf | sed 's/^v//')
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${ver}/fzf-${ver}-${fzf_arch}.tar.gz" | tar -xz -C /usr/local/bin fzf
}

install_mcfly() {
    local ver arch
    if [ "$ARCH" = "amd64" ]; then arch="x86_64-unknown-linux-musl"
    elif [ "$ARCH" = "arm64" ]; then arch="aarch64-unknown-linux-musl"
    else return 1; fi
    ver=$(gh_latest_tag cantino/mcfly | sed 's/^v//')
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/cantino/mcfly/releases/download/v${ver}/mcfly-v${ver}-${arch}.tar.gz" | tar -xz -C /tmp &&
    mv /tmp/mcfly /usr/local/bin/
}

install_lsd() {
    local ver arch
    if [ "$ARCH" = "amd64" ]; then arch="x86_64-unknown-linux-musl"
    elif [ "$ARCH" = "arm64" ]; then arch="aarch64-unknown-linux-musl"
    else return 1; fi
    ver=$(gh_latest_tag lsd-rs/lsd | sed 's/^v//')
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/lsd-rs/lsd/releases/download/v${ver}/lsd-v${ver}-${arch}.tar.gz" | tar -xz -C /tmp &&
    mv "/tmp/lsd-v${ver}-${arch}/lsd" /usr/local/bin/ &&
    rm -rf "/tmp/lsd-v${ver}-${arch}"
}

install_duf() {
    local ver duf_arch
    if [ "$ARCH" = "amd64" ]; then duf_arch="linux_x86_64"
    elif [ "$ARCH" = "arm64" ]; then duf_arch="linux_arm64"
    else return 1; fi
    ver=$(gh_latest_tag muesli/duf | sed 's/^v//')
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/muesli/duf/releases/download/v${ver}/duf_${ver}_${duf_arch}.tar.gz" | tar -xz -C /tmp &&
    mv /tmp/duf /usr/local/bin/
}

install_gitui() {
    local ver gitui_arch
    if [ "$ARCH" = "amd64" ]; then gitui_arch="x86_64"
    elif [ "$ARCH" = "arm64" ]; then gitui_arch="aarch64"
    else return 1; fi
    ver=$(gh_latest_tag gitui-org/gitui)
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/gitui-org/gitui/releases/download/${ver}/gitui-linux-${gitui_arch}.tar.gz" -o /tmp/gitui.tar.gz &&
    tar -xzf /tmp/gitui.tar.gz -C /tmp && mv /tmp/gitui /usr/local/bin/ && chmod +x /usr/local/bin/gitui &&
    rm -f /tmp/gitui.tar.gz
}

install_just() {
    local ver just_arch
    if [ "$ARCH" = "amd64" ]; then just_arch="x86_64-unknown-linux-musl"
    elif [ "$ARCH" = "arm64" ]; then just_arch="aarch64-unknown-linux-musl"
    else return 1; fi
    ver=$(gh_latest_tag casey/just)
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/casey/just/releases/download/${ver}/just-${ver}-${just_arch}.tar.gz" | tar -xz -C /usr/local/bin just &&
    chmod +x /usr/local/bin/just
}

install_dolt() {
    local dolt_arch
    if [ "$ARCH" = "amd64" ]; then dolt_arch="amd64"
    elif [ "$ARCH" = "arm64" ]; then dolt_arch="arm64"
    else return 1; fi
    curl -fsSL "https://github.com/dolthub/dolt/releases/latest/download/dolt-linux-${dolt_arch}.tar.gz" -o /tmp/dolt.tar.gz &&
    tar -xzf /tmp/dolt.tar.gz -C /tmp &&
    mv "/tmp/dolt-linux-${dolt_arch}/bin/dolt" /usr/local/bin/ &&
    chmod +x /usr/local/bin/dolt &&
    rm -rf "/tmp/dolt-linux-${dolt_arch}" /tmp/dolt.tar.gz
}

install_beads() {
    local ver bd_arch
    if [ "$ARCH" = "amd64" ]; then bd_arch="amd64"
    elif [ "$ARCH" = "arm64" ]; then bd_arch="arm64"
    else return 1; fi
    ver=$(gh_latest_tag steveyegge/beads | sed 's/^v//')
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/steveyegge/beads/releases/download/v${ver}/beads_${ver}_linux_${bd_arch}.tar.gz" -o /tmp/beads.tar.gz &&
    tar -xzf /tmp/beads.tar.gz -C /usr/local/bin bd 2>/dev/null || (tar -xzf /tmp/beads.tar.gz -C /tmp && mv /tmp/bd /usr/local/bin/) &&
    chmod +x /usr/local/bin/bd &&
    rm -f /tmp/beads.tar.gz
}

install_zellij() {
    if [ "$ARCH" != "amd64" ]; then return 0; fi
    local ver
    ver=$(gh_latest_tag zellij-org/zellij | sed 's/^v//')
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ver}/zellij-x86_64-unknown-linux-musl.tar.gz" | tar -xz -C /tmp &&
    mv /tmp/zellij /usr/local/bin/
}

install_syncthing() {
    local ver st_arch
    if [ "$ARCH" = "amd64" ]; then st_arch="linux-amd64"
    elif [ "$ARCH" = "arm64" ]; then st_arch="linux-arm64"
    else return 1; fi
    ver=$(gh_latest_tag syncthing/syncthing)
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/syncthing/syncthing/releases/download/${ver}/syncthing-${st_arch}-${ver}.tar.gz" | tar -xz -C /tmp &&
    mv "/tmp/syncthing-${st_arch}-${ver}/syncthing" /usr/local/bin/ &&
    rm -rf "/tmp/syncthing-${st_arch}-${ver}"
}

install_yazi() {
    local ver yazi_arch
    if [ "$ARCH" = "amd64" ]; then yazi_arch="x86_64-unknown-linux-musl"
    elif [ "$ARCH" = "arm64" ]; then yazi_arch="aarch64-unknown-linux-musl"
    else return 1; fi
    ver=$(gh_latest_tag sxyazi/yazi)
    [ -z "$ver" ] && return 1
    curl -fsSL "https://github.com/sxyazi/yazi/releases/download/${ver}/yazi-${yazi_arch}.zip" -o /tmp/yazi.zip &&
    unzip -o /tmp/yazi.zip -d /tmp/yazi &&
    mv "/tmp/yazi/yazi-${yazi_arch}/yazi" /usr/local/bin/ &&
    mv "/tmp/yazi/yazi-${yazi_arch}/ya" /usr/local/bin/ &&
    chmod +x /usr/local/bin/yazi /usr/local/bin/ya &&
    rm -rf /tmp/yazi /tmp/yazi.zip
}

install_act() {
    curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | BINDIR=/usr/local/bin bash
}

install_himalaya() {
    curl -fsSL https://github.com/pimalaya/himalaya/releases/latest/download/himalaya.x86_64-linux.tgz | tar xz -C /usr/local/bin himalaya &&
    chmod +x /usr/local/bin/himalaya
}

install_gws() {
    curl -fsSL https://github.com/googleworkspace/cli/releases/latest/download/gws-x86_64-unknown-linux-gnu.tar.gz | tar xz -C /usr/local/bin gws &&
    chmod +x /usr/local/bin/gws
}

update_binaries() {
    update_binary_tool "Neovim"     "neovim/neovim"         "nvim"       install_neovim
    update_binary_tool "ripgrep"    "BurntSushi/ripgrep"    "rg"         install_ripgrep
    update_binary_tool "delta"      "dandavison/delta"      "delta"      install_delta
    update_binary_tool "fzf"        "junegunn/fzf"          "fzf"        install_fzf
    update_binary_tool "mcfly"      "cantino/mcfly"         "mcfly"      install_mcfly
    update_binary_tool "lsd"        "lsd-rs/lsd"            "lsd"        install_lsd
    update_binary_tool "duf"        "muesli/duf"            "duf"        install_duf
    update_binary_tool "GitUI"      "gitui-org/gitui"       "gitui"      install_gitui
    update_binary_tool "Just"       "casey/just"            "just"       install_just
    update_binary_tool "Dolt"       "dolthub/dolt"          "dolt"       install_dolt
    update_binary_tool "Beads"      "steveyegge/beads"      "bd"         install_beads
    update_binary_tool "Zellij"     "zellij-org/zellij"     "zellij"     install_zellij
    update_binary_tool "Syncthing"  "syncthing/syncthing"   "syncthing"  install_syncthing
    update_binary_tool "Yazi"       "sxyazi/yazi"           "yazi"       install_yazi
    update_binary_tool "act"        "nektos/act"            "act"        install_act
    update_binary_tool "himalaya"   "pimalaya/himalaya"     "himalaya"   install_himalaya
    update_binary_tool "gws"        "googleworkspace/cli"   "gws"        install_gws
}

##############################
# 5. CLI tools (curl installers)
##############################
update_cli() {
    log "CLI 도구 업데이트 중..."

    # Claude CLI
    if run_as_user 'command -v claude' >/dev/null 2>&1; then
        if run_as_user 'curl -fsSL https://claude.ai/install.sh | bash' 2>/dev/null; then
            ok "Claude CLI 업데이트 완료"
        else
            warn "Claude CLI 업데이트 실패"
        fi
    fi

    # Bun
    if run_as_user 'command -v bun' >/dev/null 2>&1; then
        if run_as_user 'curl -fsSL https://bun.sh/install | bash' 2>/dev/null; then
            ok "Bun 업데이트 완료"
        else
            warn "Bun 업데이트 실패"
        fi
    fi

    # OpenCode
    if run_as_user 'command -v opencode' >/dev/null 2>&1; then
        if run_as_user 'curl -fsSL https://opencode.ai/install | bash' 2>/dev/null; then
            ok "OpenCode 업데이트 완료"
        else
            warn "OpenCode 업데이트 실패"
        fi
    fi

    # Fresh editor
    if run_as_user 'command -v fresh' >/dev/null 2>&1; then
        if run_as_user 'curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh' 2>/dev/null; then
            ok "Fresh 업데이트 완료"
        else
            warn "Fresh 업데이트 실패"
        fi
    fi

    # OpenChamber
    if run_as_user 'command -v openchamber' >/dev/null 2>&1; then
        if run_as_user 'source /opt/nvm/nvm.sh && curl -fsSL https://raw.githubusercontent.com/btriapitsyn/openchamber/main/scripts/install.sh | bash' 2>/dev/null; then
            ok "OpenChamber 업데이트 완료"
        else
            warn "OpenChamber 업데이트 실패"
        fi
    fi

    # zoxide
    if run_as_user 'command -v zoxide' >/dev/null 2>&1; then
        if run_as_user 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh' 2>/dev/null; then
            ok "zoxide 업데이트 완료"
        else
            warn "zoxide 업데이트 실패"
        fi
    fi

    # CLIProxyAPI
    if [ -d "/home/$DEV_USER/cliproxyapi" ]; then
        if run_as_user 'curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash' 2>/dev/null; then
            ok "CLIProxyAPI 업데이트 완료"
        else
            warn "CLIProxyAPI 업데이트 실패"
        fi
    fi
}

##############################
# Main
##############################
main() {
    local target="${1:---all}"

    echo ""
    echo "============================================"
    echo "  패키지 업데이트 스크립트"
    echo "  대상: ${target}"
    echo "  아키텍처: ${ARCH}"
    echo "  사용자: ${DEV_USER}"
    echo "============================================"
    echo ""

    case "$target" in
        --all)
            update_system
            update_bun
            update_python
            update_binaries
            update_cli
            ;;
        --system)  update_system ;;
        --bun)     update_bun ;;
        --python)  update_python ;;
        --binary)  update_binaries ;;
        --cli)     update_cli ;;
        --help|-h)
            echo "Usage: update-packages.sh [OPTION]"
            echo ""
            echo "Options:"
            echo "  --all      모든 패키지 업데이트 (기본값)"
            echo "  --system   시스템 패키지 (apt) 업데이트"
            echo "  --bun      bun 글로벌 패키지 업데이트"
            echo "  --python   Python 도구 (uv, ruff 등) 업데이트"
            echo "  --binary   바이너리 도구 (GitHub releases) 업데이트"
            echo "  --cli      CLI 도구 (Claude, Bun 등) 업데이트"
            echo "  --help     이 도움말 표시"
            return 0
            ;;
        *)
            fail "알 수 없는 옵션: $target"
            echo "  --help 옵션으로 사용법을 확인하세요."
            return 1
            ;;
    esac

    echo ""
    log "업데이트 완료!"
}

main "$@"
