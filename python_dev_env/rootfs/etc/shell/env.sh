unset NPM_CONFIG_PREFIX
export NVM_DIR="/opt/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export PATH="/data/npm_global/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export RUSTUP_HOME="/data/rust_cargo/rustup"
export CARGO_HOME="/data/rust_cargo/cargo"
export PATH="/data/rust_cargo/cargo/bin:$PATH"

export PATH="/usr/local/go/bin:$PATH"
export GOPATH="/data/go_workspace"
export PATH="/data/go_workspace/bin:$PATH"

export GIT_TERMINAL_PROMPT=0

# Restore Claude Code symlinks if broken by self-update
if [ -d "/data/claude_config" ]; then
    if [ ! -L "$HOME/.claude" ]; then
        if [ -d "$HOME/.claude" ]; then
            # Merge new binary without overwriting existing auth/settings
            cp -rn "$HOME/.claude/." /data/claude_config/ 2>/dev/null || true
            # Always update the binary itself
            [ -d "$HOME/.claude/local" ] && cp -rf "$HOME/.claude/local" /data/claude_config/ 2>/dev/null || true
            rm -rf "$HOME/.claude"
        fi
        ln -sf /data/claude_config "$HOME/.claude"
    fi
    if [ ! -L "$HOME/.claude.json" ]; then
        # Only move if persistent version doesn't already exist
        if [ -f "$HOME/.claude.json" ] && [ ! -f "/data/claude_config/.claude.json" ]; then
            mv "$HOME/.claude.json" /data/claude_config/ 2>/dev/null
        else
            rm -f "$HOME/.claude.json" 2>/dev/null
        fi
        ln -sf /data/claude_config/.claude.json "$HOME/.claude.json"
    fi
fi
