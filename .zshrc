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
alias ll='lsd -lah --color=auto'
alias la='lsd -A'
alias l='lsd -a'
alias ls='lsd'
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
  
  sudo systemctl enable --now httpd.service
  if systemctl is-active --quiet httpd; then
    echo "  ✅ Apache started"
  else
    echo "  ❌ Failed to start Apache"
  fi

  sudo systemctl enable --now mariadb.service
  if systemctl is-active --quiet mariadb; then
    echo "  ✅ MariaDB started"
  else
    echo "  ❌ Failed to start MariaDB"
  fi

  echo "  🌐 Browse  : http://localhost/   (site root)"
  echo "  🔐 phpMyAdmin: http://localhost/phpmyadmin/"
}

stop_lamp() {
  echo "⏹ Stopping Apache (httpd) and MariaDB…"

  sudo systemctl stop httpd.service
  sudo systemctl disable httpd.service
  echo "  🛑 Apache stopped"

  sudo systemctl stop mariadb.service
  sudo systemctl disable mariadb.service
  echo "  🛑 MariaDB stopped"
}

status_lamp() {
  echo "🔍 LAMP Status:"

  if systemctl is-active --quiet httpd; then
    echo "  ✅ Apache (httpd) is running"
  else
    echo "  ❌ Apache (httpd) is not running"
  fi

  if systemctl is-active --quiet mariadb; then
    echo "  ✅ MariaDB is running"
  else
    echo "  ❌ MariaDB is not running"
  fi
}

#--------------------------------------------------------------------------
# ~/.zshrc  – smart yt-dlp helper
#--------------------------------------------------------------------------

download() {
  # ── Default settings ─────────────────────────────
  local PLAYLIST=0 AUDIO=0 SUBS=0
  local OUT_DIR="$HOME/Videos/"
  local URL="" OPTS=() FORMAT=""

  # ── Dependency check ─────────────────────────────
  if ! command -v yt-dlp >/dev/null 2>&1; then
    echo -e "⚠️  \033[1;31myt-dlp is not installed\033[0m"
    return 1
  fi
  if ! command -v notify-send >/dev/null 2>&1; then
    echo -e "ℹ️  \033[1;33mnotify-send not found\033[0m — notifications disabled"
  fi

  # ── Argument parser ──────────────────────────────
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--playlist) PLAYLIST=1 ;;
      -a|--audio)    AUDIO=1 ;;
      -s|--subs)     SUBS=1 ;;
      -d|--dir)
        [[ -n $2 ]] || { echo "❌ Missing folder after $1"; return 1; }
        OUT_DIR="$2"; shift ;;
      -h|--help)
        cat <<EOF
Usage: download [options] <url>

Options:
  -p  --playlist   Download full playlist
  -a  --audio      Audio-only (MP3)
  -s  --subs       Download + embed all subtitles
  -d  --dir <dir>  Save to custom directory
EOF
        return 0 ;;
      -*)
        echo "❌ Unknown option: $1" >&2
        return 1 ;;
      *)
        URL="$1" ;;
    esac
    shift
  done

  [[ -z $URL ]] && { echo "❌ No URL provided"; return 1; }

  # ── Output + Metadata ─────────────────────────────
  OPTS+=(-P "$OUT_DIR" --embed-metadata --embed-thumbnail --ignore-errors)

  if (( PLAYLIST )); then
    OPTS+=(-o "%(playlist_title)s/%(playlist_index)03d - %(title)s.%(ext)s")
  else
    OPTS+=(--no-playlist -o "%(title)s.%(ext)s")
  fi

  # ── Format selection ──────────────────────────────
  if (( AUDIO )); then
    FORMAT="bestaudio"
    OPTS+=(-x --audio-format mp3)
  else
    # fallback format for HTTP 403 errors
    FORMAT="bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
  fi
  OPTS+=(-f "$FORMAT")

  # ── Subtitles ─────────────────────────────────────
  (( SUBS )) && OPTS+=(--write-subs --sub-langs all --embed-subs)

  # ── Fancy progress ───────────────────────────────
  local BORDER="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  OPTS+=(
    --progress
    --progress-template "
