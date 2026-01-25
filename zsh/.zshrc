# --- 1. COMPLETION SYSTEM ---
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' # Case-insensitive
zstyle ':completion:*' menu select                 # Visual menu
setopt AUTO_CD                                     # Type dir name to 'cd'

export GIT_EDITOR=nvim
export DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"
export TERM=xterm-256color
export LANG=en_US.UTF-8
export LANGUAGE=en_US
export LC_ALL=en_US.UTF-8


# add bins 
if [[ ":$PATH:" != *":$DOTFILES_ROOT/bin:"* ]]; then
    export PATH="$DOTFILES_ROOT/bin:$PATH"
fi

# --- 2. HISTORY ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt PROMPT_SUBST

# --- 3. PROMPT STYLING (Macchiato) ---
# Colors
CLR_BLUE="%F{blue}"
CLR_WHITE="%F{white}"
CLR_GREEN="%F{green}"
CLR_GIT="%F{red}"
CLR_HOST="%F{cyan}"
CLR_PURPLE="%F{magenta}"
CLR_RESET="%f"

# Git branch info
function git_info() {
  local branch=$(git branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    echo " ${CLR_GIT}%{\ue725%} $branch${CLR_RESET}"
  fi
}

function container_info() {
  # Strong signal: your dev workflow flag
  if [[ "${DEV_CONTAINER_ACTIVE:-0}" == "1" ]]; then
#    echo " ${CLR_PURPLE} ${CLR_RESET}"
    echo " ${CLR_PURPLE}%{\uf308%}%{${CLR_RESET}%}"
    return
  fi

  # Generic docker detection
  if [[ -f /.dockerenv ]] || grep -qE '(docker|containerd|kubepods)' /proc/1/cgroup 2>/dev/null; then
    #echo " ${CLR_PURPLE}[ctr]${CLR_RESET}"
    echo " ${CLR_PURPLE}%{\uf308%}%{${CLR_RESET}%}"
  fi
}

PROMPT="%{${CLR_BLUE}%}%n%{${CLR_WHITE}%}@%{${CLR_HOST}%}%m"
PROMPT+='$(container_info)'
PROMPT+=" %{${CLR_GREEN}%}%B%~%b%{${CLR_RESET}%}"
PROMPT+='$(git_info)'
PROMPT+="%{${CLR_PURPLE}%} ❯ %{${CLR_RESET}%}"

# --- 5. APT PLUGINS  ---
# Syntax Highlighting
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
# Autosuggestions
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null

# --- 6. Keybindings ---
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# # VI MODE
# bindkey -v
#
# # Change cursor shape based on mode
# function zle-keymap-select() {
#   if [[ ${KEYMAP} == vicmd ]]; then
#     echo -ne '\e[2 q' # Block for Normal Mode
#   else
#     echo -ne '\e[6 q' # Bar for Insert Mode
#   fi
# }
# zle -N zle-keymap-select
#
# # Ensure the bar cursor is set when starting the shell
# precmd() { echo -ne '\e[6 q' }
#
# # --- CLIPBOARD SYNC FOR VI MODE ---
# # Detect the clipboard tool (wl-copy for Wayland, xclip for X11)
# if command -v wl-copy &>/dev/null; then
#   CLIP_TOOL="wl-copy"
# elif command -v xclip &>/dev/null; then
#   CLIP_TOOL="xclip -selection clipboard"
# else
#   CLIP_TOOL=""
# fi
#
# # Function to yank Zsh buffer to system clipboard
# function vi-yank-system() {
#   zle vi-yank
#   if [ -n "$CLIP_TOOL" ]; then
#     echo -n "$CUTBUFFER" | eval "$CLIP_TOOL"
#   fi
# }
#
# # Register the widget and bind it to 'y' in command mode
# zle -N vi-yank-system
# bindkey -M vicmd 'y' vi-yank-system
# bindkey -M viins '^R' history-incremental-search-backward
# bindkey -M vicmd '^R' history-incremental-search-backward
