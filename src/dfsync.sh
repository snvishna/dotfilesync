#!/usr/bin/env bash

# ==============================================================================
# Dotfilesync v5.0.0: Enterprise Grade
# ==============================================================================
# Design Principles:
# 1. Location Agnostic: Script handles symlinks and arbitrary install paths.
# 2. Config Resolution: ENV -> Pointer File -> Local Fallback.
# 3. Idempotency: Operations are safe to repeat.
# 4. Observability: Structured logging to stdout/stderr.
# ==============================================================================

set -o errexit  # Exit on error
set -o nounset  # Abort on unbound variable
set -o pipefail # Capture pipeline errors

# --- CONSTANTS ---
readonly VERSION="5.0.0"
readonly GITHUB_API="https://api.github.com"
readonly TMP_DIR=$(mktemp -d -t dfsync.XXXXXX)

# XDG Standard for state/config
readonly XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly STATE_DIR="${XDG_CONFIG_HOME}/dfsync"
readonly POINTER_FILE="${STATE_DIR}/active_config_path"

# Colors
readonly R='\033[0;31m'
readonly G='\033[0;32m'
readonly Y='\033[1;33m'
readonly B='\033[0;34m'
readonly C='\033[0;36m'
readonly NC='\033[0m'

# --- CLEANUP TRAP ---
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# --- LOGGING ---
log_info()  { printf "${B}[INFO]${NC} %s\n" "$1"; }
log_ok()    { printf "${G}[OK]${NC}   %s\n" "$1"; }
log_warn()  { printf "${Y}[WARN]${NC} %s\n" "$1" >&2; }
log_fatal() { printf "${R}[FATAL]${NC} %s\n" "$1" >&2; exit 1; }

# --- DYNAMIC CONFIG RESOLUTION ---
resolve_source() {
    # Robustly find where this script actually lives, resolving symlinks
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    echo "$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
}

get_config_path() {
    # Priority 1: Environment Variable
    if [[ -n "${DFSYNC_CONFIG:-}" ]]; then
        echo "$DFSYNC_CONFIG"
        return
    fi

    # Priority 2: User Pointer File (Managed via 'config' command)
    if [[ -f "$POINTER_FILE" ]]; then
        local ptr
        ptr=$(cat "$POINTER_FILE")
        if [[ -f "$ptr" ]]; then
            echo "$ptr"
            return
        fi
    fi

    # Priority 3: Local Fallback (Same dir as script)
    local script_dir
    script_dir=$(resolve_source)
    if [[ -f "${script_dir}/config.json" ]]; then
        echo "${script_dir}/config.json"
        return
    fi
    
    # Priority 4: XDG Default
    if [[ -f "${XDG_CONFIG_HOME}/dfsync.json" ]]; then
        echo "${XDG_CONFIG_HOME}/dfsync.json"
        return
    fi
    
    echo ""
}

# --- HELPERS ---
check_deps() {
    for cmd in jq curl; do command -v "$cmd" &>/dev/null || log_fatal "Missing dependency: $cmd"; done
}

get_os() { uname | tr '[:upper:]' '[:lower:]'; }

to_gist_name() {
    echo "$1" | sed "s|^~/||; s|/|.|g; s|^\.|__dot__|"
}

backup_file() {
    local file="$1"
    local suffix=".bak.$(date +%Y%m%d-%H%M%S)"
    [[ -f "$file" ]] && cp -p "$file" "${file}${suffix}" && log_info "Backup created: ${file##*/}${suffix}"
}

keychain_op() {
    local op="$1" user="$2" label="$3" pass="${4:-}"
    local os=$(get_os)
    if [[ "$os" == darwin* ]]; then
        case "$op" in
            add) security add-generic-password -a "$user" -s "$label" -w "$pass" -U ;;
            get) security find-generic-password -wga "$user" -s "$label" 2>/dev/null ;;
            del) security delete-generic-password -a "$user" -s "$label" ;;
        esac
    else
        command -v secret-tool &>/dev/null || log_fatal "Linux requires 'libsecret-tools'."
        case "$op" in
            add) echo "$pass" | secret-tool store --label "$label" user "$user" usage "$label" ;;
            get) secret-tool lookup user "$user" usage "$label" ;;
            del) secret-tool clear user "$user" usage "$label" ;;
        esac
    fi
}

github_api() {
    local method="$1" endpoint="$2" user="$3" token="$4" payload_file="${5:-}"
    local output_file="${TMP_DIR}/response.json"
    
    local args=(--silent --show-error --write-out "%{http_code}" --output "$output_file" --user "${user}:${token}" --request "$method" --header "Accept: application/vnd.github.v3+json" --connect-timeout 10 --retry 3 --retry-delay 1)
    [[ -n "$payload_file" ]] && args+=(--header "Content-Type: application/json" --data "@$payload_file")

    local status
    status=$(curl "${args[@]}" "${GITHUB_API}${endpoint}")

    if [[ "$status" -ge 200 && "$status" -lt 300 ]]; then
        cat "$output_file"
    else
        local err_msg
        err_msg=$(jq -r '.message // "Unknown Error"' "$output_file" 2>/dev/null)
        log_fatal "GitHub API Error ($status): $err_msg"
    fi
}

