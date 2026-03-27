#!/bin/bash
# Feishu voice chat - 增强版：支持语音转文本 + 语音发送
# 用法：bash send_voice_enhanced.sh -t "文字" [-i 输入音频文件] [--reply-to 消息ID] [-v 音色] [-r 语速] [-p 音调]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
WHISPER_MODEL="${WHISPER_MODEL:-small}"
WHISPER_MODEL_DIR="${WHISPER_MODEL_DIR:-$HOME/.openclaw/tmp/whisper-models}"
WHISPER_BEAM_SIZE="${WHISPER_BEAM_SIZE:-5}"
WHISPER_BEST_OF="${WHISPER_BEST_OF:-5}"

# 默认配置
DEFAULT_VOICE="zh-CN-XiaoxiaoNeural"
DEFAULT_RATE="+20"
DEFAULT_PITCH="0"

VOICE="$DEFAULT_VOICE"
RATE="$DEFAULT_RATE"
PITCH="$DEFAULT_PITCH"
TEXT=""
INPUT_FILE=""
OUTPUT_FILE=""
LIST_VOICES=false
NO_SEND=false
SEND_TEXT_WITH_VOICE=true
LANGUAGE="Chinese"
MODEL=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
}

# 打印帮助
print_help() {
    cat << EOF
🎤 Feishu voice chat - 增强版：语音转文本 + 语音发送

用法：bash $0 [选项]

选项:
  -t, --text <text>       要转换的文字（与 -i 二选一）
  -i, --input <file>      输入音频文件（支持 .ogg, .mp3, .wav）
  -v, --voice <voice>     音色名称（默认：zh-CN-XiaoxiaoNeural）
  -r, --rate <0>          语速（-50 到 +50，默认 0）
  -p, --pitch <0>         音调（-50 到 +50，默认 0）
  -l, --language <lang>   语音识别语言（默认：Chinese）
  -m, --model <model>     Whisper 模型（默认：small，可选：tiny/base/small/medium/large）
  -o, --output <file>     输出音频文件路径
  --no-text               不发送文本消息（仅发送语音）
  --list-voices           列出所有可用音色
  --no-send               只生成音频，不发送
  --receive-id-type <type> 接收者ID类型（chat_id/open_id，默认chat_id）
  -h, --help              显示帮助

常用音色:
  zh-CN-XiaoxiaoNeural    女声，温暖亲切（推荐）
  zh-CN-YunxiNeural       男声，沉稳专业
  zh-CN-YunjianNeural     男声，激情澎湃
  zh-CN-XiaoyiNeural      女声，活泼可爱
  en-US-JennyNeural       女声，美式英语

示例:
  # 文字转语音
  bash $0 -t "主人晚上好～"
  bash $0 -t "Hello!" -v en-US-JennyNeural
  
  # 语音转文字 + 语音发送
  bash $0 -i voice.ogg
  bash $0 -i voice.ogg -l English
  bash $0 -i voice.ogg -m small
  
  # 仅发送语音，不发送文字
  bash $0 -i voice.ogg --no-text
  
  # 查看音色列表
  bash $0 --list-voices

EOF
}

# 列出所有可用音色
list_voices() {
    echo -e "${BLUE}🎤 获取可用音色列表...${NC}"
    
    if command -v edge-tts &> /dev/null; then
        edge-tts --list-voices 2>/dev/null | grep -E "zh-CN|zh-HK|zh-TW|en-US|en-GB" | head -30
    else
        echo "未安装 edge-tts，请先运行：pip install edge-tts"
    fi
}

# 检查 whisper 是否可用
check_whisper() {
    if ! command -v whisper &> /dev/null; then
        echo -e "${YELLOW}⚠️ 提示：未安装 whisper，语音转文字功能不可用${NC}"
        echo "如需语音转文字功能，请安装：pip install openai-whisper"
        return 1
    fi
    mkdir -p "$WHISPER_MODEL_DIR"
    return 0
}

