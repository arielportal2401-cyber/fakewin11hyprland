# WINDOWS11_RICE_SHELL_START
if [[ $- == *i* ]]; then
    command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
    command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -lah --icons=auto --group-directories-first --git'
    alias tree='eza --tree --icons=auto --group-directories-first'
    alias preview='chafa'
    alias top='btop'
    alias ff='fastfetch'
    alias pipes='pipes-rs'
fi
# WINDOWS11_RICE_SHELL_END
