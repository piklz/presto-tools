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
# Version: 1.2.0
# Last Updated: 11/04/2026
#
# Changelog:
#  - v1.2.0 - 11/04/2026  : Introduced TTL-based offline-first caching for --check (login) mode.
#             Cache is read instantly from disk; stale cache triggers a fully detached background
#             refresh so login never blocks on network. apt-get update and apt simulate are also
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
# How many hours before a background cache refresh is triggered on login.
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
#   $CACHE_DIR/
#     docker_version      — last known upstream Docker Engine version
#     docker_etag         — GitHub ETag for conditional GET
#     compose_version     — last known upstream Compose version
#     compose_etag
#     apt_pkg_alerts      — pending security package names (from apt simulate)
#     last_network_sync   — timestamp touched after a successful GitHub fetch
#     last_apt_sync       — timestamp touched after apt update + simulate
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
# HELPERS
# -------------------------------------------------------

# Seconds since a file was last modified (huge number if file absent)
cache_age_seconds() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo $(( $(date +%s) - $(date -r "$file" +%s 2>/dev/null || echo 0) ))
    else
        echo 999999
    fi
}

# Returns 0 (true) if the cache file is younger than max_age_hours
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

# Prints: newer | older | equal
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

    local http_output http_code body
    http_output=$(curl -sfL --max-time 10 \
        -H "Accept: application/vnd.github+json" \
        "${etag_args[@]}" \
        -w "\n__HTTP_CODE__:%{http_code}" \
        "$url" 2>/dev/null) || {
        [[ -f "$ver_file" ]] && { cat "$ver_file"; return 0; }
        return 1
    }

    http_code=$(echo "$http_output" | grep '__HTTP_CODE__:' | cut -d: -f2)
    body=$(echo "$http_output" | grep -v '__HTTP_CODE__:')

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

    # Grab ETag via a cheap headers-only request
    local new_etag
    new_etag=$(curl -sIL --max-time 8 -H "Accept: application/vnd.github+json" "$url" 2>/dev/null \
        | grep -i '^etag:' | awk '{print $2}' | tr -d '\r') || true
    [[ -n "$new_etag" ]] && echo "$new_etag" > "$etag_file"

    local version
    version=$(sanitise_version "$tag")
    echo "$version" > "$ver_file"
    touch "$LAST_NET_SYNC"
    echo "$version"
}

# -------------------------------------------------------
# BACKGROUND REFRESH
# Spawns a fully detached subshell (setsid) so login doesn't wait.
# Updates GitHub version cache AND apt alerts cache.
# Output goes to a rotating log file, never the terminal.
# -------------------------------------------------------
spawn_background_refresh() {
    local log="$CACHE_DIR/bg_refresh.log"

    # Export everything the subshell needs by inlining function bodies and vars
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

sudo apt-get update -qq 2>/dev/null
apt-get --simulate upgrade 2>/dev/null \
    | grep -E '^Inst (libssl|openssl|libtiff|libc6|ca-certificates|libseccomp2)' \
    | awk '{print \$2}' > "\$APT_ALERTS_FILE"
touch "\$LAST_APT_SYNC"

echo "[$(date)] Background refresh complete"
BGSCRIPT

    disown $! 2>/dev/null || true

    # Keep the log from growing forever (keep last 40 lines)
    if [[ -f "$log" ]] && (( $(wc -l < "$log") > 40 )); then
        tail -40 "$log" > "${log}.tmp" && mv "${log}.tmp" "$log"
    fi
}

# -------------------------------------------------------
# DEPENDENCY PRE-CHECK  (silent in --check mode)
# -------------------------------------------------------
for pkg in curl grep awk; do
    if ! command -v "$pkg" &>/dev/null; then
        [[ "$MODE" != "--check" ]] && echo -e "${yellow}📦 Installing missing dependency: $pkg${no_col}"
        sudo apt-get install -y "$pkg" >/dev/null 2>&1
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
    [[ "$MODE" == "--check" ]] && exit 0   # Silent skip on login
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
#
#  Zero blocking work — read from disk only.
#  If cache is stale, fire a background refresh for next time.
# ═══════════════════════════════════════════════════════
if [[ "$MODE" == "--check" ]]; then

    # Trigger background refresh if stale (non-blocking — login doesn't wait)
    if ! cache_is_fresh "$LAST_NET_SYNC"; then
        spawn_background_refresh
    fi

    # No cache yet (very first run) — background job just fired, nothing to show
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

    # Show any pending security alerts from cached apt simulate output
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
# ═══════════════════════════════════════════════════════

echo -ne "${yellow}🔄 Synchronising with package repositories...${no_col}"
sudo apt-get update -qq 2>/dev/null
echo -ne "\r\033[K"

echo -ne "${yellow}🔍 Checking upstream versions...${no_col}"

LATEST_DOCKER=$(fetch_latest_github_tag "moby/moby" \
    "$DOCKER_VER_FILE" "$DOCKER_ETAG_FILE") || {
    echo -e "\n${red}❌ Failed to retrieve Docker Engine upstream version.${no_col}"
    exit 1
}
LATEST_COMPOSE=$(fetch_latest_github_tag "docker/compose" \
    "$COMPOSE_VER_FILE" "$COMPOSE_ETAG_FILE") || {
    echo -e "\n${red}❌ Failed to retrieve Docker Compose upstream version.${no_col}"
    exit 1
}

echo -ne "\r\033[K"

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
            echo -e "${yellow}🔄 Updating Docker Compose to v${LATEST_COMPOSE}...${no_col}"
            sudo apt-get install -y --with-new-pkgs docker-compose-plugin \
                && echo -e "${green}✅ Docker Compose updated.${no_col}" \
                || echo -e "${red}❌ Docker Compose update failed. Check apt logs.${no_col}"
        fi
        if [[ "$DOCKER_UPDATE" == "newer" ]]; then
            echo -e "${yellow}🔄 Updating Docker Engine to v${LATEST_DOCKER}...${no_col}"
            sudo apt-get install -y --with-new-pkgs docker-ce docker-ce-cli containerd.io \
                && echo -e "${green}✅ Docker Engine updated.${no_col}" \
                || echo -e "${red}❌ Docker Engine update failed. Check apt logs.${no_col}"
            echo -e "${yellow}🔄 Restarting Docker service...${no_col}"
            sudo systemctl restart docker \
                && echo -e "${green}✅ Docker service restarted.${no_col}" \
                || echo -e "${red}❌ Restart failed. Try: sudo systemctl restart docker${no_col}"
        fi
        # Bust cache so next login reflects the freshly installed versions
        rm -f "$DOCKER_VER_FILE" "$COMPOSE_VER_FILE" \
              "$DOCKER_ETAG_FILE" "$COMPOSE_ETAG_FILE" \
              "$LAST_NET_SYNC"
    fi
else
    echo -e "${green}✅ Docker Engine (v${CURRENT_DOCKER}) and Docker Compose (v${CURRENT_COMPOSE}) are up to date. 🐋${no_col}"
fi

# ---- Live security / SSL library check ----
CORE_DEPS=$(apt-get --simulate upgrade 2>/dev/null \
    | grep -E '^Inst (libssl|openssl|libtiff|libc6|ca-certificates|libseccomp2)' \
    | awk '{print $2}')

# Persist result so --check can use it without running apt-simulate itself
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