# 语音转文字
convert_audio_to_text() {
    local input_file="$1"
    local language="$2"
    
    echo -e "${BLUE}🎤 语音转文字...${NC}" >&2
    
    if ! check_whisper; then
        return 1
    fi
    
    local temp_dir
    temp_dir="$(mktemp -d)"
    local base_name
    base_name="$(basename "$input_file")"
    base_name="${base_name%.*}"
    local temp_output="$temp_dir/${base_name}.txt"
    local normalized_audio="$temp_dir/${base_name}.wav"
    local whisper_lang="$language"
    local initial_prompt=""

    case "$language" in
        Chinese|中文|zh|zh-CN|zh_cn)
            whisper_lang="zh"
            initial_prompt="以下是普通话中文语音转写。"
            ;;
        English|英文|en|en-US|en_us)
            whisper_lang="en"
            ;;
        Japanese|日语|ja|ja-JP|ja_jp)
            whisper_lang="ja"
            ;;
        Korean|韩语|ko|ko-KR|ko_kr)
            whisper_lang="ko"
            ;;
    esac

    if ! ffmpeg -y -i "$input_file" -ac 1 -ar 16000 -af "highpass=f=80,lowpass=f=7600,volume=1.8" "$normalized_audio" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ 音频预处理失败，回退原始音频识别${NC}" >&2
        normalized_audio="$input_file"
    fi

    # 运行 whisper（输出文件名为 <basename>.txt）
    local -a whisper_args
    whisper_args=(
        --language "$whisper_lang"
        --model "$WHISPER_MODEL"
        --model_dir "$WHISPER_MODEL_DIR"
        --beam_size "$WHISPER_BEAM_SIZE"
        --best_of "$WHISPER_BEST_OF"
        --temperature 0
        --fp16 False
        --output_format txt
        --output_dir "$temp_dir"
    )
    if [ -n "$initial_prompt" ]; then
        whisper_args+=(--initial_prompt "$initial_prompt")
    fi

    if ! whisper "$normalized_audio" "${whisper_args[@]}" >/dev/null 2>&1; then
        echo -e "${RED}❌ 语音转文字失败：whisper 执行失败${NC}" >&2
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 读取结果
    if [ -f "$temp_output" ]; then
        local result=$(cat "$temp_output" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # 清理临时文件
        rm -rf "$temp_dir"
        
        if [ -n "$result" ]; then
            echo -e "${GREEN}✅ 语音转文字成功${NC}" >&2
            echo "识别结果：$result" >&2
            echo "" >&2
            echo "$result"
            return 0
        fi
    fi
    
    echo -e "${RED}❌ 语音转文字失败：输出为空${NC}" >&2
    rm -rf "$temp_dir"
    return 1
}

# 发送文本消息
send_text_message() {
    local text="$1"
    local token="$2"
    local safe_text
    safe_text="$(printf '%s' "$text" | json_escape)"
    
    echo -e "${BLUE}📝 发送文本消息...${NC}"
    
    RESULT=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "{\"receive_id\":\"$FEISHU_CHAT_ID\",\"msg_type\":\"text\",\"content\":\"{\\\"text\\\":\\\"$safe_text\\\"}\"}")
    
    MESSAGE_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('message_id',''))")
    
    if [ -n "$MESSAGE_ID" ]; then
        echo -e "${GREEN}✅ 文本发送成功${NC}"
    else
        echo -e "${RED}❌ 文本发送失败${NC}"
        echo "$RESULT"
    fi
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--text)
            TEXT="$2"
            shift 2
            ;;
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -v|--voice)
            VOICE="$2"
            shift 2
            ;;
        -r|--rate)
            RATE="$2"
            shift 2
            ;;
        -p|--pitch)
            PITCH="$2"
            shift 2
            ;;
        -l|--language)
            LANGUAGE="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --no-text)
            SEND_TEXT_WITH_VOICE=false
            shift
            ;;
        --list-voices)
            LIST_VOICES=true
            shift
            ;;
        --no-send)
            NO_SEND=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 未知选项：$1${NC}"
            print_help
            exit 1
            ;;
    esac
done

# 列出音色模式
if [ "$LIST_VOICES" = true ]; then
    list_voices
    exit 0
fi

# 检查必需参数
if [ -z "$TEXT" ] && [ -z "$INPUT_FILE" ]; then
    echo -e "${RED}❌ 错误：必须提供 -t 文字 或 -i 输入文件${NC}"
    print_help
    exit 1
fi

if [ -n "$MODEL" ]; then
    WHISPER_MODEL="$MODEL"
fi

# 检查互斥参数
if [ -n "$TEXT" ] && [ -n "$INPUT_FILE" ]; then
    echo -e "${RED}❌ 错误：-t 和 -i 参数不能同时使用${NC}"
    print_help
    exit 1
fi

# 如果是语音输入模式，转换语音为文字
if [ -n "$INPUT_FILE" ]; then
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}❌ 错误：输入文件不存在${NC}"
        exit 1
    fi
    
    TEXT=$(convert_audio_to_text "$INPUT_FILE" "$LANGUAGE")
    if [ $? -ne 0 ] || [ -z "$TEXT" ]; then
        echo -e "${RED}❌ 语音转文字失败，无法继续${NC}"
        exit 1
    fi
fi

# 检查 edge-tts 是否安装
if ! command -v edge-tts &> /dev/null; then
    echo -e "${RED}❌ 错误：未安装 edge-tts${NC}"
    echo "请运行：pip install edge-tts"
    exit 1
fi

# 检查环境变量（发送时需要）
if [ "$NO_SEND" = false ]; then
    if [ -z "$FEISHU_APP_ID" ] || [ -z "$FEISHU_APP_SECRET" ] || [ -z "$FEISHU_CHAT_ID" ]; then
        echo -e "${RED}❌ 错误：缺少 Feishu 配置${NC}"
        echo "请设置："
        echo "  export FEISHU_APP_ID=\"cli_xxx\""
        echo "  export FEISHU_APP_SECRET=\"xxx\""
