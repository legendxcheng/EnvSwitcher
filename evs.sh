#!/bin/bash
# ============================================================================
# EnvVarSwitcher (evs) - Bash Environment Variable Switcher
#
# Usage: source evs.sh <command> [arguments]
#        Or after installation: evs <command> [arguments]
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration
# ============================================================================

# Determine script directory (handle both direct source and function call)
_evs_get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    # Resolve symlinks and get absolute path
    while [[ -L "$source" ]]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

_evs_is_wsl() {
    grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null
}

# Try to detect script directory; if unavailable, fall back to local config.
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "main" ]]; then
    EVS_SCRIPT_DIR="$(_evs_get_script_dir 2>/dev/null)"
fi
if [[ -z "$EVS_SCRIPT_DIR" ]] || [[ ! -d "$EVS_SCRIPT_DIR" ]]; then
    EVS_SCRIPT_DIR="$HOME/.config/evs"
fi

# Profiles directory (prefer local, then script path, then WSL shared mount).
EVS_LOCAL_PROFILES="$HOME/.config/evs/profiles"
EVS_SCRIPT_PROFILES="$EVS_SCRIPT_DIR/profiles"
EVS_WSL_SHARED_PROFILES="${EVS_WSL_SHARED_PROFILES:-/mnt/e/EnvVarSwitcher/profiles}"

if [[ -d "$EVS_LOCAL_PROFILES" ]] && [[ -n "$(ls -A "$EVS_LOCAL_PROFILES" 2>/dev/null)" ]]; then
    EVS_PROFILES_DIR="$EVS_LOCAL_PROFILES"
elif [[ -d "$EVS_SCRIPT_PROFILES" ]]; then
    EVS_PROFILES_DIR="$EVS_SCRIPT_PROFILES"
elif _evs_is_wsl && [[ -d "$EVS_WSL_SHARED_PROFILES" ]]; then
    EVS_PROFILES_DIR="$EVS_WSL_SHARED_PROFILES"
else
    EVS_PROFILES_DIR="$EVS_LOCAL_PROFILES"
fi

# Tracking variables
EVS_TRACKED_VARS_KEY="EVS_TRACKED_VARS"
EVS_ACTIVE_PROFILE_KEY="EVS_ACTIVE_PROFILE"

# ============================================================================
# Helper Functions
# ============================================================================

_evs_check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        echo ""
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt install jq"
        echo "  Alpine:        apk add jq"
        echo "  macOS:         brew install jq"
        return 1
    fi
    return 0
}

_evs_get_profile_path() {
    local name="$1"
    echo "$EVS_PROFILES_DIR/$name.json"
}

_evs_profile_exists() {
    local name="$1"
    local path="$(_evs_get_profile_path "$name")"
    [[ -f "$path" ]]
}

_evs_get_tracked_vars() {
    local tracked="${!EVS_TRACKED_VARS_KEY}"
    if [[ -n "$tracked" ]]; then
        echo "$tracked" | tr ',' '\n'
    fi
}

_evs_set_tracked_vars() {
    local vars="$1"
    export "$EVS_TRACKED_VARS_KEY=$vars"
}

_evs_add_tracked_var() {
    local var="$1"
    local current="${!EVS_TRACKED_VARS_KEY}"
    if [[ -z "$current" ]]; then
        export "$EVS_TRACKED_VARS_KEY=$var"
    elif [[ ! ",$current," == *",$var,"* ]]; then
        export "$EVS_TRACKED_VARS_KEY=$current,$var"
    fi
}

_evs_is_codex_profile() {
    local name="$1"
    local dir_path="$EVS_PROFILES_DIR/$name"
    [[ -d "$dir_path" ]]
}

_evs_get_codex_profile_path() {
    local name="$1"
    echo "$EVS_PROFILES_DIR/$name"
}

_evs_apply_codex_config() {
    local profile_name="$1"
    local profile_path="$(_evs_get_codex_profile_path "$profile_name")"
    local config_file="$profile_path/config.toml"
    local auth_file="$profile_path/auth.json"

    # Validate files exist
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}Missing config.toml in profile '$profile_name'${NC}"
        return 1
    fi

    if [[ ! -f "$auth_file" ]]; then
        echo -e "${RED}Missing auth.json in profile '$profile_name'${NC}"
        return 1
    fi

    # Ensure ~/.codex directory exists
    local codex_dir="$HOME/.codex"
    mkdir -p "$codex_dir"

    # Copy files
    if ! cp "$config_file" "$codex_dir/config.toml" 2>/dev/null; then
        echo -e "${RED}Failed to copy config files.${NC}"
        echo -e "${YELLOW}Check permissions for $codex_dir directory${NC}"
        return 1
    fi

    if ! cp "$auth_file" "$codex_dir/auth.json" 2>/dev/null; then
        echo -e "${RED}Failed to copy config files.${NC}"
        echo -e "${YELLOW}Check permissions for $codex_dir directory${NC}"
        return 1
    fi

    return 0
}

