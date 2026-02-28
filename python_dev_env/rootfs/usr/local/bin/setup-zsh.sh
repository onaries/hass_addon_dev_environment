#!/bin/bash
# ZSH + Zinit Setup Script for hass-addon-dev-environment
# 매 컨테이너 시작 시 실행되어 항상 최신 설정을 적용합니다.
# Usage: setup-zsh.sh [--force]
#   --force: zinit도 재설치

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_skip() { echo -e "${YELLOW}[SKIP]${NC} $1 (already exists)"; }

FORCE=false
[ "${1:-}" = "--force" ] && FORCE=true

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

# ============================================================================
# 1. Install Zinit
# ============================================================================
install_zinit() {
    if [ -d "$ZINIT_HOME" ] && [ "$FORCE" = false ]; then
        print_skip "Zinit ($ZINIT_HOME)"
    else
        print_info "Installing Zinit..."
        mkdir -p "$(dirname "$ZINIT_HOME")"
        chmod g-rwX "$(dirname "$ZINIT_HOME")"
        rm -rf "$ZINIT_HOME"
        git clone --quiet https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"
        print_success "Zinit installed"
    fi
}

# ============================================================================
# 2. Setup theme
# ============================================================================
setup_theme() {
    local theme_file="$HOME/.zsh-themes/td.zsh-theme"

    print_info "Creating zsh theme..."
    mkdir -p "$HOME/.zsh-themes"

    cat > "$theme_file" << 'THEME_EOF'
autoload -Uz colors && colors
autoload -Uz vcs_info
setopt complete_aliases PROMPT_SUBST

zstyle ':vcs_info:git:*' formats ' %F{magenta} %b%f'
precmd() { vcs_info }

exit_status="%(?..%F{red}✘ %?%f)"

if [ -f /etc/os-release ]; then
    distro_id=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    case "$distro_id" in
        kali) DISTRO_ICON="" ;; arch*) DISTRO_ICON="" ;; ubuntu) DISTRO_ICON="" ;;
        debian) DISTRO_ICON="" ;; fedora) DISTRO_ICON="" ;; alpine) DISTRO_ICON="" ;;
        *) DISTRO_ICON="󰀲" ;;
    esac
else
    DISTRO_ICON="󰀲"
fi

user_host="%F{blue}[%F{cyan}$(whoami)%F{yellow} $DISTRO_ICON %F{cyan}%m%F{blue}]%f"
dir_display="%F{blue}[%F{yellow}%~%F{blue}]%f"

PROMPT='
%B%F{green}╭─ ${user_host} ${dir_display}${vcs_info_msg_0_}
%B%F{green}╰─%F{green}❯%F{reset} '
RPROMPT="$exit_status"
THEME_EOF
    print_success "Theme created"
}

# ============================================================================
# 3. Setup .zshenv
# ============================================================================
setup_zshenv() {
    print_info "Generating ~/.zshenv..."

    cat > "$HOME/.zshenv" << 'ZSHENV_EOF'
export PATH="$HOME/bin:/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export EDITOR="nvim"
export VISUAL="nvim"
ZSHENV_EOF

    print_success ".zshenv generated"
}

