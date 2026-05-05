#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo '{"text": "N/A", "tooltip": "nvidia-smi not found"}'
    exit 0
fi

gpu_info=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true)

if [[ -z "$gpu_info" ]]; then
    echo '{"text": "N/A", "tooltip": "No GPU data"}'
    exit 0
fi

temp=$(echo "$gpu_info" | awk -F', ' '{print $1}' | tr -d ' ')
util=$(echo "$gpu_info" | awk -F', ' '{print $2}' | tr -d ' ')
mem_used=$(echo "$gpu_info" | awk -F', ' '{print $3}' | tr -d ' ')
mem_total=$(echo "$gpu_info" | awk -F', ' '{print $4}' | tr -d ' ')

text="GPU ${temp}C ${util}% ${mem_used}/${mem_total}MB"
tooltip="Temperature: ${temp}C\nUtilization: ${util}%\nMemory: ${mem_used}/${mem_total}MB"

printf '{"text": "%s", "tooltip": "%s"}' "$text" "$tooltip"