\033[1;36m$BORDER\033[0m
📥  \033[1;37mDownloading:\033[0m %(title)s
💾  \033[1;37mSize:\033[0m %(progress._total_bytes_str)s
📊  \033[1;37mProgress:\033[0m %(progress._percent_str)s │ ETA %(progress._eta_str)s
\033[1;36m$BORDER\033[0m
"
  )

  # ── Desktop notification after download ──────────
  if command -v notify-send >/dev/null 2>&1; then
    OPTS+=(--exec "notify-send '✅ Download Complete' '🎬 %(title)s' --icon=video-x-generic")
  fi

  # ── Run yt-dlp for multiple URLs ─────────────────
  if [[ $URL == *" "* ]]; then
    # multiple URLs passed as space-separated
    for u in $URL; do
      yt-dlp "${OPTS[@]}" "$u" 2> >(grep -v "HTTP Error 403")
    done
  else
    yt-dlp "${OPTS[@]}" "$URL" 2> >(grep -v "HTTP Error 403")
  fi
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


#--------------------------------------------------------------------------
# ~/.zshrc  — fuzzy-yay installer
#--------------------------------------------------------------------------

finpac() {
  # Check dependencies
  for dep in fzf yay pacman; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo -e "⚠️  \033[1;31m$dep is not installed\033[0m. Install it first."
      case "$dep" in
        fzf)    echo "    sudo pacman -S fzf" ;;
        yay)    echo "    sudo pacman -S yay" ;;
        pacman) echo "    You're missing pacman? Are you even on Arch? 🤨" ;;
      esac
      return 1
    fi
  done

  # Fetch package lists
  local _list
  _list=$(
    {
      pacman -Slq 2>/dev/null | sort -u | sed 's/^/pacman:/'
      yay -Slq 2>/dev/null     | sort -u | sed 's/^/aur:/'
    } | sort -u
  )

  if [[ -z "$_list" ]]; then
    echo -e "⚠️  \033[1;33mNo packages found.\033[0m"
    return 1
  fi

  # ASCII preview header
  local ascii_border="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Let user select
  local sel
  sel=$(printf '%s\n' "$_list" |
    fzf --multi --height=40% --reverse \
        --prompt='🔍 Search packages > ' --border --ansi \
        --preview="
          pkg_type=\$(echo {} | cut -d: -f1)
          pkg_name=\$(echo {} | cut -d: -f2-)

          echo -e '\033[1;36m$ascii_border\033[0m'
          echo -e '📦 \033[1;37mPackage:\033[0m' \$pkg_name
          echo -e '📂 \033[1;37mSource:\033[0m' \$pkg_type
          echo -e '\033[1;36m$ascii_border\033[0m'

          if [[ \$pkg_type == pacman ]]; then
            pacman -Si \$pkg_name
          else
            yay -Si \$pkg_name
          fi

          echo -e '\033[1;36m$ascii_border\033[0m'
        " \
        --preview-window=right,70%) || return

  [[ -z $sel ]] && return

  # Separate into repo & AUR
  local -a pacman_pkgs aur_pkgs
  while IFS= read -r line; do
    if [[ $line == pacman:* ]]; then
      pacman_pkgs+=("${line#pacman:}")
    else
      aur_pkgs+=("${line#aur:}")
    fi
  done <<< "$sel"

  # Final confirmation with ASCII UI
  echo -e "\n\033[1;32m════════════════════════════════════════════════════════════════════════════\033[0m"
  echo -e "📦  \033[1;37mReady to install:\033[0m"
  [[ ${#pacman_pkgs[@]} -gt 0 ]] && echo -e "   🏛  From Repo:  \033[1;36m${pacman_pkgs[*]}\033[0m"
  [[ ${#aur_pkgs[@]}    -gt 0 ]] && echo -e "   🚀  From AUR :  \033[1;35m${aur_pkgs[*]}\033[0m"
  echo -e "\033[1;32m════════════════════════════════════════════════════════════════════════════\033[0m"
  
  
  printf "✅ Proceed with installation? [y/N]: "
  read ans
  [[ $ans =~ ^[Yy]$ ]] || { echo "❌ Installation cancelled."; return; }

  # Install
  (( ${#pacman_pkgs[@]} )) && sudo pacman -S --needed "${pacman_pkgs[@]}"
  (( ${#aur_pkgs[@]}    )) && yay -S --needed "${aur_pkgs[@]}"

  # Notification
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Finpac" "🎉 Installation complete!" --icon=software-update-available
  fi
  echo -e "🎉 \033[1;32mInstallation complete!\033[0m"
}
# -----------------------------------------------------
# END OF FILE
# -----------------------------------------------------

fpath+=~/.zfunc

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
