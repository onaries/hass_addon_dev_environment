#!/bin/bash
# ZSH + Zinit Setup Script for hass-addon-dev-environment
# Usage: setup-zsh.sh [--force]
#   --force: 기존 .zshrc를 백업 후 재생성

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
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

    if [ -f "$theme_file" ] && [ "$FORCE" = false ]; then
        print_skip "Theme ($theme_file)"
        return
    fi

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
    print_info "Updating ~/.zshenv..."
    touch "$HOME/.zshenv"
    local added=0

    declare -a env_lines=(
        'export PATH="$HOME/bin:/usr/local/bin:$PATH"'
        'export PATH="$HOME/.local/bin:$PATH"'
        'export PATH="$HOME/.cargo/bin:$PATH"'
        'export XDG_CONFIG_HOME="$HOME/.config"'
        'export XDG_CACHE_HOME="$HOME/.cache"'
        'export XDG_DATA_HOME="$HOME/.local/share"'
        'export XDG_STATE_HOME="$HOME/.local/state"'
    )

    for line in "${env_lines[@]}"; do
        if ! grep -qF "$line" "$HOME/.zshenv" 2>/dev/null; then
            echo "$line" >> "$HOME/.zshenv"
            added=$((added + 1))
        fi
    done

    if ! grep -q 'EDITOR=' "$HOME/.zshenv" 2>/dev/null; then
        echo 'export EDITOR="nvim"' >> "$HOME/.zshenv"
        echo 'export VISUAL="nvim"' >> "$HOME/.zshenv"
        added=$((added + 2))
    fi

    [ $added -gt 0 ] && print_success "Added $added entries to ~/.zshenv" || print_skip "~/.zshenv"
}

# ============================================================================
# 4. Generate .zshrc
# ============================================================================
setup_zshrc() {
    if [ -f "$HOME/.zshrc" ] && grep -q "ZINIT_HOME" "$HOME/.zshrc" 2>/dev/null && [ "$FORCE" = false ]; then
        print_skip ".zshrc (zinit config already present)"
        return
    fi

    if [ -f "$HOME/.zshrc" ] && [ "$FORCE" = true ]; then
        local backup="$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.zshrc" "$backup"
        print_info "Backed up .zshrc to $backup"
    fi

    print_info "Generating ~/.zshrc..."

    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# ============================================================================
# ZSH Options
# ============================================================================
setopt AUTO_CD HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS SHARE_HISTORY EXTENDED_HISTORY nonomatch
HISTFILE=~/.zsh_history
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
ZSHRC_EOF

    # DOCKER_HOST (dynamic)
    if [ -n "${DOCKER_HOST:-}" ]; then
        echo "export DOCKER_HOST=\"$DOCKER_HOST\"" >> "$HOME/.zshrc"
    elif [ -S /var/run/docker.sock ]; then
        echo 'export DOCKER_HOST=unix:///var/run/docker.sock' >> "$HOME/.zshrc"
    fi

    print_success ".zshrc generated"
}

# ============================================================================
# 5. Persist to /data/ (addon persistent storage)
# ============================================================================
persist_config() {
    if [ -d "/data" ]; then
        print_info "Persisting shell configs to /data/..."
        cp "$HOME/.zshrc" /data/user_zshrc
        cp "$HOME/.bashrc" /data/user_bashrc 2>/dev/null || true
        ln -sf /data/user_zshrc "$HOME/.zshrc"
        ln -sf /data/user_bashrc "$HOME/.bashrc" 2>/dev/null || true
        print_success "Configs persisted and symlinked"
    else
        print_warn "/data/ not found — skipping persistence (not running in addon?)"
    fi
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
    persist_config

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Done! Run: source ~/.zshrc               ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
}

main "$@"