_evs_mask_value() {
    local value="$1"
    local len=${#value}

    if [[ $len -le 0 ]]; then
        echo ""
        return
    fi

    if [[ $len -le 4 ]]; then
        # Too short, mask entirely
        printf '%*s' "$len" '' | tr ' ' '*'
    elif [[ $len -le 8 ]]; then
        # Short value: show first 1 and last 1
        local first="${value:0:1}"
        local last="${value: -1}"
        local mask_len=$((len - 2))
        local mask=$(printf '%*s' "$mask_len" '' | tr ' ' '*')
        echo "${first}${mask}${last}"
    else
        # Normal value: show first 2 and last 3
        local first="${value:0:2}"
        local last="${value: -3}"
        local mask_len=$((len - 5))
        local mask=$(printf '%*s' "$mask_len" '' | tr ' ' '*')
        echo "${first}${mask}${last}"
    fi
}

# ============================================================================
# Command: Help
# ============================================================================

_evs_help() {
    cat << 'EOF'

  EnvVarSwitcher (evs) - Environment Variable Switcher (Bash)

  USAGE:
    evs <command> [arguments]

  COMMANDS:
    list, ls              List all available profiles
    use, switch <name>    Switch to specified profile
    show [name]           Show current state or preview a profile
    clear                 Clear all variables set by current profile
    add <name>            Create a new profile interactively
    edit <name>           Open profile in default editor
    remove, rm <name>     Delete a profile

  EXAMPLES:
    evs list              # List all profiles
    evs use dev           # Switch to 'dev' profile
    evs show              # Show current active variables
    evs show prod         # Preview 'prod' profile
    evs clear             # Clear current session variables
    evs add staging       # Create new 'staging' profile
    evs edit dev          # Edit 'dev' profile

  PROFILE LOCATION:
EOF
    echo "    $EVS_PROFILES_DIR"
    echo ""
}

# ============================================================================
# Command: List
# ============================================================================

_evs_list() {
    _evs_check_jq || return 1

    if [[ ! -d "$EVS_PROFILES_DIR" ]]; then
        echo -e "${YELLOW}No profiles directory found.${NC}"
        echo "Expected: $EVS_PROFILES_DIR"
        return 1
    fi

    local active="${!EVS_ACTIVE_PROFILE_KEY}"

    echo ""
    echo "Available profiles:"
    echo ""

    local has_profiles=false

    # List JSON profiles (environment variables)
    for f in "$EVS_PROFILES_DIR"/*.json; do
        if [[ -f "$f" ]]; then
            has_profiles=true
            local filename=$(basename "$f" .json)
            local description=$(jq -r '.description // empty' "$f" 2>/dev/null)

            local marker=" "
            local color=""
            if [[ "$filename" == "$active" ]]; then
                marker="*"
                color="$GREEN"
            fi

            printf "  %s ${color}%-15s${NC} [env]  " "$marker" "$filename"
            if [[ -n "$description" ]]; then
                echo -e " ${GRAY}- $description${NC}"
            else
                echo ""
            fi
        fi
    done

    # List directory profiles (codex configurations)
    for d in "$EVS_PROFILES_DIR"/*; do
        if [[ -d "$d" ]]; then
            local dirname=$(basename "$d")
            local config_file="$d/config.toml"
            local auth_file="$d/auth.json"

            # Only list if both required files exist
            if [[ -f "$config_file" ]] && [[ -f "$auth_file" ]]; then
                has_profiles=true

                local marker=" "
                local color=""
                if [[ "$dirname" == "$active" ]]; then
                    marker="*"
                    color="$GREEN"
                fi

                printf "  %s ${color}%-15s${NC} [codex]" "$marker" "$dirname"
                echo -e " ${GRAY}- Codex configuration${NC}"
            fi
        fi
    done

    if [[ "$has_profiles" == "false" ]]; then
        echo -e "${YELLOW}No profiles found.${NC}"
        echo "Create one with: evs add <name>"
        echo ""
        return 0
    fi

    echo ""
    echo -e "  ${GRAY}* = active profile${NC}"
    echo ""
}

# ============================================================================
# Command: Use
# ============================================================================

_evs_use() {
    local profile_name="$1"

    if [[ -z "$profile_name" ]]; then
        echo -e "${RED}Usage: evs use <profile-name>${NC}"
        return 1
    fi

    _evs_check_jq || return 1

    local profile_path="$(_evs_get_profile_path "$profile_name")"

    if [[ ! -f "$profile_path" ]]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        echo "Run 'evs list' to see available profiles."
        return 1
    fi

    # Clear previous variables first
    _evs_clear --silent

    # Read and set variables
    local var_count=0
    local var_names=""

    while IFS='=' read -r key value; do
        if [[ -n "$key" ]]; then
            export "$key=$value"
            if [[ -z "$var_names" ]]; then
                var_names="$key"
            else
                var_names="$var_names,$key"
            fi
            ((var_count++))
        fi
    done < <(jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$profile_path" 2>/dev/null)

    # Track variables
    _evs_set_tracked_vars "$var_names"
    export "$EVS_ACTIVE_PROFILE_KEY=$profile_name"

    # Output
    echo ""
    echo -e "${GREEN}✓ Switched to '$profile_name'${NC}"
    echo ""

    if [[ $var_count -gt 0 ]]; then
        echo "  Set $var_count variable(s):"
        while IFS='=' read -r key value; do
            if [[ -n "$key" ]]; then
                local masked=$(_evs_mask_value "$value")
                echo -e "    ${CYAN}$key${NC} = $masked"
            fi
        done < <(jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$profile_path" 2>/dev/null)
    fi

    echo ""
}

# ============================================================================
# Command: Show
# ============================================================================

_evs_show() {
    local profile_name="$1"

    _evs_check_jq || return 1

    echo ""

    # If profile name given, preview that profile
    if [[ -n "$profile_name" ]]; then
        local profile_path="$(_evs_get_profile_path "$profile_name")"

        if [[ ! -f "$profile_path" ]]; then
            echo -e "${RED}Profile '$profile_name' not found.${NC}"
            return 1
        fi

        echo -n "Profile: "
        echo -e "${CYAN}$profile_name${NC}"

        local description=$(jq -r '.description // empty' "$profile_path" 2>/dev/null)
        if [[ -n "$description" ]]; then
            echo -e "  ${GRAY}$description${NC}"
        fi

        echo ""
        echo "Variables:"

        local has_vars=false
        while IFS='=' read -r key value; do
            if [[ -n "$key" ]]; then
                local masked=$(_evs_mask_value "$value")
                echo -e "    ${CYAN}$key${NC} = $masked"
                has_vars=true
            fi
        done < <(jq -r '.variables | to_entries[] | "\(.key)=\(.value)"' "$profile_path" 2>/dev/null)

        if [[ "$has_vars" == "false" ]]; then
            echo -e "  ${GRAY}(no variables defined)${NC}"
        fi

        echo ""
        return 0
    fi

    # Show current session state
    local active="${!EVS_ACTIVE_PROFILE_KEY}"

    if [[ -z "$active" ]]; then
        echo -e "${GRAY}No active profile.${NC}"
        echo "Use 'evs use <name>' to switch to a profile."
        echo ""
        return 0
    fi

    echo -n "Active profile: "
    echo -e "${GREEN}$active${NC}"
    echo ""

    local tracked_vars=$(_evs_get_tracked_vars)
    if [[ -n "$tracked_vars" ]]; then
        echo "Variables:"
        while IFS= read -r var_name; do
            if [[ -n "$var_name" ]]; then
                local value="${!var_name}"
                local masked=$(_evs_mask_value "$value")
                echo -e "    ${CYAN}$var_name${NC} = $masked"
            fi
        done <<< "$tracked_vars"
    else
        echo -e "  ${GRAY}(no variables set)${NC}"
    fi

    echo ""
}

# ============================================================================
# Command: Clear
# ============================================================================

_evs_clear() {
    local silent=false
    if [[ "$1" == "--silent" ]]; then
        silent=true
    fi

    local tracked_vars=$(_evs_get_tracked_vars)
    local active="${!EVS_ACTIVE_PROFILE_KEY}"
    local count=0

    # Clear each tracked variable
    while IFS= read -r var_name; do
        if [[ -n "$var_name" ]]; then
            unset "$var_name"
            ((count++))
        fi
    done <<< "$tracked_vars"

    # Clear tracking variables
    unset "$EVS_TRACKED_VARS_KEY"
    unset "$EVS_ACTIVE_PROFILE_KEY"

    if [[ "$silent" == "false" ]]; then
        echo ""
        if [[ $count -gt 0 ]]; then
            echo -e "${GREEN}✓ Cleared $count variable(s) from session.${NC}"
        else
            echo -e "${GRAY}No variables to clear.${NC}"
        fi
        echo ""
    fi
}

# ============================================================================
# Command: Add
# ============================================================================

_evs_add() {
    local profile_name="$1"

    if [[ -z "$profile_name" ]]; then
        echo -e "${RED}Usage: evs add <profile-name>${NC}"
        return 1
    fi

    # Validate name
    if [[ ! "$profile_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Invalid profile name. Use only letters, numbers, underscore, and hyphen.${NC}"
        return 1
    fi

    local profile_path="$(_evs_get_profile_path "$profile_name")"

    if [[ -f "$profile_path" ]]; then
        echo -e "${RED}Profile '$profile_name' already exists.${NC}"
        echo "Use 'evs edit $profile_name' to modify it."
        return 1
    fi

    # Ensure profiles directory exists
    mkdir -p "$EVS_PROFILES_DIR"

    echo ""
    echo -n "Creating new profile: "
    echo -e "${CYAN}$profile_name${NC}"
    echo ""

    # Get description
    read -p "Description (optional): " description

    # Get variables
    echo ""
    echo "Enter variables (empty name to finish):"
    echo ""

    local variables=""
    local first=true

    while true; do
        read -p "  Variable name: " var_name
        if [[ -z "$var_name" ]]; then
            break
        fi

        read -p "  Value for '$var_name': " var_value

        if [[ "$first" == "true" ]]; then
            variables="\"$var_name\": \"$var_value\""
            first=false
        else
            variables="$variables,
    \"$var_name\": \"$var_value\""
        fi

        echo ""
    done

    # Create JSON
    cat > "$profile_path" << EOF
{
  "name": "$profile_name",
  "description": "$description",
  "variables": {
    $variables
  }
}
EOF

    echo ""
    echo -e "${GREEN}✓ Profile '$profile_name' created successfully.${NC}"
    echo "  Location: $profile_path"
    echo ""
    echo "Use 'evs use $profile_name' to activate it."
    echo ""
}

# ============================================================================
# Command: Edit
# ============================================================================

_evs_edit() {
    local profile_name="$1"

    if [[ -z "$profile_name" ]]; then
        echo -e "${RED}Usage: evs edit <profile-name>${NC}"
        return 1
    fi

    local profile_path="$(_evs_get_profile_path "$profile_name")"

    if [[ ! -f "$profile_path" ]]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        echo "Run 'evs list' to see available profiles."
        return 1
    fi

    echo ""
    echo "Opening '$profile_name' in editor..."

    # Try editors in order of preference
    if [[ -n "$EDITOR" ]]; then
        $EDITOR "$profile_path"
    elif command -v code &> /dev/null; then
        code "$profile_path"
    elif command -v vim &> /dev/null; then
        vim "$profile_path"
    elif command -v nano &> /dev/null; then
        nano "$profile_path"
    elif command -v vi &> /dev/null; then
        vi "$profile_path"
    else
        echo -e "${RED}No editor found.${NC}"
        echo "Set \$EDITOR or install vim/nano."
        echo "File location: $profile_path"
        return 1
    fi
}

# ============================================================================
# Command: Remove
# ============================================================================

_evs_remove() {
    local profile_name="$1"

    if [[ -z "$profile_name" ]]; then
        echo -e "${RED}Usage: evs remove <profile-name>${NC}"
        return 1
    fi

    local profile_path="$(_evs_get_profile_path "$profile_name")"

    if [[ ! -f "$profile_path" ]]; then
        echo -e "${RED}Profile '$profile_name' not found.${NC}"
        return 1
    fi

    echo ""
    read -p "Are you sure you want to delete '$profile_name'? (y/N): " confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm -f "$profile_path"

        # Clear if this was the active profile
        local active="${!EVS_ACTIVE_PROFILE_KEY}"
        if [[ "$active" == "$profile_name" ]]; then
            _evs_clear --silent
        fi

        echo -e "${GREEN}✓ Profile '$profile_name' deleted.${NC}"
    else
        echo -e "${GRAY}Cancelled.${NC}"
    fi

    echo ""
}

# ============================================================================
# Main Entry Point
# ============================================================================

_evs_main() {
    local command="$1"
    shift

    case "$command" in
        list|ls)
            _evs_list
            ;;
        use|switch)
            _evs_use "$1"
            ;;
        show)
            _evs_show "$1"
            ;;
        clear)
            _evs_clear
            ;;
        add)
            _evs_add "$1"
            ;;
        edit)
            _evs_edit "$1"
            ;;
        remove|rm)
            _evs_remove "$1"
            ;;
        help|--help|-h|"")
            _evs_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo "Run 'evs help' for usage information."
            return 1
            ;;
    esac
}

# Run main function with all arguments
_evs_main "$@"
