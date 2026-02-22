bindkey '\t' menu-complete
bindkey "${terminfo[kcbt]}" reverse-menu-complete
setopt MENU_COMPLETE

eval "$(zoxide init zsh)"
eval "$(mcfly init zsh)"

_server() { ~/scripts/connect_server; }
_kid() { ~/scripts/connect_kid; }
_my() { ~/scripts/connect_my; }
