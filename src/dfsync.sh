#!/bin/bash
# dfsync - Dotfile Sync to Gist
# v3.9 - Recursive Discovery + Restored Verbose/Debug Logic

set -e

# --- Constants ---
KEYCHAIN_SERVICE="dotfilesync"
KEYCHAIN_ACCOUNT="github_token"
CONFIG_POINTER="${HOME}/.dfsyncrc"
DEFAULT_CONFIG_PATH="${HOME}/.config/dfsync.json"
LINUX_TOKEN_FILE="${HOME}/.dfsync_token"

# --- Globals ---
YES_MODE=false
VERBOSE_MODE=false
OS_TYPE="$(uname -s)"

# --- Crash Trap ---
trap '[[ $? -ne 0 ]] && echo -e "\n\033[0;31m[CRASH] Script aborted on line $LINENO.\033[0m"' EXIT

# --- Helpers ---
log() { echo -e "\033[0;34m[dfsync]\033[0m $1"; }
success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; exit 1; }
warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }

debug() { 
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "\033[0;90m[DEBUG] $1\033[0m"
    fi
    return 0
}

confirm() {
    local prompt="$1"
    if [[ "$YES_MODE" == "true" ]]; then return 0; fi
    local response
    read -p "$prompt [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then return 0; else return 1; fi
}

check_deps() {
    command -v jq >/dev/null 2>&1 || error "jq is required."
    if [[ "$OS_TYPE" == "Linux" ]]; then
        command -v curl >/dev/null 2>&1 || error "curl is required."
    fi
}

# --- Credential Management ---

credential_get() {
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null; then return 0; fi
        if security find-generic-password -s "dfsync_github_token" -a "github_api" -w 2>/dev/null; then
            local old_token=$(security find-generic-password -s "dfsync_github_token" -a "github_api" -w)
            credential_save "$old_token"
            echo "$old_token"
            return 0
        fi
        return 1
    else
        [[ -f "$LINUX_TOKEN_FILE" ]] && cat "$LINUX_TOKEN_FILE" && return 0
        return 1
    fi
}

credential_save() {
    local token="$1"
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w "$token"
    else
        echo "$token" > "$LINUX_TOKEN_FILE"
        chmod 600 "$LINUX_TOKEN_FILE"
    fi
}

# --- Core Functions ---

get_config_path() {
    if [[ ! -f "$CONFIG_POINTER" ]]; then
        error "dfsync is not configured. Run 'dfsync setup' first."
    fi
    cat "$CONFIG_POINTER"
}

get_token() {
    if ! credential_get; then
        error "GitHub Token not found. Run 'dfsync setup' or 'dfsync config token'."
    fi
}

ensure_valid_config() {
    local config_file="$1"
    if [[ ! -s "$config_file" ]]; then
        debug "File is empty. Initializing..."
        echo '{"gist_id": "", "files": []}' > "$config_file"
        return
    fi

    local check_file=$(mktemp)
    set +e
    jq empty "$config_file" > "$check_file" 2>&1
    local status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        local err_msg=$(cat "$check_file")
        rm "$check_file"
        error "Config file is corrupted (Invalid JSON):\n$err_msg"
    fi
    rm "$check_file"

    local fix_file=$(mktemp)
    set +e
    jq 'if type=="array" then {files: ., gist_id: ""} elif (.files == null and .dotFilePaths == null) then .files = [] else . end' "$config_file" > "$fix_file"
    status=$?
    set -e
    
    if [[ $status -eq 0 ]]; then
        mv "$fix_file" "$config_file"
    else
        rm "$fix_file"
        error "Config repair failed."
    fi
}

# --- Commands ---

