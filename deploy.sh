#!/bin/bash

default_path="https://github.com/drushadrusha/minideploy/recipes/" # Path to load recipes from

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
