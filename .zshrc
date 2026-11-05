# ╔══════════════════════════════════════════════════════════════════════════╗
# ║   ~/.zshrc  —  Arch Linux · Zinit · Powerlevel10k                      ║
# ║   Omarchy Quattro shell integration                                     ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── Powerlevel10k instant prompt (MUST be near top) ──────────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ════════════════════════════════════════════════════════════════════════════
# SECTION 1 — ENVIRONMENT & PATH
# ════════════════════════════════════════════════════════════════════════════

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export PAGER="less"
export LESS="-R --use-color"

# ── Quattro envs — sourced first so OMARCHY_PATH and Quattro tools are live ──
[[ -f /usr/share/omarchy/default/bash/envs ]] && \
  source /usr/share/omarchy/default/bash/envs

# Override EDITOR: prefer nvim directly in terminal
export EDITOR="nvim"
export VISUAL="nvim"
export SUDO_EDITOR="nvim"

# Android SDK (if installed)
if [[ -d "$HOME/Android/Sdk" ]]; then
  export ANDROID_HOME="$HOME/Android/Sdk"
fi

# ── PATH (dynamic: only adds directories that actually exist) ────────────────
typeset -U path
for _p in \
  "$HOME/.local/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/go/bin" \
  "$HOME/.npm-global/bin" \
  "$HOME/.composer/vendor/bin" \
  "$HOME/.bun/bin" \
  "$HOME/Android/Sdk/platform-tools" \
  "$HOME/Android/Sdk/emulator" \
  "$HOME/Android/Sdk/cmdline-tools/latest/bin" \
  "$HOME/.config/herd-lite/bin"; do
  [[ -d "$_p" ]] && path=("$_p" $path)
done
unset _p

# ════════════════════════════════════════════════════════════════════════════
# SECTION 2 — ZINIT PLUGIN MANAGER
# ════════════════════════════════════════════════════════════════════════════

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
  print -P "%F{cyan}[zinit] First run — cloning zinit...%f"
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "$ZINIT_HOME/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ════════════════════════════════════════════════════════════════════════════
# SECTION 3 — COMPLETIONS & PLUGINS
# ════════════════════════════════════════════════════════════════════════════

# Custom completions directory (MUST be added to fpath before compinit)
fpath=("$HOME/.zfunc" $fpath)

# ── Completion System ────────────────────────────────────────────────────────
autoload -Uz compinit
if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.mh+24) ]]; then
  compinit -d "${ZDOTDIR:-$HOME}/.zcompdump"
else
  compinit -C -d "${ZDOTDIR:-$HOME}/.zcompdump"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always "$realpath" 2>/dev/null'
zstyle ':fzf-tab:complete:*' fzf-preview \
  'file "$realpath" 2>/dev/null | grep -q text && bat --color=always --line-range :50 "$realpath" 2>/dev/null || echo "$realpath"'

# ── Theme ────────────────────────────────────────────────────────────────────
zinit ice depth=1; zinit light romkatv/powerlevel10k

# ── Completions & fuzzy tab ──────────────────────────────────────────────────
zinit light Aloxaf/fzf-tab
zinit ice wait lucid; zinit light zsh-users/zsh-completions

# ── Suggestions & Highlighting (highlighting MUST load after widgets) ────────
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting

# ════════════════════════════════════════════════════════════════════════════
# SECTION 4 — SHELL OPTIONS & HISTORY
# ════════════════════════════════════════════════════════════════════════════

setopt autocd
setopt interactivecomments
setopt extendedglob
setopt nomatch
setopt sharehistory
setopt histignorealldups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_verify
setopt auto_pushd
setopt pushd_ignore_dups
unsetopt beep

HISTSIZE=50000
SAVEHIST=100000
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"

# ════════════════════════════════════════════════════════════════════════════
# SECTION 5 — KEY BINDINGS & FZF
# ════════════════════════════════════════════════════════════════════════════