# ============================================================================
# 4. Generate .zshrc (always regenerated)
# ============================================================================
setup_zshrc() {
    print_info "Generating ~/.zshrc..."

    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# ============================================================================
# ZSH Options
# ============================================================================
setopt AUTO_CD HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS SHARE_HISTORY EXTENDED_HISTORY nonomatch
HISTFILE=/data/zsh_history
HISTSIZE=10000
SAVEHIST=10000

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line
bindkey "^Z" undo
bindkey "^Y" redo
bindkey " " magic-space

# ============================================================================
# Zinit Plugin Manager
# ============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ ! -f $ZINIT_HOME/zinit.zsh ]]; then
    print -P "%F{33}Installing Zinit...%f"
    command mkdir -p "$(dirname $ZINIT_HOME)" && command chmod g-rwX "$(dirname $ZINIT_HOME)"
    command git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Theme
source ~/.zsh-themes/td.zsh-theme 2>/dev/null || true

# Plugins
zinit ice blockf
zinit light zsh-users/zsh-completions

zinit ice atload"_zsh_autosuggest_start" atinit"ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=50; bindkey \"^_\" autosuggest-execute; bindkey \"^ \" autosuggest-accept"
zinit light zsh-users/zsh-autosuggestions

zinit light zdharma-continuum/fast-syntax-highlighting
zinit light joshskidmore/zsh-fzf-history-search

zinit ice atload"bindkey \"^I\" menu-select; bindkey -M menuselect \"\$terminfo[kcbt]\" reverse-menu-complete; bindkey \"^[[A\" history-beginning-search-backward; bindkey \"^[[B\" history-beginning-search-forward; bindkey \"^[OA\" history-beginning-search-backward; bindkey \"^[OB\" history-beginning-search-forward"
zinit light marlonrichert/zsh-autocomplete

zinit for is-snippet OMZL::{compfix,completion,git,key-bindings}.zsh PZT::modules/{history}
zinit as"completion" for OMZP::{pip/_pip,terraform/_terraform}

# Completion
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
zstyle ":completion:*" matcher-list "m:{a-zA-Z}={A-Za-z}"
zstyle ":completion:*" menu select
zstyle ":completion:*" list-colors ${(s.:.)LS_COLORS}

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

# Aliases
[[ -f ~/.aliases ]] && source ~/.aliases

# ============================================================================
# Addon environment
# ============================================================================
source /etc/shell/env.sh 2>/dev/null || true
source /etc/shell/aliases.sh 2>/dev/null || true
source /etc/shell/zsh-extra.sh 2>/dev/null || true

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias gac="git-ai-commit"
compdef gac=git-ai-commit 2>/dev/null
ZSHRC_EOF

    # DOCKER_HOST (dynamic)
    if [ -n "${DOCKER_HOST:-}" ]; then
        echo "export DOCKER_HOST=\"$DOCKER_HOST\"" >> "$HOME/.zshrc"
    elif [ -S /var/run/docker.sock ]; then
        echo 'export DOCKER_HOST=unix:///var/run/docker.sock' >> "$HOME/.zshrc"
    fi

    mkdir -p "$HOME/.zsh/completions"

    # Source NVM and user paths so we can find user-installed tools
    export NVM_DIR="/opt/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null
    export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:/data/rust_cargo/cargo/bin:/usr/local/go/bin:$PATH"

    command -v git-ai-commit >/dev/null 2>&1 && git-ai-commit completion zsh > "$HOME/.zsh/completions/_git-ai-commit" 2>/dev/null || true
    command -v openclaw >/dev/null 2>&1 && openclaw completion -s zsh > "$HOME/.zsh/completions/_openclaw" 2>/dev/null || true
    command -v opencode >/dev/null 2>&1 && opencode completion zsh > "$HOME/.zsh/completions/_opencode" 2>/dev/null || true
    command -v gh >/dev/null 2>&1 && gh completion -s zsh > "$HOME/.zsh/completions/_gh" 2>/dev/null || true
    command -v just >/dev/null 2>&1 && just --completions zsh > "$HOME/.zsh/completions/_just" 2>/dev/null || true
    command -v docker >/dev/null 2>&1 && docker completion zsh > "$HOME/.zsh/completions/_docker" 2>/dev/null || true
    command -v rustup >/dev/null 2>&1 && rustup completions zsh > "$HOME/.zsh/completions/_rustup" 2>/dev/null || true
    command -v uv >/dev/null 2>&1 && uv generate-shell-completion zsh > "$HOME/.zsh/completions/_uv" 2>/dev/null || true
    command -v zellij >/dev/null 2>&1 && zellij setup --generate-completion zsh > "$HOME/.zsh/completions/_zellij" 2>/dev/null || true
    command -v delta >/dev/null 2>&1 && delta --generate-completion zsh > "$HOME/.zsh/completions/_delta" 2>/dev/null || true
    command -v bun >/dev/null 2>&1 && bun completions zsh > "$HOME/.zsh/completions/_bun" 2>/dev/null || true
    command -v codex >/dev/null 2>&1 && codex completion zsh > "$HOME/.zsh/completions/_codex" 2>/dev/null || true
    command -v rg >/dev/null 2>&1 && rg --generate complete-zsh > "$HOME/.zsh/completions/_rg" 2>/dev/null || true

    print_success ".zshrc generated"
}

# ============================================================================
# 5. Generate .bashrc (always regenerated)
# ============================================================================
setup_bashrc() {
    print_info "Generating ~/.bashrc..."

    cat > "$HOME/.bashrc" << 'BASHRC_EOF'
source /etc/shell/env.sh 2>/dev/null || true
source /etc/shell/aliases.sh 2>/dev/null || true

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias gac="git-ai-commit"
BASHRC_EOF

    # DOCKER_HOST (dynamic)
    if [ -n "${DOCKER_HOST:-}" ]; then
        echo "export DOCKER_HOST=\"$DOCKER_HOST\"" >> "$HOME/.bashrc"
    elif [ -S /var/run/docker.sock ]; then
        echo 'export DOCKER_HOST=unix:///var/run/docker.sock' >> "$HOME/.bashrc"
    fi

    print_success ".bashrc generated"
}

# ============================================================================
# Main
# ============================================================================
main() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  ZSH + Zinit Setup (hass-addon-dev-env)   ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""

    install_zinit
    setup_theme
    setup_zshenv
    setup_zshrc
    setup_bashrc

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Done! Run: source ~/.zshrc               ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
}

main "$@"
