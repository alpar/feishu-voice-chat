#!/bin/bash
# OpenClaw <-> Feishu voice bridge (no core code changes)
# Purpose:
# 1) Take inbound audio downloaded by OpenClaw
# 2) Run skill-side STT/TTS pipeline
# 3) Reply back to the original Feishu message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_help() {
    cat << EOF
🔗 OpenClaw Audio Bridge

用法:
  bash $0 -i <inbound.ogg> -m <message_id> [选项]

选项:
  -i, --input <file>            OpenClaw 下载的语音文件（必需）
  -m, --message-id <id>         飞书原消息 ID（必需）
  -v, --voice <voice>           回复音色（默认：zh-CN-XiaoxiaoNeural）
  --stt-model <model>           首次识别模型（默认：small）
  --stt-upgrade-model <model>   命中关键词后的复识别模型（默认：small）
  -h, --help                    显示帮助

示例:
  bash $0 -i ~/.openclaw/media/inbound/xxx.ogg -m om_xxx
  bash $0 -i ~/.openclaw/media/inbound/xxx.ogg -m om_xxx --stt-model small --stt-upgrade-model small
EOF
}

INPUT_FILE=""
MESSAGE_ID=""
VOICE="zh-CN-XiaoxiaoNeural"
STT_MODEL="small"
STT_UPGRADE_MODEL="small"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)
            INPUT_FILE="${2:-}"
            shift 2
            ;;
        -m|--message-id)
            MESSAGE_ID="${2:-}"
            shift 2
            ;;
        -v|--voice)
            VOICE="${2:-}"
            shift 2
            ;;
        --stt-model)
            STT_MODEL="${2:-}"
            shift 2
            ;;
        --stt-upgrade-model)
            STT_UPGRADE_MODEL="${2:-}"
            shift 2
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "❌ 未知参数: $1"
            print_help
            exit 1
            ;;
    esac
done

if [ -z "$INPUT_FILE" ] || [ -z "$MESSAGE_ID" ]; then
    echo "❌ 缺少必需参数"
    print_help
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ 输入文件不存在: $INPUT_FILE"
    exit 1
fi

if [ -z "${FEISHU_APP_ID:-}" ] || [ -z "${FEISHU_APP_SECRET:-}" ]; then
    echo "❌ 缺少 FEISHU_APP_ID / FEISHU_APP_SECRET"
    exit 1
fi

exec bash "$SCRIPT_DIR/voice_message_handler.sh" \
    -i "$INPUT_FILE" \
    -m "$MESSAGE_ID" \
    -v "$VOICE" \
    --stt-model "$STT_MODEL" \
    --stt-upgrade-model "$STT_UPGRADE_MODEL"