bindkey -v
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# History prefix search (type command prefix, press Up/Down)
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

autoload -U select-word-style
select-word-style bash

# ── FZF Key Bindings & Completion ────────────────────────────────────────────
_fzf_sourced=0
for _f in "$HOME/.fzf.zsh" /usr/share/fzf/key-bindings.zsh; do
  [[ -f "$_f" && $_fzf_sourced -eq 0 ]] && { source "$_f"; _fzf_sourced=1; }
done
unset _f _fzf_sourced
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

bindkey '^O' fzf-file-widget

# Esc Esc toggles sudo on the current line buffer
sudo-command-line() {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    LBUFFER="${LBUFFER#sudo }"
  else
    LBUFFER="sudo $LBUFFER"
  fi
}
zle -N sudo-command-line
bindkey '\e\e' sudo-command-line

# ════════════════════════════════════════════════════════════════════════════
# SECTION 6 — TOOLS (zoxide, vivid / dircolors, mise, fzf)
# ════════════════════════════════════════════════════════════════════════════

# zoxide — smarter cd
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# LS_COLORS — vivid with fallback to dircolors
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate one-dark)"
elif [[ -f /etc/DIR_COLORS ]]; then
  eval "$(dircolors -b /etc/DIR_COLORS 2>/dev/null)"
else
  eval "$(dircolors -b 2>/dev/null)"
fi

# FZF default options
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --exclude .git'
elif command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --no-messages'
fi

export FZF_DEFAULT_OPTS='
  --height=40% --layout=reverse --border
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
'

# mise — runtime manager
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# ════════════════════════════════════════════════════════════════════════════
# SECTION 7 — QUATTRO FUNCTIONS & WORKTREES
# ════════════════════════════════════════════════════════════════════════════

if [[ -d "$OMARCHY_PATH/default/bash/fns" ]]; then
  for _omarchy_fn in "$OMARCHY_PATH/default/bash/fns/"*; do
    [[ "$(basename "$_omarchy_fn")" == "worktrees" ]] && continue
    source "$_omarchy_fn"
  done
  unset _omarchy_fn

  # Worktrees: ga/gd renamed to gwa/gwd to protect git aliases
  if [[ -f "$OMARCHY_PATH/default/bash/fns/worktrees" ]]; then
    gwa() {
      if [[ -z "$1" ]]; then
        echo "Usage: gwa [branch name]"
        return 1
      fi
      local branch="$1"
      local base="$(basename "$PWD")"
      local wt_path="../${base}--${branch}"
      git worktree add -b "$branch" "$wt_path"
      command -v mise >/dev/null 2>&1 && mise trust "$wt_path"
      cd "$wt_path"
    }

    gwd() {
      if command -v gum >/dev/null 2>&1 && gum confirm "Remove worktree and branch?"; then
        local cwd base branch root worktree
        cwd="$(pwd)"
        worktree="$(basename "$cwd")"
        root="${worktree%%--*}"
        branch="${worktree#*--}"
        if [[ "$root" != "$worktree" ]]; then
          cd "../$root"
          git worktree remove "$cwd" --force || return 1
          git branch -D "$branch"
        fi
      fi
    }
  fi
fi

# Quattro try — lazy loader
if command -v try >/dev/null 2>&1; then
  try() {
    unset -f try
    eval "$(SHELL=/bin/bash command try init ~/Work/tries)"
    try "$@"
  }
fi

# ════════════════════════════════════════════════════════════════════════════
# SECTION 8 — ALIASES
# ════════════════════════════════════════════════════════════════════════════

# Source Omarchy's base aliases
[[ -f "$OMARCHY_PATH/default/bash/aliases" ]] && \
  source "$OMARCHY_PATH/default/bash/aliases"

# ── Navigation & Listing ─────────────────────────────────────────────────────
alias l='eza -la --group-directories-first --icons=auto'

