# ╔══════════════════════════════════════════════════════════════════════════╗
# ║   ~/.zshrc  —  Arch Linux · Zinit · Powerlevel10k  (v3.0)              ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── Powerlevel10k instant prompt (MUST be near top) ──────────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ════════════════════════════════════════════════════════════════════════════
# SECTION 1 — ENVIRONMENT
# ════════════════════════════════════════════════════════════════════════════

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R --use-color"

# ── PATH  (typeset -U deduplicates automatically) ────────────────────────────
typeset -U path
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.composer/vendor/bin"
  "$HOME/.bun/bin"
  $path
)

# ── Linuxbrew (optional — Arch users rarely need this) ───────────────────────
[[ -d /home/linuxbrew/.linuxbrew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# ════════════════════════════════════════════════════════════════════════════
# SECTION 2 — ZINIT PLUGIN MANAGER  (no Oh My Zsh — single manager)
# ════════════════════════════════════════════════════════════════════════════

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

# Install Zinit on first run (non-interactive, no shell startup blocking)
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
  print -P "%F{cyan}[zinit] First run — cloning zinit...%f"
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "$ZINIT_HOME/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
# ════════════════════════════════════════════════════════════════════════════
# SECTION 3 — COMPLETION SYSTEM
# ════════════════════════════════════════════════════════════════════════════

autoload -Uz compinit
# Rebuild .zcompdump only once per day (speeds up startup)
if [[ -n "${ZDOTDIR:-$HOME}/.zcompdump"(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'          # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:*' fzf-preview \
  'file "$realpath" 2>/dev/null | grep -q text && bat --color=always "$realpath" 2>/dev/null || echo "$realpath"'


# ── Theme ────────────────────────────────────────────────────────────────────
zinit ice depth=1; zinit light romkatv/powerlevel10k

# ── Core plugins (loaded immediately — order matters) ────────────────────────
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting   # must be last of the three

# ── Lazy-loaded completions (deferred until first use) ───────────────────────
zinit ice wait lucid; zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab

# ════════════════════════════════════════════════════════════════════════════
# SECTION 4 — SHELL OPTIONS
# ════════════════════════════════════════════════════════════════════════════

setopt autocd                 # type a dir name to cd into it
setopt interactivecomments    # allow # comments in interactive shell
setopt extendedglob           # extended globbing patterns
setopt nomatch                # error on unmatched globs
setopt appendhistory          # append to history, don't overwrite
setopt histignorealldups      # remove duplicate history entries
setopt sharehistory           # share history across sessions
unsetopt beep                 # no beep on errors
# NOTE: 'setopt correct' intentionally omitted — causes annoying "did you mean?"
#       prompts and breaks aliases/scripts.

HISTSIZE=50000
SAVEHIST=100000
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"

# ════════════════════════════════════════════════════════════════════════════
# SECTION 5 — KEY BINDINGS
# ════════════════════════════════════════════════════════════════════════════

bindkey -v                          # vi mode
bindkey '^R' history-incremental-search-backward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^[[A' history-search-backward   # Up arrow: history search
bindkey '^[[B' history-search-forward    # Down arrow

autoload -U select-word-style
select-word-style bash              # word navigation like bash (Ctrl+W etc.)

# ── FZF  (load exactly once from the right place) ────────────────────────────
_fzf_sourced=0
for _f in "$HOME/.fzf.zsh" /usr/share/fzf/key-bindings.zsh; do
  [[ -f "$_f" && $_fzf_sourced -eq 0 ]] && { source "$_f"; _fzf_sourced=1; }
done
unset _f _fzf_sourced
# Source completion separately (it's a different concern)
[[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

bindkey '^O' fzf-file-widget

# ════════════════════════════════════════════════════════════════════════════
# SECTION 6 — TOOLS (zoxide, vivid, fzf defaults)
# ════════════════════════════════════════════════════════════════════════════

# zoxide — smarter cd
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# vivid — LS_COLORS
command -v vivid >/dev/null 2>&1 && export LS_COLORS="$(vivid generate one-dark)"

# NVM — sourced exactly once
[[ -f /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh

# FZF default command
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

# ════════════════════════════════════════════════════════════════════════════
# SECTION 7 — ALIASES
# ════════════════════════════════════════════════════════════════════════════

# ── Navigation ───────────────────────────────────────────────────────────────
alias ls='lsd'
alias ll='lsd -lah --color=auto'
alias la='lsd -A'
alias l='lsd -a'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ── Editor ───────────────────────────────────────────────────────────────────
alias vim='nvim'
alias vi='nvim'

# ── Utilities ────────────────────────────────────────────────────────────────
alias please='sudo $(fc -ln -1)'
alias fs='fastfetch --config examples/22.jsonc'
alias cat='bat --style=auto'       # remove this line if bat is not installed
alias grep='grep --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'                  # interactive+verbose, safer than -rf alias

# ── Git ──────────────────────────────────────────────────────────────────────
alias gs='git status'
alias ga='git add'
alias gc='git commit -v'
alias gp='git push'
alias gl='git pull --ff-only'
alias gco='git checkout'
alias gd='git diff'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# ── Laravel/PHP ──────────────────────────────────────────────────────────────
alias art='php artisan'

# ── Arch-specific ────────────────────────────────────────────────────────────
if command -v pacman >/dev/null 2>&1; then
  alias update='sudo pacman -Syu && yay -Syu --noconfirm'
  alias pacs='pacman -Ss'          # search
  alias paci='sudo pacman -S'      # install
  alias pacr='sudo pacman -Rns'    # remove + orphans
  alias pacu='sudo pacman -Syu'    # update system
  alias pacl='pacman -Ql'          # list files in package
  alias pacown='pacman -Qo'        # which package owns file
  alias orphans='pacman -Qdtq | sudo pacman -Rns -' 2>/dev/null
fi

# ════════════════════════════════════════════════════════════════════════════
# SECTION 8 — LAMP HELPERS  (Apache + PostgreSQL)
# ════════════════════════════════════════════════════════════════════════════

start_lamp() {
  echo "▶ Starting Apache and PostgreSQL…"
  sudo systemctl enable --now httpd.service
  systemctl is-active --quiet httpd \
    && echo "  ✅ Apache started" \
    || echo "  ❌ Failed to start Apache"
  sudo systemctl enable --now postgresql.service
  systemctl is-active --quiet postgresql \
    && echo "  ✅ PostgreSQL started" \
    || echo "  ❌ Failed to start PostgreSQL"
  echo "  🌐 Browse : http://localhost/"
}

stop_lamp() {
  echo "⏹ Stopping Apache and PostgreSQL…"
  sudo systemctl stop    httpd.service postgresql.service
  sudo systemctl disable httpd.service postgresql.service
  echo "  🛑 All services stopped"
}

status_lamp() {
  echo "🔍 Service Status:"
  systemctl is-active --quiet httpd \
    && echo "  ✅ Apache is running" || echo "  ❌ Apache is stopped"
  systemctl is-active --quiet postgresql \
    && echo "  ✅ PostgreSQL is running" || echo "  ❌ PostgreSQL is stopped"
}

# ════════════════════════════════════════════════════════════════════════════
# SECTION 9 — DOWNLOAD FUNCTION  (yt-dlp frontend v3.0)
# ════════════════════════════════════════════════════════════════════════════

# ── Download config defaults (override in ~/.config/download/config) ─────────
DL_DEFAULT_QUALITY="${DL_DEFAULT_QUALITY:-1080}"
DL_VIDEO_DIR="${DL_VIDEO_DIR:-$HOME/Videos}"
DL_MUSIC_DIR="${DL_MUSIC_DIR:-$HOME/Music}"
DL_ARCHIVE="${DL_ARCHIVE:-}"
DL_PARALLEL="${DL_PARALLEL:-4}"
DL_RETRIES="${DL_RETRIES:-5}"
DL_FRAGMENT_RETRIES="${DL_FRAGMENT_RETRIES:-5}"
DL_SOCKET_TIMEOUT="${DL_SOCKET_TIMEOUT:-30}"
DL_THROTTLE_RATE="${DL_THROTTLE_RATE:-100K}"   # ISP resilience (Bangladesh)

# ── Colour helpers ────────────────────────────────────────────────────────────
_dl_red()    { print -P "%F{red}%B$*%b%f"; }
_dl_green()  { print -P "%F{green}%B$*%b%f"; }
_dl_yellow() { print -P "%F{yellow}$*%f"; }
_dl_cyan()   { print -P "%F{cyan}$*%f"; }
_dl_bold()   { print -P "%B$*%b"; }
_dl_error()  { print -P "%F{red}%B❌  $*%b%f" >&2; }
_dl_warn()   { print -P "%F{yellow}⚠️   $*%f" >&2; }
_dl_info()   { print -P "%F{cyan}ℹ️   $*%f"; }
_dl_ok()     { print -P "%F{green}%B✔   $*%b%f"; }

# ── Load optional user config ─────────────────────────────────────────────────
_dl_load_config() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/download/config"
  [[ -f "$cfg" ]] && source "$cfg"
}

# ── Help text ─────────────────────────────────────────────────────────────────
_dl_help() {
  cat <<'EOF'

  ╭─────────────────────────────────────────────────────────────────╮
  │                   download  —  yt-dlp frontend                  │
  ╰─────────────────────────────────────────────────────────────────╯

  USAGE
    download [options] <url> [url2 url3 ...]

  OPTIONS
    -p, --playlist         Download entire playlist
    -a, --audio            Audio-only (opus/best)
        --mp3              Force MP3 output (implies -a)
    -s, --subs             Embed subtitles (requires ffmpeg)
    -q, --quality <res>    Max video height: 480 | 720 | 1080 | 1440 | 2160
                           (default: 1080)
    -d, --dir <path>       Save to custom directory
    -c, --cookies <file>   Load cookies from file
        --chrome           Load cookies from Chrome
        --firefox          Load cookies from Firefox
    -A, --archive          Skip already-downloaded files
    -l, --list             List available formats (no download)
    -n, --parallel <N>     Parallel downloads for playlists (default: 4)
        --thumb            Thumbnail only (no video)
        --meta             Write JSON metadata only
        --no-notify        Disable desktop notifications
        --no-progress      Plain progress (good for pipes/logs)
        --clip <S-E>       Download a clip, e.g. --clip 1:30-3:45
        --clipboard        Read URL from clipboard
    -h, --help             Show this help

  CONFIG  (~/.config/download/config)
    DL_DEFAULT_QUALITY=1080
    DL_VIDEO_DIR="$HOME/Videos"
    DL_MUSIC_DIR="$HOME/Music"
    DL_ARCHIVE="$HOME/.cache/yt-dlp-archive"
    DL_PARALLEL=4
    DL_RETRIES=5
    DL_SOCKET_TIMEOUT=30
    DL_THROTTLE_RATE=100K

  EXAMPLES
    download https://youtu.be/dQw4w9WgXcQ
    download -a https://soundcloud.com/artist/track
    download --mp3 https://youtu.be/…
    download -q 1080 -p https://youtube.com/playlist?list=…
    download --chrome https://youtu.be/…
    download --clip 0:30-2:00 https://youtu.be/…
    download url1 url2 url3

EOF
}

# ── Argument parser ───────────────────────────────────────────────────────────
_dl_parse_args() {
  # Resets all variables into the calling scope
  PLAYLIST=0; AUDIO=0; FORCE_MP3=0; SUBS=0
  QUALITY="$DL_DEFAULT_QUALITY"
  VIDEO_DIR="$DL_VIDEO_DIR"; MUSIC_DIR="$DL_MUSIC_DIR"
  OUT_DIR=""
  ARCHIVE_FILE="$DL_ARCHIVE"; USE_ARCHIVE=0
  PARALLEL="$DL_PARALLEL"
  COOKIES_FILE=""; COOKIES_BROWSER=""
  LIST_FORMATS=0; THUMB_ONLY=0; META_ONLY=0
  NO_NOTIFY=0; NO_PROGRESS=0
  CLIP_START=""; CLIP_END=""
  USE_CLIPBOARD=0
  URLS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--playlist)    PLAYLIST=1 ;;
      -a|--audio)       AUDIO=1 ;;
         --mp3)         AUDIO=1; FORCE_MP3=1 ;;
      -s|--subs)        SUBS=1 ;;
      -A|--archive)     USE_ARCHIVE=1 ;;
      -l|--list)        LIST_FORMATS=1 ;;
         --thumb)       THUMB_ONLY=1 ;;
         --meta)        META_ONLY=1 ;;
         --no-notify)   NO_NOTIFY=1 ;;
         --no-progress) NO_PROGRESS=1 ;;
         --chrome)      COOKIES_BROWSER="chrome" ;;
         --firefox)     COOKIES_BROWSER="firefox" ;;
         --clipboard)   USE_CLIPBOARD=1 ;;
      -q|--quality)
        [[ -n $2 ]] || { _dl_error "Missing value after $1"; return 1; }
        QUALITY="$2"; shift ;;
      -d|--dir)
        [[ -n $2 ]] || { _dl_error "Missing value after $1"; return 1; }
        OUT_DIR="$2"; shift ;;
      -c|--cookies)
        [[ -n $2 ]] || { _dl_error "Missing value after $1"; return 1; }
        COOKIES_FILE="$2"; shift ;;
      -n|--parallel)
        [[ -n $2 ]] || { _dl_error "Missing value after $1"; return 1; }
        PARALLEL="$2"; shift ;;
      --clip)
        [[ -n $2 ]] || { _dl_error "Missing value after --clip (use S-E, e.g. 1:30-3:45)"; return 1; }
        CLIP_START="${2%-*}"; CLIP_END="${2#*-}"; shift ;;
      -h|--help)
        _dl_help; return 2 ;;   # 2 = help shown, caller should return 0
      -*)
        _dl_error "Unknown option: $1 — run: download --help"
        return 1 ;;
      *)
        URLS+=("$1") ;;
    esac
    shift
  done
}