# --- COMMANDS ---

cmd_config() {
    local action="${1:-show}"
    local target="${2:-}"

    mkdir -p "$STATE_DIR"

    case "$action" in
        set|SET)
            [[ -z "$target" ]] && log_fatal "Usage: dfsync config set /path/to/config.json"
            # Resolve absolute path
            target=$(cd "$(dirname "$target")"; pwd)/$(basename "$target")
            if [[ ! -f "$target" ]]; then
                log_warn "File does not exist: $target (Pointer set anyway)"
            fi
            echo "$target" > "$POINTER_FILE"
            log_ok "Active config set to: $target"
            ;;
        show|SHOW)
            local current=$(get_config_path)
            if [[ -n "$current" ]]; then
                log_info "Active Config: $current"
                cat "$current" | jq 'del(.dotFilePaths)' # Show metadata only
            else
                log_warn "No active config found. (Search path: ENV -> POINTER -> LOCAL -> XDG)"
            fi
            ;;
        *)
            log_fatal "Unknown config action. Use 'set' or 'show'."
            ;;
    esac
}

cmd_push() {
    local auto_yes="${1:-}"
    local config_file
    config_file=$(get_config_path)

    [[ -z "$config_file" ]] && log_fatal "Config not found. Run 'dfsync config set <path>'."
    
    local config=$(cat "$config_file")
    local user=$(echo "$config" | jq -r ".githubUser")
    local gist_id=$(echo "$config" | jq -r ".gistId")
    local token=$(keychain_op get "$user" "dotfiles_sync")
    [[ -z "$token" ]] && log_fatal "No API token found for user: $user"

    log_info "Analyzing changes using config: $(basename "$config_file")"
    local payload_json="${TMP_DIR}/payload.json"
    echo '{ "files": {} }' > "$payload_json"
    local count=0

    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue
        local local_path="${filepath/#\~/$HOME}"
        local gist_name=$(to_gist_name "$filepath")

        if [[ "$auto_yes" != "-y" && "$auto_yes" != "--yes" ]]; then
            printf "${C}? Push ${filepath}?${NC} [y/N] "
            read -r confirm < /dev/tty
            [[ ! "$confirm" =~ ^[Yy] ]] && continue
        fi

        if [[ -f "$local_path" && -s "$local_path" ]]; then
            local temp_acc="${TMP_DIR}/acc.json"
            jq --arg fn "$gist_name" --rawfile content "$local_path" '.files += { ($fn): { "content": $content } }' "$payload_json" > "$temp_acc" && mv "$temp_acc" "$payload_json"
            ((count++))
            log_ok "Queued: $filepath"
        else
            log_warn "Skipped (Missing/Empty): $filepath"
        fi
    done < <(echo "$config" | jq -r '.dotFilePaths[]')

    [[ "$count" -eq 0 ]] && { log_warn "Nothing to sync."; return 0; }

    log_info "Uploading $count files..."
    github_api "PATCH" "/gists/$gist_id" "$user" "$token" "$payload_json" > /dev/null
    log_ok "Sync Complete."
}

cmd_pull() {
    local auto_yes="${1:-}"
    local config_file
    config_file=$(get_config_path)

    [[ -z "$config_file" ]] && log_fatal "Config not found."

    local config=$(cat "$config_file")
    local user=$(echo "$config" | jq -r ".githubUser")
    local gist_id=$(echo "$config" | jq -r ".gistId")
    local token=$(keychain_op get "$user" "dotfiles_sync")

    log_info "Fetching Gist..."
    local resp
    resp=$(github_api "GET" "/gists/$gist_id" "$user" "$token")
    local count=0

    while IFS= read -r filepath; do
        local local_path="${filepath/#\~/$HOME}"
        local gist_name=$(to_gist_name "$filepath")
        local content
        content=$(echo "$resp" | jq -r ".files[\"$gist_name\"].content // empty")

        if [[ -n "$content" ]]; then
            if [[ -f "$local_path" && "$auto_yes" != "-y" && "$auto_yes" != "--yes" ]]; then
                printf "${Y}! Overwrite ${filepath}?${NC} [y/N] "
                read -r confirm < /dev/tty
                [[ ! "$confirm" =~ ^[Yy] ]] && continue
            fi
            mkdir -p "$(dirname "$local_path")"
            backup_file "$local_path"
            echo "$content" > "$local_path"
            log_ok "Restored: $filepath"
            ((count++))
        fi
    done < <(echo "$config" | jq -r '.dotFilePaths[]')
    log_info "Restored $count files."
}

# --- ENTRY POINT ---
check_deps
case "${1:-}" in
    push|PUSH)   cmd_push "${2:-}" ;;
    pull|PULL)   cmd_pull "${2:-}" ;;
    config|CONFIG) cmd_config "${2:-}" "${3:-}" ;;
    *) echo "Usage: dfsync {push|pull} [-y] OR dfsync config {set|show}"; exit 1 ;;
esac