# ── Editor ───────────────────────────────────────────────────────────────────
alias vim='nvim'
alias vi='nvim'

# ── Utilities ────────────────────────────────────────────────────────────────
alias fs='fastfetch'
alias cat='bat --style=auto'
alias grep='grep --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias cls='clear'

# Rerun last command with sudo
please() {
  local last_cmd
  last_cmd=$(fc -ln -1 | sed 's/^[[:space:]]*//')
  if [[ -n "$last_cmd" ]]; then
    echo "Running: sudo $last_cmd"
    eval "sudo $last_cmd"
  fi
}

# ── Git (Personal shortcuts) ─────────────────────────────────────────────────
alias gs='git status'
alias ga='git add'
alias gc='git commit -v'
alias gp='git push'
alias gl='git pull --ff-only'
alias gco='git checkout'
alias gd='git diff'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# ── Laravel / PHP ────────────────────────────────────────────────────────────
alias art='php artisan'

# ── Arch Linux ───────────────────────────────────────────────────────────────
if command -v pacman >/dev/null 2>&1; then
  alias update='yay -Syu'
  alias pacs='pacman -Ss'
  alias paci='sudo pacman -S'
  alias pacr='sudo pacman -Rns'
  alias pacl='pacman -Ql'
  alias pacown='pacman -Qo'

  orphans() {
    local pkgs
    pkgs=($(pacman -Qdtq 2>/dev/null))
    if (( ${#pkgs[@]} > 0 )); then
      echo "Orphaned packages: ${pkgs[*]}"
      sudo pacman -Rns "${pkgs[@]}"
    else
      echo "No orphaned packages found."
    fi
  }
fi

# ════════════════════════════════════════════════════════════════════════════
# SECTION 9 — FUZZY PACKAGE MANAGERS
# ════════════════════════════════════════════════════════════════════════════

finpac() {
  for dep in fzf yay pacman; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "⚠️  $dep is not installed."
      return 1
    fi
  done

  local _list
  _list=$(pacman -Slq 2>/dev/null | sort -u)
  [[ -z "$_list" ]] && { echo "⚠️  No packages found."; return 1; }

  local sel
  sel=$(printf '%s\n' "$_list" |
    fzf --multi --height=60% --reverse \
        --prompt='🔍 Search Arch packages > ' --border \
        --header='[Tab: multi-select | Enter: install]' \
        --preview='pacman -Si {} 2>/dev/null || yay -Si {} 2>/dev/null' \
        --preview-window=right,65%) || return 0

  [[ -z $sel ]] && return 0

  local -a pkgs=("${(f)sel}")
  echo -e "\n📦 Ready to install: ${pkgs[*]}"
  printf "✅ Proceed? [y/N]: "
  local ans; read -r ans
  [[ $ans =~ ^[Yy]$ ]] || { echo "❌ Cancelled."; return 0; }

  yay -S --needed "${pkgs[@]}" && {
    command -v notify-send >/dev/null 2>&1 && \
      notify-send "finpac" "🎉 Installation complete!" --icon=software-update-available
    echo "🎉 Installation complete!"
  }
}

remove_app() {
  for dep in fzf yay pacman; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "⚠️  $dep is not installed."
      return 1
    fi
  done

  local pkg
  pkg=$(pacman -Qq | fzf --height=50% --reverse --header="Select package to REMOVE" \
    --preview "pacman -Qi {1}" --preview-window=right:60%) || return 0

  if [[ -n "$pkg" ]]; then
    printf "Uninstall %s and unneeded dependencies? [y/N]: " "$pkg"
    local confirm; read -r confirm
    [[ $confirm =~ ^[Yy]$ ]] && yay -Rns "$pkg"
  fi
}

# ════════════════════════════════════════════════════════════════════════════
# SECTION 10 — LOCAL EXTRAS & POWERLEVEL10K
# ════════════════════════════════════════════════════════════════════════════

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
