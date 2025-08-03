# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#
#            _
#    _______| |__  _ __ ___
#   |_  / __| '_ \| '__/ __|
#  _ / /\__ \ | | | | | (__
# (_)___|___/_| |_|_|  \___|
#
# -----------------------------------------------------

export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME=""
ZSH_THEME="powerlevel10k/powerlevel10k"
source $ZSH/oh-my-zsh.sh

# -----------------------------------------------------
# BEGIN PERSONAL CUSTOMISATIONS  🎨
# -----------------------------------------------------

#### ── Environment ──────────────────────────────────
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

path+=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" "$HOME/.npm-global/bin" "$HOME/.composer/vendor/bin" "$HOME/.bun/bin")

#### ── Homebrew (Linuxbrew) ─────────────────────────
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

#### ── Zoxide (smart cd) ────────────────────────────
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
#
#### ── Plugin Manager (Zinit) ───────────────────────
if [[ ! -f "$HOME/.zinit/bin/zinit.zsh" ]]; then
  mkdir -p "$HOME/.zinit" &&
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$HOME/.zinit/bin"
fi
source "$HOME/.zinit/bin/zinit.zsh"

zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light Aloxaf/fzf-tab
zinit light zdharma-continuum/fast-syntax-highlighting

#### ── Key-bindings & FZF widgets ───────────────────
bindkey -v
autoload -U select-word-style && zle -N fzf-file-widget
bindkey '^O' fzf-file-widget

#### ── Aliases ──────────────────────────────────────
alias ll='ls -lah --color=auto'
alias la='ls -A'
alias l='ls -CF'
alias please='sudo $(history -p !!)'
alias vim="nvim"

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit -v'
alias gp='git push'
alias gl='git pull --ff-only'
alias gco='git checkout'
alias art="php artisan"
alias fs="fastfetch --config examples/22.jsonc"

# Arch or Fedora
if [[ -x /usr/bin/pacman ]]; then
  alias update='sudo pacman -Syu && yay -Syu --noconfirm'
# elif [[ -x /usr/bin/dnf ]]; then
#   alias update='sudo dnf upgrade --refresh'
fi

#### ── History settings ─────────────────────────────
HISTSIZE=50000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt appendhistory
setopt histignorealldups
setopt sharehistory

#### ── FZF default command ──────────────────────────
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix'
elif command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --no-messages'
fi

#### ── LS_COLORS via vivid ──────────────────────────
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate one-dark)"
fi

#### ── Shell behavior ───────────────────────────────
setopt autocd
setopt correct
setopt interactivecomments
setopt extendedglob
setopt nomatch
unsetopt beep

# ────────────────────────────────────────────────
# LAMP helper functions (Apache + MariaDB)
# ────────────────────────────────────────────────
start_lamp() {
  echo "▶ Starting Apache (httpd) and MariaDB…"
  sudo systemctl start httpd  && echo "  ✅ Apache started"
  sudo systemctl start mariadb && echo "  ✅ MariaDB started"
  echo "  🌐 Browse  : http://localhost/   (site root)"
  echo "  🔐 phpMyAdmin: http://localhost/phpmyadmin/"
}

stop_lamp() {
  echo "⏹ Stopping Apache (httpd) and MariaDB…"
  sudo systemctl stop httpd   && echo "  🛑 Apache stopped"
  sudo systemctl stop mariadb && echo "  🛑 MariaDB stopped"
}
#--------------------------------------------------------------------------
# ~/.zshrc  – smart yt-dlp helper
#--------------------------------------------------------------------------
download() {
  # default settings
  local PLAYLIST=0 AUDIO=0 SUBS=0
  local OUT_DIR="$HOME/Downloads"
  local URL OPTS FORMAT

  # -------- argument parser ---------------------------------------------
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--playlist)      PLAYLIST=1 ;;
      -a|--audio)         AUDIO=1   ;;
      -s|--subs)          SUBS=1    ;;
      -d|--dir)           OUT_DIR="$2"; shift ;;
      -h|--help)
        cat <<EOF
Usage: ytdlp [options] <url>

Options:
  -p, --playlist        treat URL as playlist, keep files numbered from 0
  -a, --audio           audio-only (extract best track, convert to mp3)
  -s, --subs            download & embed subtitles (all languages)
  -d, --dir <folder>    custom download folder (default: $HOME/Downloads)
EOF
        return 0 ;;
      *) URL="$1" ;;
    esac
    shift
  done
  [[ -z $URL ]] && { echo "ytdlp: no URL given" >&2; return 1; }

  # -------- generic switches --------------------------------------------
  OPTS=(-P "$OUT_DIR"                        # custom target directory :contentReference[oaicite:0]{index=0}
        --embed-metadata --embed-thumbnail )

  # playlist vs single video +  zero-based numbering
  if (( PLAYLIST )); then
    OPTS+=(-o "%(playlist_title)s/%(playlist_index-1)03d - %(title)s.%(ext)s")  # arithmetic field ops :contentReference[oaicite:1]{index=1}
  else
    OPTS+=(--no-playlist -o "%(title)s.%(ext)s")
  fi

  # audio-only
  if (( AUDIO )); then
    FORMAT="bestaudio"
    OPTS+=(-x --audio-format mp3)            # extract+convert to MP3  :contentReference[oaicite:2]{index=2}
  else
    FORMAT="bestvideo[height<=1080]+bestaudio/best"
  fi
  OPTS+=(-f "$FORMAT")

  # subtitles
  (( SUBS )) && OPTS+=(--write-subs --sub-langs all --embed-subs)  # :contentReference[oaicite:3]{index=3}

  # fancy progress & desktop notification
  OPTS+=(--progress            # force progress even if quiet
        --progress-template "download:%(progress._percent_str)s of %(progress._total_bytes_str)s │ ETA %(progress.eta)s"  # :contentReference[oaicite:4]{index=4}
        --exec "after_move:notify-send '✅ yt-dlp' 'Finished: %(info.title)s'")   # :contentReference[oaicite:5]{index=5}

  # -------- run yt-dlp ---------------------------------------------------
  yt-dlp "${OPTS[@]}" "$URL"
}


#--------------------------------------------------------------------------
# ~/.zshrc  — fuzzy-brew installer
#--------------------------------------------------------------------------

fbrew() {
  command -v fzf >/dev/null 2>&1 || {
    echo "⚠️  fzf is not installed. brew install fzf first." >&2
    return 1
  }

  # Use 'brew formulae' and 'brew casks' commands for listing
  local _list
  _list=$(
    { brew formulae; brew casks | sed 's/^/cask:/' ; } 2>/dev/null | sort -u
  ) || {
    echo "⚠️  Failed to get brew packages list. Check your brew installation." >&2
    return 1
  }

  if [[ -z "$_list" ]]; then
    echo "⚠️  No packages found. Check brew installation."
    return 1
  fi

  local sel
  sel=$(printf '%s\n' "$_list" |
        fzf --multi --height=40% --reverse --prompt='fbrew> ' --border \
            --preview='
              [[ {} == cask:* ]] && brew info --cask ${${}:#cask:} ||
              brew info {}
            ' --preview-window=right,70%) || return

  [[ -z $sel ]] && return

  local -a formulas casks
  for line in ${(f)sel}; do
    if [[ $line == cask:* ]]; then
      casks+=("${line#cask:}")
    else
      formulas+=("$line")
    fi
  done

  (( ${#formulas[@]} )) && brew install "${formulas[@]}"
  (( ${#casks[@]}    )) && brew install --cask "${casks[@]}"
}

# -----------------------------------------------------
# END OF FILE
# -----------------------------------------------------

fpath+=~/.zfunc

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
