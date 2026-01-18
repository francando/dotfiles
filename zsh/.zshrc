# --- 1. COMPLETION SYSTEM ---
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' # Case-insensitive
zstyle ':completion:*' menu select                 # Visual menu
setopt AUTO_CD                                     # Type dir name to 'cd'
export GIT_EDITOR=nvim

# --- 2. HISTORY ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt PROMPT_SUBST

# --- 3. PROMPT STYLING (Macchiato) ---
# Colors
CLR_BLUE="%F{blue}"
CLR_GREEN="%F{green}"
CLR_GIT="%F{red}"
CLR_HOST="%F{cyan}"
CLR_PURPLE="%F{magenta}"
CLR_RESET="%f"

# Git branch info
function git_info() {
  local branch=$(git branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    echo " ${CLR_GIT} $branch${CLR_RESET}"
  fi
}


# Prompt: [user] at [host] in [CWD] [git]
# %~ shows the CWD relative to home
PROMPT="${CLR_BLUE}%n${CLR_HOST}@%m ${CLR_GREEN}%B%~%b${CLR_RESET}"
PROMPT+='$(git_info)'
PROMPT+="${CLR_PURPLE} ❯ ${CLR_RESET}"

# --- 4. THEME ---
if [ -f ~/.zsh/catppuccin_macchiato-zsh-syntax-highlighting.zsh ]; then
  source ~/.zsh/catppuccin_macchiato-zsh-syntax-highlighting.zsh
fi

# --- 5. APT PLUGINS  ---
# Syntax Highlighting
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
# Autosuggestions
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null

# --- 6. Keybindings ---
bindkey '^H' backward-kill-word
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