cmd_help() {
    echo -e "Usage: dfsync [COMMAND] [OPTIONS]"
    echo -e "\nCommands:"
    echo -e "  setup            Initialize dfsync."
    echo -e "  track <file>     Add a file to the sync list."
    echo -e "  untrack <file>   Remove a file from the sync list."
    echo -e "  push             Upload all tracked files to Gist."
    echo -e "  pull             Download files from Gist."
    echo -e "  config token     Update GitHub Token."
    echo -e "  config path      Change config file location."
    echo -e "  help             Show this guide."
    echo -e "\nOptions:"
    echo -e "  -y, --yes        Auto-confirm all prompts (Batch Mode)."
    echo -e "  -v, --verbose    Show detailed debug logs."
}

cmd_setup() {
    echo "--- dfsync Setup ($OS_TYPE) ---"
    local default_path="$DEFAULT_CONFIG_PATH"
    [[ -f "$CONFIG_POINTER" ]] && default_path=$(cat "$CONFIG_POINTER")
    local config_path=""
    
    if [[ "$YES_MODE" == "true" ]]; then
        config_path="$default_path"
        log "Auto-accepting config path: $config_path"
    else
        read -p "Enter path for config file [$default_path]: " input_path
        config_path=${input_path:-$default_path}
    fi
    
    config_path="${config_path/#\~/$HOME}"
    mkdir -p "$(dirname "$config_path")"
    echo "$config_path" > "$CONFIG_POINTER"
    success "Config path set to: $config_path"
    
    if [[ ! -f "$config_path" ]]; then
        echo '{"gist_id": "", "files": []}' > "$config_path"
        success "Created empty config file."
    fi

    if credential_get >/dev/null; then
        [[ "$YES_MODE" != "true" ]] && log "Existing token found."
    else
        read -s -p "Enter GitHub Access Token (gist scope): " token
        echo ""
        [[ -n "$token" ]] && credential_save "$token" && success "Token saved." || warn "No token entered."
    fi

    ensure_valid_config "$config_path"
    local current_gist_id=$(jq -r '.gist_id // .gistId // empty' "$config_path")

    if [[ -n "$current_gist_id" ]]; then
        [[ "$YES_MODE" != "true" ]] && log "Existing Gist ID found: $current_gist_id"
    else
        if [[ "$YES_MODE" != "true" ]]; then
            local input_gist_id
            echo -e "\nRestore: Do you have an existing Gist ID?"
            read -p "Enter Gist ID (Leave empty to create new on push): " input_gist_id
            if [[ -n "$input_gist_id" ]]; then
                local tmp=$(mktemp)
                jq --arg id "$input_gist_id" '.gist_id = $id' "$config_path" > "$tmp" && mv "$tmp" "$config_path"
                success "Gist ID saved."
            fi
        fi
    fi
}

cmd_config_token() {
    local token="$1"
    [[ -z "$token" ]] && read -s -p "Enter new GitHub Access Token: " token && echo ""
    [[ -z "$token" ]] && error "Token cannot be empty."
    credential_save "$token"
    success "Token updated."
}

cmd_config_path() {
    local path="$1"
    [[ -z "$path" ]] && error "Usage: dfsync config path <absolute_path>"
    path="${path/#\~/$HOME}"
    echo "$path" > "$CONFIG_POINTER"
    success "Config path updated to: $path"
}

cmd_track() {
    check_deps
    local path="$1"
    [[ -z "$path" ]] && error "Usage: dfsync track <path_to_file_or_dir>"
    
    if [[ -d "$path" ]]; then
        log "Directory detected. Scanning: $(echo "$path" | sed "s|$HOME|~|")"
        find "$path" -type f -not -path '*/.*' -not -name ".DS_Store" | while read -r subfile; do
            "$0" track "$subfile"
        done
        return
    fi

    local config_file=$(get_config_path)
    ensure_valid_config "$config_file"
    local clean_path="${path/$HOME/\~}"
    local tmp=$(mktemp)
    
    debug "Tracking file: $clean_path"

    set +e
    jq --arg f "$clean_path" '
        (if type == "array" then {files: ., gist_id: ""} else . end)
        | .files |= (if . == null then [] else . end | . + [$f] | unique)
    ' "$config_file" > "$tmp"
    local status=$?
    set -e

    if [[ $status -eq 0 ]]; then
        mv "$tmp" "$config_file"
        success "Now tracking: $clean_path"
    else
        rm -f "$tmp"
        error "Failed to update config."
    fi
}

