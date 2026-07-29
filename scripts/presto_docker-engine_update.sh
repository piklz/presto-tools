#!/usr/bin/env bash

#  __/\\\\\\\\\\\\\______/\\\\\\\\\______/\\\\\\\\\\\\\\\_____/\\\\\\\\\\\____/\\\\\\\\\\\\\\\_______/\\\\\______
#   _\/\\\/////////\\\__/\\\///////\\\___\/\\\///////////____/\\\/////////\\\_\///////\\\/////______/\\\///\\\____
#    _\/\\\_______\/\\\_\/\\\_____\/\\\___\/\\\______________\//\\\______\///________\/\\\_________/\\\/__\///\\\__
#     _\/\\\\\\\\\\\\\/__\/\\\\\\\\\\\/____\/\\\\\\\\\\\_______\////\\\_______________\/\\\________/\\\______\//\\\_
#      _\/\\\/////////____\/\\\//////\\\____\/\\\///////___________\////\\\____________\/\\\_______\/\\\_______\/\\\_
#       _\/\\\_____________\/\\\____\//\\\___\/\\\_____________________\////\\\_________\/\\\_______\//\\\______/\\\__
#        _\/\\\_____________\/\\\_____\//\\\__\/\\\______________/\\\______\//\\\________\/\\\________\///\\\__/\\\____
#         _\/\\\_____________\/\\\______\//\\\_\/\\\\\\\\\\\\\\\_\///\\\\\\\\\\\/_________\/\\\__________\///\\\\\/______
#          _\///______________\///________\///__\///////////////____\///////////___________\///_____________\/////_______

#######################################################  TOOLS  #########################################################
# Description: Docker engine / compose version checker and updater via apt manager
# Version: 1.3.0
# Last Updated: 29/07/2026
#
# Changelog:
#  - v1.3.0 - 29/07/2026  : Added run_with_spinner() animated spinner for manual-mode tasks
#             (apt sync, upstream version checks, installs). Fixed dependency pre-check
#             running "sudo apt install" synchronously even in --check/login mode. Fixed
#             apt --simulate upgrade being run without sudo (was silently returning empty
#             results on some systems). Background sudo apt update now uses "sudo -n" so a
#             missing passwordless-sudo rule fails fast instead of hanging an orphaned job.
#  - v1.2.0 - 11/04/2026  : Introduced TTL-based offline-first caching for --check (login) mode.
#             Cache is read instantly from disk; stale cache triggers a fully detached background
#             refresh so login never blocks on network. apt update and apt simulate are also
#             TTL-gated and run in the background, never on the login path. Manual mode always
#             fetches live. Added CACHE_MAX_AGE_HOURS tunable.
#  - v1.1.0 - 11/04/2026  : Fixed CORE_DEPS grep (case mismatch), added ETag caching, set -uo
#             pipefail, Docker/daemon guards, version sanitisation, safer compose extraction.
#  - v1.0.4 - 09/04/2026  : Added SSL security library checks and final confirmation message.
#  - v1.0.3 - 08/04/2026  : Added dependency pre-checks for curl, grep, awk.

set -uo pipefail

# -------------------------------------------------------
# CUSTOMISING UPDATE CHECK FREQUENCY
# -------------------------------------------------------
CACHE_MAX_AGE_HOURS=6

# -------------------------------------------------------
# COLORS
# -------------------------------------------------------
blue="\e[34m"
green="\e[32m"
red="\e[31m"
yellow="\e[33m"
no_col="\e[0m"