# ── Build yt-dlp option array ─────────────────────────────────────────────────
_dl_build_opts() {
  OPTS=(
    -P "$OUT_DIR"
    --embed-metadata
    --embed-thumbnail
    --ignore-errors
    --no-warnings
    --restrict-filenames
    -N "$PARALLEL"
    --retries              "$DL_RETRIES"
    --fragment-retries     "$DL_FRAGMENT_RETRIES"
    --retry-sleep          3
    --retry-sleep          "fragment:2"
    --socket-timeout       "$DL_SOCKET_TIMEOUT"
    --throttled-rate       "$DL_THROTTLE_RATE"
    --continue
  )

  # Playlist vs single
  if (( PLAYLIST )); then
    OPTS+=(-o "%(playlist_title)s/%(playlist_index)03d - %(title)s.%(ext)s")
  else
    OPTS+=(--no-playlist -o "%(title)s.%(ext)s")
  fi

  # Format selection
  if (( AUDIO )); then
    OPTS+=(-x)
    if (( FORCE_MP3 )); then
      OPTS+=(-f bestaudio --audio-format mp3 --audio-quality 0)
    else
      OPTS+=(-f bestaudio --audio-format best --audio-quality 0)
    fi
  else
    # VP9+opus (free codec), fallback to h264+m4a (mobile-safe), then best
    local FMT="bestvideo[height<=${QUALITY}][vcodec^=vp9]+bestaudio[acodec=opus]"
    FMT+="/bestvideo[height<=${QUALITY}][ext=mp4]+bestaudio[ext=m4a]"
    FMT+="/bestvideo[height<=${QUALITY}]+bestaudio"
    FMT+="/best[height<=${QUALITY}]/best"
    OPTS+=(-f "$FMT")
  fi

  # Subtitles
  (( SUBS )) && OPTS+=(
    --write-subs --write-auto-subs
    --sub-langs "en,en-US,en-GB"
    --embed-subs
  )

  # Cookies
  if [[ -n $COOKIES_BROWSER ]]; then
    OPTS+=(--cookies-from-browser "$COOKIES_BROWSER")
  elif [[ -n $COOKIES_FILE ]]; then
    [[ -f $COOKIES_FILE ]] || { _dl_error "Cookies file not found: $COOKIES_FILE"; return 1; }
    OPTS+=(--cookies "$COOKIES_FILE")
  fi

  # Download archive
  if (( USE_ARCHIVE )); then
    ARCHIVE_FILE="${ARCHIVE_FILE:-$HOME/.cache/yt-dlp-archive}"
    mkdir -p "$(dirname "$ARCHIVE_FILE")"
    OPTS+=(--download-archive "$ARCHIVE_FILE")
    _dl_info "Archive: $ARCHIVE_FILE"
  fi

  # Clip  — use --download-sections for accurate cuts (better than postprocessor-args)
  if [[ -n $CLIP_START ]]; then
    OPTS+=(
      --download-sections "*${CLIP_START}-${CLIP_END}"
      --force-keyframes-at-cuts
    )
    _dl_info "Clipping: ${CLIP_START} → ${CLIP_END}"
  fi

  # Thumbnail / metadata only
  (( THUMB_ONLY )) && { OPTS+=(--write-thumbnail --skip-download); _dl_info "Thumbnail-only mode"; }
  (( META_ONLY  )) && { OPTS+=(--write-info-json  --skip-download); _dl_info "Metadata-only mode"; }

  # Notification hook
  if (( ! NO_NOTIFY )) && command -v notify-send >/dev/null 2>&1; then
    OPTS+=(--exec "notify-send '✅ Download complete' '%(title)s' --icon=video-x-generic")
  fi

  # Progress display — single-line, TTY-safe (NO multi-line cursor gymnastics)
  if (( NO_PROGRESS )) || [[ ! -t 1 ]]; then
    OPTS+=(--newline)
  else
    OPTS+=(
      --progress
      --progress-template "%(progress._percent_str)s │ %(progress._speed_str)s │ ETA %(progress._eta_str)s │ %(info.title).50s"
    )
  fi
}

