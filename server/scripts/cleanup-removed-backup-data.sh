#!/bin/bash

set -euo pipefail

usage() {
    echo "用法: $0 [--dry-run|--apply]"
}

mode="${1:---dry-run}"
if [[ "$mode" != "--dry-run" && "$mode" != "--apply" ]]; then
    usage >&2
    exit 2
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
server_dir="$(CDPATH= cd -- "$script_dir/.." && pwd -P)"
data_dir="$server_dir/data"

if [[ -L "$data_dir" ]]; then
    echo "拒绝清理：$data_dir 是符号链接" >&2
    exit 1
fi
if [[ -e "$data_dir" && ! -d "$data_dir" ]]; then
    echo "拒绝清理：$data_dir 不是目录" >&2
    exit 1
fi

temp_root="$(node -p "require('os').tmpdir()")"
if [[ -z "$temp_root" || "$temp_root" != /* || "$temp_root" == "/" || ! -d "$temp_root" ]]; then
    echo "拒绝清理：无法安全确定 Node 临时目录" >&2
    exit 1
fi

resolved_temp_root="$(CDPATH= cd -- "$temp_root" && pwd -P)" || {
    echo "拒绝清理：无法解析 Node 临时目录" >&2
    exit 1
}
if [[ "$resolved_temp_root" == "/" ]]; then
    echo "拒绝清理：Node 临时目录不能是根目录" >&2
    exit 1
fi
temp_dir="$resolved_temp_root/litchi-journal-backups"
if [[ -L "$temp_dir" ]]; then
    echo "拒绝清理：$temp_dir 是符号链接" >&2
    exit 1
fi
if [[ -e "$temp_dir" && ! -d "$temp_dir" ]]; then
    echo "拒绝清理：$temp_dir 不是目录" >&2
    exit 1
fi

if [[ "$mode" == "--apply" ]] && command -v pm2 >/dev/null 2>&1; then
    running_pid="$(pm2 pid diary-api 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$running_pid" =~ ^[1-9][0-9]*$ ]]; then
        echo "拒绝清理：diary-api 仍在运行，请先停止旧服务" >&2
        exit 1
    fi
fi

is_backup_data_name() {
    case "$1" in
        backup-settings.json|backup-credentials.json|backup-state.json|\
        backup-settings.json.corrupt-*|backup-credentials.json.corrupt-*|backup-state.json.corrupt-*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

targets=()
if [[ -d "$data_dir" ]]; then
    if [[ ! -r "$data_dir" || ! -x "$data_dir" ]]; then
        echo "拒绝清理：无法安全读取 $data_dir" >&2
        exit 1
    fi
    while IFS= read -r -d '' candidate; do
        name="$(basename -- "$candidate")"
        if ! is_backup_data_name "$name"; then
            continue
        fi
        if [[ ! -f "$candidate" && ! -L "$candidate" ]]; then
            echo "拒绝清理：备份遗留目标不是普通文件或符号链接：$candidate" >&2
            exit 1
        fi
        targets+=("$candidate")
    done < <(find "$data_dir" -mindepth 1 -maxdepth 1 -print0)
fi

echo "模式：$mode"
if (( ${#targets[@]} == 0 )); then
    echo "未发现备份配置、凭据、状态或损坏隔离文件"
else
    echo "将处理以下备份数据文件："
    for target in "${targets[@]}"; do
        echo "  $target"
    done
fi

if [[ -d "$temp_dir" ]]; then
    echo "将处理应用专用临时目录："
    echo "  $temp_dir"
else
    echo "未发现应用专用临时目录"
fi

if [[ "$mode" == "--dry-run" ]]; then
    echo "仅预览，未删除任何内容"
    exit 0
fi

if (( ${#targets[@]} > 0 )); then
    for target in "${targets[@]}"; do
        rm -f -- "$target"
    done
fi
if [[ -d "$temp_dir" ]]; then
    rm -rf -- "$temp_dir"
fi

echo "备份遗留数据清理完成"