cmd_untrack() {
    check_deps
    local path="$1"
    [[ -z "$path" ]] && error "Usage: dfsync untrack <path>"
    local config_file=$(get_config_path)
    ensure_valid_config "$config_file"
    local clean_path="${path/$HOME/\~}"
    local tmp=$(mktemp)
    
    set +e
    jq --arg f "$clean_path" '
        (if type == "array" then {files: ., gist_id: ""} else . end)
        | .files |= (if . == null then [] else map(select(. != $f)) end)
    ' "$config_file" > "$tmp"
    local status=$?
    set -e

    if [[ $status -eq 0 ]]; then
        mv "$tmp" "$config_file"
        success "No longer tracking: $clean_path"
    else
        rm -f "$tmp"
        error "Failed to update config."
    fi
}

cmd_push() {
    local config_file=$(get_config_path)
    ensure_valid_config "$config_file"
    local token=$(get_token)
    
    log "Reading config from $config_file..."
    local count_file=$(mktemp)
    set +e
    jq '(.files // .dotFilePaths // []) | length' "$config_file" > "$count_file" 2>&1
    local jq_status=$?
    set -e

    if [[ $jq_status -ne 0 ]]; then error "jq failed to read file list."; fi
    
    local file_count; read -r file_count < "$count_file"; rm "$count_file"
    debug "Found $file_count tracked files."
    
    if [[ "$file_count" == "0" ]]; then
        warn "No files to sync. Use 'dfsync track <file>'."
        return 0
    fi
    
    local gist_id=$(jq -r '.gist_id // .gistId // empty' "$config_file" || echo "")
    local payload_file=$(mktemp)
    echo '{ "description": "dfsync backup", "files": {} }' > "$payload_file"
    
    log "Preparing upload..."
    local list_file=$(mktemp)
    set +e
    jq -r '(.files // .dotFilePaths // [])[]' "$config_file" > "$list_file"
    set -e

    local TARGET_FILES=()
    while IFS= read -r line; do TARGET_FILES+=("$line"); done < "$list_file"; rm "$list_file"

    local files_packed=0
    for filepath in "${TARGET_FILES[@]}"; do
        local abs_path="${filepath/#\~/$HOME}"
        local flat_name=$(echo "$filepath" | sed 's/^~\///' | sed 's/\//__/g')
        
        if [[ -f "$abs_path" ]]; then
            if confirm "Upload $filepath?"; then
                debug "Processing: $filepath"
                [[ "$VERBOSE_MODE" != "true" ]] && echo -n "."
                
                local content_file=$(mktemp)
                set +e
                jq -Rs . < "$abs_path" > "$content_file"
                local read_status=$?
                set -e

                if [[ $read_status -eq 0 ]]; then
                    local tmp_payload=$(mktemp)
                    set +e
                    jq --arg fn "$flat_name" --slurpfile c "$content_file" '.files[$fn] = {content: $c[0]}' "$payload_file" > "$tmp_payload"
                    local update_status=$?
                    set -e
                    if [[ $update_status -eq 0 ]]; then
                        mv "$tmp_payload" "$payload_file"
                        ((files_packed++))
                    else
                        rm "$tmp_payload"
                    fi
                fi
                rm "$content_file"
            else
                debug "Skipping: $filepath"
            fi
        else
            warn "File not found (skipping): $abs_path"
        fi
    done

    [[ "$VERBOSE_MODE" != "true" ]] && echo ""
    
    if [[ $files_packed -eq 0 ]]; then
        log "No files selected. Aborting."; rm "$payload_file"; return 0
    fi

    log "Uploading $files_packed files..."
    local response_body=$(mktemp)
    local http_code
    
    set +e
    if [[ -z "$gist_id" ]]; then
        http_code=$(curl -s -w "%{http_code}" -o "$response_body" -H "Authorization: token $token" -X POST -d @"$payload_file" "https://api.github.com/gists")
    else
        http_code=$(curl -s -w "%{http_code}" -o "$response_body" -H "Authorization: token $token" -X PATCH -d @"$payload_file" "https://api.github.com/gists/$gist_id")
    fi
    set -e
    
    if [[ "$http_code" == "201" ]] || [[ "$http_code" == "200" ]]; then
        if [[ -z "$gist_id" ]]; then
            local new_id=$(jq -r '.id' "$response_body")
            local tmp=$(mktemp)
            jq --arg id "$new_id" '.gist_id = $id' "$config_file" > "$tmp" && mv "$tmp" "$config_file"
            success "Created new Gist: $new_id"
        else
            success "Gist $gist_id updated."
        fi
    else
        error "GitHub API Error ($http_code). Response: $(cat "$response_body")"
    fi
    rm -f "$payload_file" "$response_body"
}