# -------------------------------------------------------
# MATRIX REVEAL
# Scrambles "$1" with half-width katakana + symbol noise, then
# sweeps a reveal line left → right over "$2" seconds until the
# real text is fully shown. Half-width katakana is single-column
# in virtually every UTF-8 terminal (unlike full-width CJK, which
# is double-width and breaks alignment), so this stays authentic
# without wrecking the printf spacing. Manual-mode flourish only
# — never call this in --check mode, it's a blocking animation.
#
#   matrix_reveal "presto engine check" 3
# -------------------------------------------------------
matrix_reveal() {
    local text="$1"
    local duration="${2:-3}"
    local fps=20
    # Half-width katakana (single-column) + a few ASCII glyphs for
    # variety. Falls back gracefully to '?' glyphs on non-UTF-8
    # locales/consoles, but never breaks column alignment.
    local charset='ｦｱｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾂﾃﾅﾆﾇﾈﾊﾋﾎﾏﾐﾑﾒﾓﾔﾕﾗﾘﾜﾝ!@#$%^&*<>?01'
    local charset_len=${#charset}
    local len=${#text}
    local total_frames=$(( duration * fps ))
    local frame_delay
    frame_delay=$(awk -v f="$fps" 'BEGIN{printf "%f", 1/f}')

    tput civis 2>/dev/null

    local frame
    for (( frame=0; frame<=total_frames; frame++ )); do
        local progress
        progress=$(awk -v f="$frame" -v tf="$total_frames" -v l="$len" \
            'BEGIN{printf "%d", (f/tf)*l}')

        local out="" i ch r
        for (( i=0; i<len; i++ )); do
            ch="${text:i:1}"
            if [[ "$ch" == " " ]]; then
                out+=" "
            elif (( i < progress )); then
                out+="$ch"
            else
                r=$(( RANDOM % charset_len ))
                out+="${charset:r:1}"
            fi
        done

        printf "\r${green}%s${no_col}" "$out"
        sleep "$frame_delay"
    done

    printf "\r${green}%s${no_col}\n" "$text"
    tput cnorm 2>/dev/null
}

# -------------------------------------------------------
# MATRIX REVEAL — CONCURRENT VARIANT
# Same left-to-right katakana sweep, but runs it WHILE a real
# command executes in the background instead of as a fixed-length
# intro. The sweep itself always takes ~1.5s; if the command is
# still running once fully revealed, the last frame just holds
# until the command finishes. Captures stdout in $SPINNER_STDOUT
# exactly like run_with_spinner, so it's a drop-in replacement.
#
#   matrix_reveal_while "presto engine check" sudo apt-get update -qq
#   result="$SPINNER_STDOUT"
# -------------------------------------------------------
matrix_reveal_while() {
    local text="$1"; shift
    local outfile errfile
    outfile=$(mktemp)
    errfile=$(mktemp)

    "$@" >"$outfile" 2>"$errfile" &
    local pid=$!

    local fps=20
    local sweep_seconds=1.5
    local sweep_frames
    sweep_frames=$(awk -v s="$sweep_seconds" -v f="$fps" 'BEGIN{printf "%d", s*f}')
    local charset='ｦｱｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾂﾃﾅﾆﾇﾈﾊﾋﾎﾏﾐﾑﾒﾓﾔﾕﾗﾘﾜﾝ!@#$%^&*<>?01'
    local charset_len=${#charset}
    local len=${#text}
    local frame_delay
    frame_delay=$(awk -v f="$fps" 'BEGIN{printf "%f", 1/f}')

    tput civis 2>/dev/null

    local frame=0
    while kill -0 "$pid" 2>/dev/null; do
        local progress
        if (( frame < sweep_frames )); then
            progress=$(awk -v f="$frame" -v tf="$sweep_frames" -v l="$len" \
                'BEGIN{printf "%d", (f/tf)*l}')
        else
            progress=$len   # sweep finished, hold fully-revealed text while task keeps running
        fi

        local out="" i ch r
        for (( i=0; i<len; i++ )); do
            ch="${text:i:1}"
            if [[ "$ch" == " " ]]; then
                out+=" "
            elif (( i < progress )); then
                out+="$ch"
            else
                r=$(( RANDOM % charset_len ))
                out+="${charset:r:1}"
            fi
        done

        printf "\r${green}%s${no_col}" "$out"
        sleep "$frame_delay"
        (( frame++ ))
    done

    wait "$pid"
    local status=$?

    tput cnorm 2>/dev/null
    printf "\r\033[K"

    if [[ $status -eq 0 ]]; then
        printf "${green}✅ %s${no_col}\n" "$text"
    else
        printf "${red}❌ %s${no_col}\n" "$text"
        [[ -s "$errfile" ]] && sed 's/^/   /' "$errfile" >&2
    fi

    SPINNER_STDOUT=$(<"$outfile")
    rm -f "$outfile" "$errfile"
    return $status
}

# -------------------------------------------------------
# ARGS
# -------------------------------------------------------
MODE="${1:-}"

# -------------------------------------------------------
# REAL USER HOME  (safe under sudo)
# -------------------------------------------------------
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_USER="$SUDO_USER"
else
    USER_HOME="$HOME"
    REAL_USER="$(id -un)"
fi

# -------------------------------------------------------
# CACHE LAYOUT
# -------------------------------------------------------
CACHE_DIR="${XDG_CACHE_HOME:-$USER_HOME/.cache}/presto"
mkdir -p "$CACHE_DIR"

DOCKER_VER_FILE="$CACHE_DIR/docker_version"
DOCKER_ETAG_FILE="$CACHE_DIR/docker_etag"
COMPOSE_VER_FILE="$CACHE_DIR/compose_version"
COMPOSE_ETAG_FILE="$CACHE_DIR/compose_etag"
APT_ALERTS_FILE="$CACHE_DIR/apt_pkg_alerts"
LAST_NET_SYNC="$CACHE_DIR/last_network_sync"
LAST_APT_SYNC="$CACHE_DIR/last_apt_sync"

# -------------------------------------------------------
# SPINNER
# Runs a command (function or plain binary) in the background,
# animates a braille spinner next to a label while it runs, then
# replaces the line with a check or cross. Command's stdout is
# captured in $SPINNER_STDOUT so callers can still consume return
# values (e.g. a fetched version string) as if they'd called it
# directly and command-substituted the result.
#
#   run_with_spinner "Checking Docker upstream..." fetch_latest_github_tag "moby/moby" "$DOCKER_VER_FILE" "$DOCKER_ETAG_FILE"
#   LATEST_DOCKER="$SPINNER_STDOUT"
#
# On failure, stderr is echoed (indented) below the ❌ line and the
# function returns the wrapped command's exit status.
# -------------------------------------------------------
run_with_spinner() {
    local label="$1"; shift
    local outfile errfile
    outfile=$(mktemp)
    errfile=$(mktemp)

    "$@" >"$outfile" 2>"$errfile" &
    local pid=$!

    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local nframes=${#frames}

    tput civis 2>/dev/null

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${yellow}%s${no_col} %s" "${frames:i++%nframes:1}" "$label"
        sleep 0.1
    done

    wait "$pid"
    local status=$?

    tput cnorm 2>/dev/null
    printf "\r\033[K"

    if [[ $status -eq 0 ]]; then
        printf "${green}✅ %s${no_col}\n" "$label"
    else
        printf "${red}❌ %s${no_col}\n" "$label"
        [[ -s "$errfile" ]] && sed 's/^/   /' "$errfile" >&2
    fi

    SPINNER_STDOUT=$(<"$outfile")
    rm -f "$outfile" "$errfile"
    return $status
}

# -------------------------------------------------------
# HELPERS
# -------------------------------------------------------
cache_age_seconds() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo $(( $(date +%s) - $(date -r "$file" +%s 2>/dev/null || echo 0) ))
    else
        echo 999999
    fi
}

cache_is_fresh() {
    local file="$1"
    local max_hours="${2:-$CACHE_MAX_AGE_HOURS}"
    local age
    age=$(cache_age_seconds "$file")
    (( age < max_hours * 3600 ))
}

sanitise_version() {
    echo "${1:-}" | sed 's/^docker-//' | sed 's/^[vV]//' | sed 's/[-+].*//'
}

compare_versions() {
    awk -v current="$1" -v latest="$2" '
    function clean(ver,   arr, i, out) {
        split(ver, arr, ".")
        out = ""
        for (i = 1; i <= length(arr); i++) {
            gsub(/[^0-9].*$/, "", arr[i])
            out = out (i == 1 ? "" : ".") (arr[i] == "" ? "0" : arr[i])
        }
        return out
    }
    BEGIN {
        current = clean(current); latest = clean(latest)
        split(current, cur, "."); split(latest, lat, ".")
        n = length(cur) > length(lat) ? length(cur) : length(lat)
        for (i = 1; i <= n; i++) {
            c = (cur[i]=="" ? 0 : cur[i]); l = (lat[i]=="" ? 0 : lat[i])
            if (c+0 < l+0) { print "newer"; exit }
            if (c+0 > l+0) { print "older"; exit }
        }
        print "equal"
    }'
}

# Fetch latest GitHub release tag with ETag caching.
# Writes version to ver_file, ETag to etag_file; echoes version to stdout.
# Falls back to stale cache on network failure.
fetch_latest_github_tag() {
    local repo="$1" ver_file="$2" etag_file="$3"
    local url="https://api.github.com/repos/${repo}/releases/latest"

    local etag_args=()
    [[ -f "$etag_file" ]] && etag_args=(-H "If-None-Match: $(cat "$etag_file")")

    # -D- dumps response headers to stdout ahead of the body, so we can grab
    # the ETag from the SAME response instead of firing a second request.
    local http_output http_code headers body
    http_output=$(curl -sfL --max-time 10 \
        -H "Accept: application/vnd.github+json" \
        "${etag_args[@]}" \
        -D- \
        -w "\n__HTTP_CODE__:%{http_code}" \
        "$url" 2>/dev/null) || {
        [[ -f "$ver_file" ]] && { cat "$ver_file"; return 0; }
        return 1
    }

    http_code=$(echo "$http_output" | grep '__HTTP_CODE__:' | tail -n1 | cut -d: -f2)
    headers=$(echo "$http_output" | sed -n '1,/^\r\?$/p')
    body=$(echo "$http_output" | sed -n '/^\r\?$/,$p' | grep -v '__HTTP_CODE__:')

    if [[ "$http_code" == "304" ]]; then
        touch "$LAST_NET_SYNC"
        [[ -f "$ver_file" ]] && { cat "$ver_file"; return 0; }
        rm -f "$etag_file"
        fetch_latest_github_tag "$repo" "$ver_file" "$etag_file"; return $?
    fi

    if [[ "$http_code" != "200" ]]; then
        echo -e "${red}❌ GitHub API HTTP $http_code for $repo${no_col}" >&2
        [[ -f "$ver_file" ]] && { cat "$ver_file"; return 0; }
        return 1
    fi

    local tag
    tag=$(echo "$body" | grep '"tag_name":' | cut -d'"' -f4)
    [[ -z "$tag" ]] && { echo -e "${red}❌ Could not parse tag_name for $repo${no_col}" >&2; return 1; }

    local new_etag
    new_etag=$(echo "$headers" | grep -i '^etag:' | awk '{print $2}' | tr -d '\r')
    [[ -n "$new_etag" ]] && echo "$new_etag" > "$etag_file"

    local version
    version=$(sanitise_version "$tag")
    echo "$version" > "$ver_file"
    touch "$LAST_NET_SYNC"
    echo "$version"
}

# -------------------------------------------------------
# BACKGROUND REFRESH
# -------------------------------------------------------
spawn_background_refresh() {
    local log="$CACHE_DIR/bg_refresh.log"

    setsid bash <<BGSCRIPT >>"$log" 2>&1 &
set -uo pipefail

CACHE_DIR="$CACHE_DIR"
DOCKER_VER_FILE="$DOCKER_VER_FILE"
DOCKER_ETAG_FILE="$DOCKER_ETAG_FILE"
COMPOSE_VER_FILE="$COMPOSE_VER_FILE"
COMPOSE_ETAG_FILE="$COMPOSE_ETAG_FILE"
APT_ALERTS_FILE="$APT_ALERTS_FILE"
LAST_NET_SYNC="$LAST_NET_SYNC"
LAST_APT_SYNC="$LAST_APT_SYNC"
red='\e[31m' no_col='\e[0m'

$(declare -f sanitise_version)
$(declare -f fetch_latest_github_tag)

echo "[$(date)] Starting background refresh"

fetch_latest_github_tag "moby/moby"        "\$DOCKER_VER_FILE"  "\$DOCKER_ETAG_FILE"  >/dev/null
fetch_latest_github_tag "docker/compose" "\$COMPOSE_VER_FILE" "\$COMPOSE_ETAG_FILE" >/dev/null

# -n = non-interactive: fail fast instead of hanging an orphaned
# detached process if passwordless sudo isn't configured for apt.
if sudo -n true 2>/dev/null; then
    sudo -n apt update -qq 2>/dev/null
    sudo -n apt --simulate upgrade 2>/dev/null \
        | grep -E '^Inst (libssl|openssl|libtiff|libc6|ca-certificates|libseccomp2)' \
        | awk '{print \$2}' > "\$APT_ALERTS_FILE"
    touch "\$LAST_APT_SYNC"
else
    echo "[$(date)] Skipping apt refresh: passwordless sudo not available"
fi

echo "[$(date)] Background refresh complete"
BGSCRIPT

    disown $! 2>/dev/null || true

    if [[ -f "$log" ]] && (( $(wc -l < "$log") > 40 )); then
        tail -40 "$log" > "${log}.tmp" && mv "${log}.tmp" "$log"
    fi
}

# -------------------------------------------------------
# DEPENDENCY PRE-CHECK
# In --check (login) mode we must NEVER run a blocking "sudo apt
# install" — that was the old bug. If a dep is missing on login we
# just skip silently (the tool degrades gracefully) and let manual
# mode install it later.
# -------------------------------------------------------
for pkg in curl grep awk; do
    if ! command -v "$pkg" &>/dev/null; then
        if [[ "$MODE" == "--check" ]]; then
            # Silent skip — do not block login on an install.
            continue
        fi
        run_with_spinner "Installing missing dependency: $pkg" sudo apt install -y "$pkg"
    fi
done

# -------------------------------------------------------
# DOCKER PRESENCE + DAEMON GUARD
# -------------------------------------------------------
if ! command -v docker &>/dev/null; then
    echo -e "${red}❌ Docker is not installed or not in PATH.${no_col}"
    exit 1
fi

CURRENT_DOCKER_RAW=$(docker version --format '{{.Server.Version}}' 2>/dev/null || true)
if [[ -z "$CURRENT_DOCKER_RAW" ]]; then
    [[ "$MODE" == "--check" ]] && exit 0
    echo -e "${red}❌ Cannot reach Docker daemon. Try: sudo systemctl start docker${no_col}"
    exit 1
fi
CURRENT_DOCKER=$(sanitise_version "$CURRENT_DOCKER_RAW")

if docker compose version --short &>/dev/null 2>&1; then
    CURRENT_COMPOSE_RAW=$(docker compose version --short 2>/dev/null)
else
    CURRENT_COMPOSE_RAW=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
fi
CURRENT_COMPOSE=$(sanitise_version "${CURRENT_COMPOSE_RAW:-0.0.0}")


# ═══════════════════════════════════════════════════════
#  LOGIN / QUIET MODE  (--check)
# ═══════════════════════════════════════════════════════
if [[ "$MODE" == "--check" ]]; then

    if ! cache_is_fresh "$LAST_NET_SYNC"; then
        spawn_background_refresh
    fi

    if [[ ! -f "$DOCKER_VER_FILE" || ! -f "$COMPOSE_VER_FILE" ]]; then
        exit 0
    fi

    LATEST_DOCKER=$(cat  "$DOCKER_VER_FILE")
    LATEST_COMPOSE=$(cat "$COMPOSE_VER_FILE")

    DOCKER_UPDATE=$(compare_versions  "$CURRENT_DOCKER"  "$LATEST_DOCKER")
    COMPOSE_UPDATE=$(compare_versions "$CURRENT_COMPOSE" "$LATEST_COMPOSE")

    UPDATE_AVAILABLE=0
    [[ "$COMPOSE_UPDATE" == "newer" ]] && {
        printf "${yellow}⬆️  %-20s ${red}%-10s${no_col} → ${green}%s${no_col}\n" \
    "Docker Compose:" "v${CURRENT_COMPOSE}" "v${LATEST_COMPOSE}"
        UPDATE_AVAILABLE=1
    }
    [[ "$DOCKER_UPDATE" == "newer" ]] && {
        printf "${yellow}⬆️  %-20s ${red}%-10s${no_col} → ${green}%s${no_col}\n" \
    "Docker Engine:" "v${CURRENT_DOCKER}" "v${LATEST_DOCKER}"
        UPDATE_AVAILABLE=1
    }
    [[ "$UPDATE_AVAILABLE" -eq 1 ]] && \
        echo -e "${blue}👉 Run ${yellow}presto_engine_update${blue} to apply.${no_col}"

    if [[ -f "$APT_ALERTS_FILE" ]]; then
        CORE_DEPS=$(cat "$APT_ALERTS_FILE")
        [[ -n "$CORE_DEPS" ]] && \
            echo -e "${yellow}⚠️  Security library updates pending — run ${blue}sudo apt upgrade${no_col}"
    fi

    exit 0
fi


# ═══════════════════════════════════════════════════════
#  MANUAL / INTERACTIVE MODE  (no flag)
#  Always fetches live. Full output. Yes/no prompts.
#  Every network/apt step now shows an animated spinner
#  instead of a static message that just gets wiped.
# ═══════════════════════════════════════════════════════

matrix_reveal_while "presto engine check" sudo apt-get update -qq

run_with_spinner "Checking Docker Engine upstream version..." \
    fetch_latest_github_tag "moby/moby" "$DOCKER_VER_FILE" "$DOCKER_ETAG_FILE"
if [[ $? -ne 0 ]]; then
    echo -e "${red}❌ Failed to retrieve Docker Engine upstream version.${no_col}"
    exit 1
fi
LATEST_DOCKER="$SPINNER_STDOUT"

run_with_spinner "Checking Docker Compose upstream version..." \
    fetch_latest_github_tag "docker/compose" "$COMPOSE_VER_FILE" "$COMPOSE_ETAG_FILE"
if [[ $? -ne 0 ]]; then
    echo -e "${red}❌ Failed to retrieve Docker Compose upstream version.${no_col}"
    exit 1
fi
LATEST_COMPOSE="$SPINNER_STDOUT"

DOCKER_UPDATE=$(compare_versions  "$CURRENT_DOCKER"  "$LATEST_DOCKER")
COMPOSE_UPDATE=$(compare_versions "$CURRENT_COMPOSE" "$LATEST_COMPOSE")
UPDATE_NEEDED=0

[[ "$COMPOSE_UPDATE" == "newer" ]] && {
    printf "${yellow}⬆️  %-20s ${red}%-10s${no_col} → ${green}%s${no_col}\n" \
    "Docker Compose:" "v${CURRENT_COMPOSE}" "v${LATEST_COMPOSE}"
    UPDATE_NEEDED=1
}
[[ "$DOCKER_UPDATE" == "newer" ]] && {
    printf "${yellow}⬆️  %-20s ${red}%-10s${no_col} → ${green}%s${no_col}\n" \
    "Docker Engine:" "v${CURRENT_DOCKER}" "v${LATEST_DOCKER}"
    UPDATE_NEEDED=1
}

if [[ "$UPDATE_NEEDED" -eq 1 ]]; then
    echo -e "${yellow}Do you want to update now? (y/N)${no_col}"
    read -r REPLY
    if [[ ! "${REPLY:-}" =~ ^[Yy]$ ]]; then
        echo -e "${red}🚫 Update cancelled.${no_col}"
    else
        if [[ "$COMPOSE_UPDATE" == "newer" ]]; then
            run_with_spinner "Updating Docker Compose to v${LATEST_COMPOSE}..." \
                sudo apt install -y docker-compose-plugin
        fi

        if [[ "$DOCKER_UPDATE" == "newer" ]]; then
            run_with_spinner "Updating Docker Engine & Containerd..." \
                sudo apt install -y docker-ce docker-ce-cli containerd.io
            run_with_spinner "Restarting Docker service..." \
                sudo systemctl restart docker
        fi
        rm -f "$DOCKER_VER_FILE" "$COMPOSE_VER_FILE" \
              "$DOCKER_ETAG_FILE" "$COMPOSE_ETAG_FILE" \
              "$LAST_NET_SYNC"
    fi
else
    echo -e "${green}✅ Docker Engine (v${CURRENT_DOCKER}) and Docker Compose (v${CURRENT_COMPOSE}) are up to date. 🐋${no_col}"
fi

# ---- Live security / SSL library check (now correctly run with sudo) ----
run_with_spinner "Checking system security libraries..." \
    sudo apt --simulate upgrade
CORE_DEPS=$(echo "$SPINNER_STDOUT" \
    | grep -E '^Inst (libssl|openssl|libtiff|libc6|ca-certificates|libseccomp2)' \
    | awk '{print $2}')

echo "$CORE_DEPS" > "$APT_ALERTS_FILE"
touch "$LAST_APT_SYNC"

if [[ -n "$CORE_DEPS" ]]; then
    echo -e "${yellow}⚠️  Security library updates are pending:${no_col}"
    while IFS= read -r dep; do
        echo -e "   ${red}•${no_col} $dep"
    done <<< "$CORE_DEPS"
    echo -e "${blue}👉 Run ${yellow}sudo apt upgrade${blue} to apply.${no_col}"
else
    echo -e "${green}✅ All underlying system libraries are current.${no_col}"
fi

echo -e "${blue}🏁 Check complete.${no_col}"