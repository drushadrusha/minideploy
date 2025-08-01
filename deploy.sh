#!/bin/bash

default_path="https://raw.githubusercontent.com/drushadrusha/minideploy/refs/heads/master/recipes/"

check_dependencies() {
    for cmd in curl awk ssh sshpass jq; do
        command -v "$cmd" >/dev/null || { echo "Error: $cmd is not found. Please install." >&2; return 1; }
    done
}

parse_host_info() {
    local input="$1"
    local user="root" host="" port="22"
    [[ "$input" =~ ^([^@]+)@(.+)$ ]] && { user="${BASH_REMATCH[1]}"; input="${BASH_REMATCH[2]}"; }
    [[ "$input" =~ ^(.+):([0-9]+)$ ]] && { host="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[2]}"; } || host="$input"
    echo "$user@$host:$port"
}

parse_meta() {
    local file="$1"
    [[ -f "$file" ]] || { echo "Temporary script file is not found." >&2; return 1; }
    awk '
        BEGIN { meta = 0 }
        /^# minideploy meta/ { meta = 1; next }
        /^# end/ { exit }
        meta && /^# *name:/ {
            sub(/^# *name:[ \t]*/, "", $0)
            name = $0
        }
        meta && /^# *description:/ {
            sub(/^# *description:[ \t]*/, "", $0)
            description = $0
        }
        END {
            if (name != "") printf "name=\"%s\"\n", name
            if (description != "") printf "description=\"%s\"\n", description
        }
    ' "$file"
}

download_script() {
    local recipe_name="$1"
    local temp_file
    temp_file=$(mktemp)
    local local_recipe="$HOME/.minideploy/${recipe_name}.sh"
    # First check for local recipe in $HOME/.minideploy
    if [[ -f "$local_recipe" ]]; then
        cp "$local_recipe" "$temp_file"
        echo "$temp_file"
    else
        # If not found locally, try to download from GitHub
        local url="${default_path}${recipe_name}.sh"
        if curl -s -f "$url" -o "$temp_file"; then
            echo "$temp_file"
        else
            echo "Cannot load $recipe_name or it not exist." >&2
            rm -f "$temp_file"
            return 1
        fi
    fi
}

display_metadata() {
    local file="$1"
    local metadata
    metadata=$(parse_meta "$file")
    if [[ -n "$metadata" ]]; then
        local name description
        eval "$metadata"
        echo -e "\033[1;34m📦 $name\033[0m"
        echo -e "\033[1;34m📄 $description\033[0m"
    else
        echo -e "\033[1;34m📦$file\033[0m"
    fi
}

format_json() {
    local json="$1"
    echo "$json" | sed 's/,/,\n  /g' | sed 's/{/{\n  /' | sed 's/}/\n}/' | sed 's/"/"/g'
}

parse_json_output() {
    local output="$1"
    local json_content=""
    local in_json=false
    local brace_count=0

    while IFS= read -r line; do
        if [[ "$line" =~ \{ ]]; then
            # Extract JSON part starting from the first brace
            local json_start="${line#*\{}"
            json_content="{"$json_start
            in_json=true
            brace_count=1

            # Count braces in current line
            local line_open line_close
            line_open=$(echo "$json_content" | tr -cd '{' | wc -c)
            line_close=$(echo "$json_content" | tr -cd '}' | wc -c)
            brace_count=$((line_open - line_close))

            # If brace count reaches 0, we have complete JSON on one line
            if [[ $brace_count -eq 0 ]]; then
                break
            fi
        elif [[ "$in_json" == true ]]; then
            json_content="$json_content"$'\n'"$line"
            # Count braces to detect end of JSON
            local line_open line_close
            line_open=$(echo "$line" | tr -cd '{' | wc -c)
            line_close=$(echo "$line" | tr -cd '}' | wc -c)
            brace_count=$((brace_count + line_open - line_close))

            # If brace count reaches 0, we've found the end of JSON
            if [[ $brace_count -eq 0 ]]; then
                break
            fi
        fi
    done <<< "$output"

    if [[ -n "$json_content" && "$in_json" == true ]]; then
        # Validate JSON and extract fields using jq
        if echo "$json_content" | jq . >/dev/null 2>&1; then
            local status info
            status=$(echo "$json_content" | jq -r '.status // empty')
            info=$(echo "$json_content" | jq -r '.info // empty')

            if [[ "$status" == "success" ]]; then
                echo -e "\033[32m✓ $info\033[0m"
            elif [[ "$status" == "error" ]]; then
                echo -e "\033[31m✗ $info\033[0m"
            else
                echo "$json_content" | jq .
            fi
            return 0
        else
            format_json "$json_content"
            return 0
        fi
    else
        return 1
    fi
}

execute_script() {
    local file="$1"
    local host="$2"
    local password="$3"
    local output

    if [[ -n "$host" && -n "$password" ]]; then
        local host_info user host_port host port
        host_info=$(parse_host_info "$host")
        user=$(echo "$host_info" | cut -d'@' -f1)
        host_port=$(echo "$host_info" | cut -d'@' -f2)
        host=$(echo "$host_port" | cut -d':' -f1)
        port=$(echo "$host_port" | cut -d':' -f2)

        output=$(sshpass -p "$password" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" 'bash -s' < "$file" 2>&1)
    else
        output=$(bash "$file" 2>&1)
    fi

    parse_json_output "$output" || { echo; echo "Result:"; echo "$output"; }
}

main() {
    # Check dependencies first
    if ! check_dependencies; then
        exit 1
    fi

    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <recipe> [host[:port]] [password]"
        echo "Local: $0 nginx"
        echo "Remote: $0 nginx 77.110.114.16 password"
        echo "        $0 nginx root@77.110.114.16:2222 password"
        echo "        $0 nginx 77.110.114.16:2222 password"
        exit 1
    fi

    local recipe_name="$1"
    local host="$2"
    local password="$3"

    if [[ -n "$host" && -z "$password" ]]; then
        echo "Error: Password is required for remote execution."
        exit 1
    fi

    local temp_file
    if ! temp_file=$(download_script "$recipe_name"); then
        exit 1
    fi

    display_metadata "$temp_file"
    execute_script "$temp_file" "$host" "$password"

    rm -f "$temp_file"
}

main "$@"