cmd_pull() {
    local config_file=$(get_config_path)
    ensure_valid_config "$config_file"
    local token=$(get_token)
    local gist_id=$(jq -r '.gist_id // .gistId // empty' "$config_file")
    
    [[ -z "$gist_id" ]] && error "No Gist ID found."
    log "Fetching Gist $gist_id..."
    
    local response_body=$(mktemp)
    local http_code
    set +e
    http_code=$(curl -s -w "%{http_code}" -o "$response_body" -H "Authorization: token $token" "https://api.github.com/gists/$gist_id")
    set -e
    
    if [[ "$http_code" != "200" ]]; then error "Failed to fetch Gist ($http_code)."; fi
    
    log "Restoring files..."
    local list_file=$(mktemp)
    jq -r '(.files // .dotFilePaths // [])[]' "$config_file" > "$list_file"

    local TARGET_FILES=()
    while IFS= read -r line; do TARGET_FILES+=("$line"); done < "$list_file"; rm "$list_file"

    for filepath in "${TARGET_FILES[@]}"; do
        local abs_path="${filepath/#\~/$HOME}"
        local flat_name=$(echo "$filepath" | sed 's/^~\///' | sed 's/\//__/g')
        local content=$(jq -r --arg fn "$flat_name" '.files[$fn].content // empty' "$response_body")
        
        if [[ -n "$content" ]]; then
            if confirm "Overwrite $filepath?"; then
                debug "Restoring: $flat_name -> $abs_path"
                mkdir -p "$(dirname "$abs_path")"
                echo "$content" > "$abs_path"
                success "Restored: $filepath"
            else
                debug "Skipped: $filepath"
            fi
        fi
    done
    rm -f "$response_body"
}

# --- Router ---
ARGS=()
for arg in "$@"; do
    case $arg in
        -y|--yes) YES_MODE=true ;;
        -v|--verbose) VERBOSE_MODE=true ;;
        *) ARGS+=("$arg") ;;
    esac
done

[[ ${#ARGS[@]} -eq 0 ]] && cmd_help && exit 0

COMMAND="${ARGS[0]}"
shift
ARG_1="${ARGS[1]}"

case "$COMMAND" in
    setup) cmd_setup ;;
    config)
        case "$ARG_1" in
            token) cmd_config_token "${ARGS[2]}" ;;
            path) cmd_config_path "${ARGS[2]}" ;;
            *) error "Unknown config command." ;;
        esac
        ;;
    track) cmd_track "$ARG_1" ;;
    untrack) cmd_untrack "$ARG_1" ;;
    push) cmd_push ;;
    pull) cmd_pull ;;
    help|*) cmd_help ;;
esac