export FEISHU_OPEN_ID="ou_dd5e80beaff75169fa3995ed41e30f62"  # 私聊使用open_id
        exit 1
    fi
fi

echo -e "${BLUE}🎤 开始处理...${NC}"
echo "文字：$TEXT"
if [ -n "$INPUT_FILE" ]; then
    echo "输入文件：$INPUT_FILE"
fi
echo "音色：$VOICE"
echo "语速：$RATE%"
echo "音调：$PITCH Hz"
echo ""

# 生成临时文件
TEMP_DIR=$(mktemp -d)
TEMP_MP3="$TEMP_DIR/voice.mp3"
TEMP_OPUS="$TEMP_DIR/voice.opus"

# 使用 edge-tts 生成语音
echo -e "${BLUE}🔊 调用 Edge TTS...${NC}"

# 构建参数
RATE_PARAM=""
if [ "$RATE" != "0" ]; then
    RATE_PARAM="--rate $RATE%"
fi

PITCH_PARAM=""
if [ "$PITCH" != "0" ]; then
    PITCH_PARAM="--pitch $PITCHHz"
fi

# 生成 MP3
edge-tts --voice "$VOICE" --text "$TEXT" $RATE_PARAM $PITCH_PARAM --write-media "$TEMP_MP3" 2>&1 | tail -3

if [ ! -f "$TEMP_MP3" ] || [ ! -s "$TEMP_MP3" ]; then
    echo -e "${RED}❌ 错误：语音生成失败${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✅ 语音生成成功${NC}"

# 转换为 OPUS 格式
echo -e "${BLUE}🔄 转换为 OPUS 格式...${NC}"
ffmpeg -i "$TEMP_MP3" -c:a libopus -b:a 32k "$TEMP_OPUS" -y 2>&1 | tail -3

if [ ! -f "$TEMP_OPUS" ] || [ ! -s "$TEMP_OPUS" ]; then
    echo -e "${RED}❌ 错误：OPUS 转换失败${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✅ OPUS 转换成功${NC}"

# 保存输出文件（如果指定）
if [ -n "$OUTPUT_FILE" ]; then
    cp "$TEMP_OPUS" "$OUTPUT_FILE"
    echo -e "${GREEN}✅ 已保存到：$OUTPUT_FILE${NC}"
fi

# 只生成不发送
if [ "$NO_SEND" = true ]; then
    rm -rf "$TEMP_DIR"
    echo -e "${GREEN}✅ 完成（未发送）${NC}"
    exit 0
fi

echo -e "${BLUE}📤 上传到飞书...${NC}"

# 获取 Token
TOKEN=$(curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$FEISHU_APP_ID\",\"app_secret\":\"$FEISHU_APP_SECRET\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('tenant_access_token',''))")

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ 错误：获取 Token 失败${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 上传文件
UPLOAD_RESULT=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/files" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=audio" \
  -F "file=@$TEMP_OPUS" \
  -F "file_type=opus")

FILE_KEY=$(echo "$UPLOAD_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('file_key',''))")

if [ -z "$FILE_KEY" ]; then
    echo -e "${RED}❌ 错误：文件上传失败${NC}"
    echo "$UPLOAD_RESULT"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✅ 文件上传成功，File Key: $FILE_KEY${NC}"

# 获取音频时长
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TEMP_OPUS")
DURATION_MS=$(echo "$DURATION" | awk '{printf "%.0f", $1 * 1000}')

# 发送语音消息
echo -e "${BLUE}📤 发送语音消息...${NC}"

RESULT=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"receive_id\":\"$FEISHU_CHAT_ID\",\"msg_type\":\"audio\",\"content\":\"{\\\"file_key\\\":\\\"$FILE_KEY\\\",\\\"duration\\\":$DURATION_MS}\"}")

MESSAGE_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('message_id',''))")

# 发送文本消息（如果需要）
if [ "$SEND_TEXT_WITH_VOICE" = true ] && [ -n "$TEXT" ]; then
    send_text_message "$TEXT" "$TOKEN"
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

# 检查结果
if [ -n "$MESSAGE_ID" ]; then
    echo -e "${GREEN}✅ 发送成功！${NC}"
    echo "Message ID: $MESSAGE_ID"
    echo "Chat ID: $FEISHU_CHAT_ID"
    echo "时长：${DURATION_MS}ms (${DURATION}s)"
    
    if [ "$SEND_TEXT_WITH_VOICE" = true ]; then
        echo "已同时发送语音和文字消息"
    else
        echo "仅发送语音消息"
    fi
else
    echo -e "${RED}❌ 发送失败${NC}"
    echo "$RESULT"
    exit 1
fi