# ── Render progress bar ───────────────────────────────────────────────────────
_dl_render_progress() {
  local pct="$1" speed="$2" eta="$3" title="$4"
  printf "\r📥  %-50.50s  %6s  ⚡ %-10s  ⏱ %-8s" "$title" "$pct" "$speed" "$eta"
}

# ── Main entry point ──────────────────────────────────────────────────────────
download() {
  _dl_load_config

  local PLAYLIST AUDIO FORCE_MP3 SUBS QUALITY VIDEO_DIR MUSIC_DIR OUT_DIR
  local ARCHIVE_FILE USE_ARCHIVE PARALLEL COOKIES_FILE COOKIES_BROWSER
  local LIST_FORMATS THUMB_ONLY META_ONLY NO_NOTIFY NO_PROGRESS
  local CLIP_START CLIP_END USE_CLIPBOARD
  local -a URLS OPTS

  _dl_parse_args "$@"
  local _rc=$?
  (( _rc == 2 )) && return 0   # help was shown
  (( _rc != 0 )) && return 1

  # ── Dependency check ────────────────────────────────────────────────────
  if ! command -v yt-dlp >/dev/null 2>&1; then
    _dl_error "yt-dlp not installed. Run: pip install -U yt-dlp"
    return 1
  fi

  # ── Clipboard ───────────────────────────────────────────────────────────
  if (( USE_CLIPBOARD )); then
    local _clip=""
    if   command -v wl-paste >/dev/null 2>&1; then _clip=$(wl-paste 2>/dev/null)
    elif command -v xclip    >/dev/null 2>&1; then _clip=$(xclip -o  2>/dev/null)
    elif command -v pbpaste  >/dev/null 2>&1; then _clip=$(pbpaste   2>/dev/null)
    else _dl_error "No clipboard tool (wl-paste / xclip / pbpaste)"; return 1
    fi
    [[ -z $_clip ]] && { _dl_error "Clipboard is empty"; return 1; }
    URLS+=("$_clip")
    _dl_info "URL from clipboard: $_clip"
  fi

  # ── Prompt if no URLs ────────────────────────────────────────────────────
  if [[ ${#URLS[@]} -eq 0 ]]; then
    _dl_warn "No URL provided."
    print -n "   Enter URL(s) separated by spaces: "
    read -r -A _input
    [[ ${#_input[@]} -eq 0 ]] && { _dl_error "No URL provided"; return 1; }
    URLS+=("${_input[@]}")
  fi

  # ── List formats (no download) ───────────────────────────────────────────
  if (( LIST_FORMATS )); then
    for u in "${URLS[@]}"; do
      _dl_cyan "━━━  Formats for: $u"
      yt-dlp -F "$u"
    done
    return 0
  fi

  # ── Validate quality ─────────────────────────────────────────────────────
  case "$QUALITY" in
    480|720|1080|1440|2160) ;;
    *) _dl_error "Invalid quality '$QUALITY'. Valid: 480 720 1080 1440 2160"; return 1 ;;
  esac

  # ── ffmpeg gate ──────────────────────────────────────────────────────────
  if { (( SUBS || FORCE_MP3 )) || [[ -n $CLIP_START ]]; } && ! command -v ffmpeg >/dev/null 2>&1; then
    _dl_error "ffmpeg required for the requested options but was not found."
    return 1
  fi

  # ── Resolve output directory ─────────────────────────────────────────────
  [[ -z $OUT_DIR ]] && OUT_DIR=$(( AUDIO )) && OUT_DIR="$MUSIC_DIR" || OUT_DIR="$VIDEO_DIR"
  [[ -z $OUT_DIR ]] && { (( AUDIO )) && OUT_DIR="$MUSIC_DIR" || OUT_DIR="$VIDEO_DIR"; }
  mkdir -p "$OUT_DIR" || { _dl_error "Cannot create directory: $OUT_DIR"; return 1; }

  _dl_build_opts || return 1

  # ── Run downloads ────────────────────────────────────────────────────────
  local START_TIME=$SECONDS DL_OK=0 DL_FAIL=0

  _dl_cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  _dl_bold "  ⬇  Downloading ${#URLS[@]} URL(s)  →  $OUT_DIR"
  _dl_cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  for u in "${URLS[@]}"; do
    echo
    _dl_info "URL: $u"

    local LOG_FILE
    LOG_FILE="$(mktemp /tmp/yt-dlp-XXXXXX.log)"
    trap 'rm -f "$LOG_FILE"' EXIT INT TERM

    if yt-dlp "${OPTS[@]}" "$u" 2> >(tee "$LOG_FILE" | grep -v 'HTTP Error 403' >&2); then
      (( DL_OK++ ))
    else
      (( DL_FAIL++ ))
      _dl_error "Download failed: $u"
      if [[ -s $LOG_FILE ]]; then
        _dl_warn "Last stderr output:"
        tail -5 "$LOG_FILE" >&2
      fi
    fi
    rm -f "$LOG_FILE"
    trap - EXIT INT TERM
  done

  # ── Summary ──────────────────────────────────────────────────────────────
  local ELAPSED=$(( SECONDS - START_TIME ))
  echo
  _dl_cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  (( DL_OK   > 0 )) && _dl_ok    "Downloaded : $DL_OK file(s)"
  (( DL_FAIL > 0 )) && _dl_error "Failed     : $DL_FAIL file(s)"
  _dl_bold   "  📂 Saved to : $OUT_DIR"
  _dl_bold   "  ⏱  Time     : $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s"
  _dl_cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  (( DL_FAIL > 0 )) && return 1 || return 0
}

# ── Zsh tab completion for download() ────────────────────────────────────────
_download_zsh_comp() {
  local -a opts
  opts=(
    '-p:Download entire playlist'         '--playlist:Download entire playlist'
    '-a:Audio only'                       '--audio:Audio only'
                                          '--mp3:Force MP3 output'
    '-s:Embed subtitles'                  '--subs:Embed subtitles'
    '-q:Max video quality'               '--quality:Max video quality'
    '-d:Output directory'                '--dir:Output directory'
    '-c:Cookies file'                    '--cookies:Cookies file'
                                          '--chrome:Cookies from Chrome'
                                          '--firefox:Cookies from Firefox'
    '-A:Use download archive'            '--archive:Use download archive'
    '-l:List formats'                    '--list:List formats'
    '-n:Parallel downloads'              '--parallel:Parallel downloads'
                                          '--thumb:Thumbnail only'
                                          '--meta:Metadata only'
                                          '--no-notify:Disable notifications'
                                          '--no-progress:Plain progress'
                                          '--clip:Download a clip S-E'
                                          '--clipboard:URL from clipboard'
    '-h:Show help'                       '--help:Show help'
  )
  _describe 'download options' opts
}
compdef _download_zsh_comp download

# ════════════════════════════════════════════════════════════════════════════
# SECTION 10 — FUZZY PACKAGE INSTALLERS
# ════════════════════════════════════════════════════════════════════════════

# ── finpac — fuzzy Arch package installer (pacman + AUR via yay) ─────────────
finpac() {
  for dep in fzf yay pacman; do
    command -v "$dep" >/dev/null 2>&1 && continue
    echo -e "⚠️  \033[1;31m$dep is not installed\033[0m."
    case "$dep" in
      fzf)    echo "    sudo pacman -S fzf" ;;
      yay)    echo "    (install yay from AUR)" ;;
      pacman) echo "    pacman missing — are you even on Arch? 👀" ;;
    esac
    return 1
  done

  local _list
  _list=$(
    {
      pacman -Slq 2>/dev/null | sort -u | sed 's/^/pacman:/'
      yay    -Slq 2>/dev/null | sort -u | sed 's/^/aur:/'
    } | sort -u
  )
  [[ -z "$_list" ]] && { echo "⚠️  No packages found."; return 1; }

  local sel
  sel=$(printf '%s\n' "$_list" |
    fzf --multi --height=60% --reverse \
        --prompt='🔍 Search packages > ' --border --ansi \
        --preview='
          pkg_type=$(echo {} | cut -d: -f1)
          pkg_name=$(echo {} | cut -d: -f2-)
          echo -e "\033[1;36m$(printf "━%.0s" {1..60})\033[0m"
          echo -e "📦 \033[1;37mPackage:\033[0m $pkg_name  📂 \033[1;37mSource:\033[0m $pkg_type"
          echo -e "\033[1;36m$(printf "━%.0s" {1..60})\033[0m"
          [[ $pkg_type == pacman ]] && pacman -Si "$pkg_name" 2>/dev/null || yay -Si "$pkg_name" 2>/dev/null
        ' \
        --preview-window=right,70%) || return 0

  [[ -z $sel ]] && return 0

  local -a pacman_pkgs aur_pkgs
  while IFS= read -r line; do
    [[ $line == pacman:* ]] && pacman_pkgs+=("${line#pacman:}") || aur_pkgs+=("${line#aur:}")
  done <<< "$sel"

  echo -e "\n\033[1;32m$(printf "═%.0s" {1..60})\033[0m"
  echo -e "📦  \033[1;37mReady to install:\033[0m"
  (( ${#pacman_pkgs[@]} > 0 )) && echo -e "   🏛  Repo: \033[1;36m${pacman_pkgs[*]}\033[0m"
  (( ${#aur_pkgs[@]}    > 0 )) && echo -e "   🚀  AUR:  \033[1;35m${aur_pkgs[*]}\033[0m"
  echo -e "\033[1;32m$(printf "═%.0s" {1..60})\033[0m"

  printf "✅ Proceed? [y/N]: "
  local ans; read -r ans
  [[ $ans =~ ^[Yy]$ ]] || { echo "❌ Cancelled."; return 0; }

  (( ${#pacman_pkgs[@]} > 0 )) && sudo pacman -S --needed "${pacman_pkgs[@]}"
  (( ${#aur_pkgs[@]}    > 0 )) && yay -S --needed "${aur_pkgs[@]}"

  command -v notify-send >/dev/null 2>&1 && \
    notify-send "finpac" "🎉 Installation complete!" --icon=software-update-available
  echo -e "🎉 \033[1;32mInstallation complete!\033[0m"
}

# ── fbrew — fuzzy Homebrew installer (Linuxbrew) ─────────────────────────────
fbrew() {
  command -v fzf  >/dev/null 2>&1 || { echo "⚠️  fzf not installed." >&2; return 1; }
  command -v brew >/dev/null 2>&1 || { echo "⚠️  brew not installed." >&2; return 1; }

  local _list
  _list=$({ brew formulae; brew casks | sed 's/^/cask:/'; } 2>/dev/null | sort -u)
  [[ -z "$_list" ]] && { echo "⚠️  No brew packages found."; return 1; }

  local sel
  sel=$(printf '%s\n' "$_list" |
    fzf --multi --height=40% --reverse --prompt='fbrew> ' --border \
        --preview='
          [[ {} == cask:* ]] && brew info --cask "${${(s.:.)@}[2]}" ||
          brew info {}
        ' \
        --preview-window=right,70%) || return 0

  [[ -z $sel ]] && return 0

  local -a formulas casks
  for line in ${(f)sel}; do
    [[ $line == cask:* ]] && casks+=("${line#cask:}") || formulas+=("$line")
  done

  (( ${#formulas[@]} > 0 )) && brew install "${formulas[@]}"
  (( ${#casks[@]}    > 0 )) && brew install --cask "${casks[@]}"
}

# ════════════════════════════════════════════════════════════════════════════
# SECTION 11 — LOCAL EXTRAS
# ════════════════════════════════════════════════════════════════════════════

fpath+=("$HOME/.zfunc")

# Load any personal overrides / secrets
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ── Powerlevel10k config ──────────────────────────────────────────────────────
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# ════════════════════════════════════════════════════════════════════════════
# END OF FILE
# ════════════════════════════════════════════════════════════════════════════

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
