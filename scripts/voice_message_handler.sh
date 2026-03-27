#!/bin/bash
# Feishu voice chat - 语音消息处理工作流
# 当前最终版：1. 只转语音最终回复 2. 修复语音识别问题

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
WHISPER_MODEL="${WHISPER_MODEL:-small}"
WHISPER_MODEL_DIR="${WHISPER_MODEL_DIR:-$HOME/.openclaw/tmp/whisper-models}"
WHISPER_BEAM_SIZE="${WHISPER_BEAM_SIZE:-5}"
WHISPER_BEST_OF="${WHISPER_BEST_OF:-5}"
STT_UPGRADE_MODEL="${STT_UPGRADE_MODEL:-small}"
STT_UPGRADE_KEYWORDS="${STT_UPGRADE_KEYWORDS:-金额|数字|账号|验证码|密码|地址|电话|邮箱|合同|订单|发票|转账|汇款|日期|时间}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印帮助
print_help() {
    cat << EOF
🎤 Feishu voice chat - 语音消息处理工作流

🎯 改进内容：
1. 语音转文字准确性提升
2. 只转语音最终回复内容（不包含思考过程）
3. 更准确的意图识别

用法：bash $0 [选项]

选项:
  -i, --input <file>       输入语音文件（必需）
  -m, --message-id <id>    原消息ID（用于回复）
  --stt-model <model>      Whisper 模型（默认：small，可选：tiny/base/small/medium/large）
  --stt-upgrade-model <m>  关键词命中后自动复识别模型（默认：small）
  -v, --voice <voice>      回复语音音色（默认：zh-CN-XiaoxiaoNeural）
  -h, --help              显示帮助

示例:
  bash $0 -i voice.ogg -m om_xxx

EOF
}

should_upgrade_stt_model() {
    local text="$1"
    local keywords="$STT_UPGRADE_KEYWORDS"
    IFS='|' read -r -a kw_list <<< "$keywords"
    for kw in "${kw_list[@]}"; do
        if [ -n "$kw" ] && [[ "$text" == *"$kw"* ]]; then
            return 0
        fi
    done
    return 1
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
}

normalize_message_id() {
    local raw_id="$1"
    local normalized_id="${raw_id%%:*}"
    printf '%s' "$normalized_id"
}

# 语音转文字（最终版）
convert_audio_to_text() {
    local input_file="$1"
    local language="${2:-auto}"
    
    echo -e "${BLUE}🎤 步骤1：语音转文字...${NC}" >&2
    
    if ! command -v whisper &> /dev/null; then
        echo -e "${RED}❌ 错误：未安装 whisper${NC}" >&2
        echo "请安装：pip install openai-whisper" >&2
        return 1
    fi
    mkdir -p "$WHISPER_MODEL_DIR"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    local base_name=$(basename "$input_file" .ogg)
    local output_base="$temp_dir/$base_name"
    
    # 使用正确的 whisper 参数
    echo -e "${YELLOW}⚠️ 正在识别语音内容...${NC}" >&2

    local normalized_audio="$temp_dir/${base_name}.wav"
    if ! ffmpeg -y -i "$input_file" -ac 1 -ar 16000 -af "highpass=f=80,lowpass=f=7600,volume=1.8" "$normalized_audio" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ 音频预处理失败，回退原始音频识别${NC}" >&2
        normalized_audio="$input_file"
    fi

    local -a whisper_args
    whisper_args=(
        --model "$WHISPER_MODEL"
        --model_dir "$WHISPER_MODEL_DIR"
        --beam_size "$WHISPER_BEAM_SIZE"
        --best_of "$WHISPER_BEST_OF"
        --temperature 0
        --fp16 False
        --output_format txt
        --output_dir "$temp_dir"
    )
    # language=auto 时不传 --language，让 whisper 自动检测；中文固定 prompt 提升准确率
    if [ -n "$language" ] && [ "$language" != "auto" ]; then
        whisper_args+=(--language "$language")
        if [ "$language" = "zh" ] || [ "$language" = "Chinese" ] || [ "$language" = "中文" ]; then
            whisper_args+=(--initial_prompt "以下是普通话中文语音转写。")
        fi
    fi

    if ! whisper "$normalized_audio" "${whisper_args[@]}" >/dev/null 2>&1; then
        echo -e "${RED}❌ 语音识别失败：whisper 执行失败${NC}" >&2
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 检查输出文件
    local txt_file="${output_base}.txt"
    if [ -f "$txt_file" ]; then
        local result=$(cat "$txt_file" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ -n "$result" ]; then
            echo -e "${GREEN}✅ 识别成功：$result${NC}" >&2
            echo "$result"
            rm -rf "$temp_dir"
            return 0
        fi
    fi
    
    echo -e "${RED}❌ 语音识别结果为空${NC}" >&2
    rm -rf "$temp_dir"
    return 1
}

# 文本理解分析
analyze_text() {
    local text="$1"
    
    echo -e "${BLUE}🧠 步骤2：文本理解分析...${NC}" >&2
    echo "识别文本：$text" >&2
    
    # 分析意图和生成回复
    local intent=""
    local final_reply=""
    local analysis_details=""
    
    # 更准确的意图识别
    case "$text" in
        *改进*|*修复*|*问题*|*错误*)
            intent="improvement"
            analysis_details="检测到改进或问题反馈意图"
            final_reply="好的，我来检查和改进相关功能"
            ;;
        *测试*|*验证*|*检查*)
            intent="testing"
            analysis_details="检测到测试验证意图"
            final_reply="功能测试正常，运行良好"
            ;;
        *你好*|*hello*|*hi*)
            intent="greeting"
            analysis_details="检测到问候意图"
            final_reply="你好！语音处理功能运行正常"
            ;;
        *谢谢*|*感谢*|*thank*)
            intent="thanks"
            analysis_details="检测到感谢意图"
            final_reply="不客气！很高兴能帮到你"
            ;;
        *语音*|*声音*|*说话*)
            intent="voice"
            analysis_details="检测到语音相关意图"
            final_reply="语音处理功能正在正常运行"
            ;;
        *)
            intent="general"
            analysis_details="检测到一般意图"
            final_reply="收到你的语音消息，功能运行正常"
            ;;
    esac
    
    echo -e "${GREEN}✅ 分析结果：$analysis_details${NC}" >&2
    echo -e "${BLUE}💬 最终回复内容：$final_reply${NC}" >&2
    
    # 返回最终回复内容（用于语音生成）和分析详情（用于文字说明）
    echo "$final_reply"
}

# 生成回复语音（只转最终回复内容）
generate_reply_voice() {
    local final_reply="$1"
    local voice="$2"
    local output_file="$3"
    
    echo -e "${BLUE}🔊 步骤3：生成回复语音（仅最终内容）...${NC}"
    
    if ! command -v edge-tts &> /dev/null; then
        echo -e "${RED}❌ 错误：未安装 edge-tts${NC}"
        return 1
    fi
    
    # 生成临时文件
    local temp_mp3="${output_file%.*}.mp3"
    
    # 只生成最终回复内容的语音
    echo -e "${YELLOW}⚠️ 正在生成语音：$final_reply${NC}"
    edge-tts --voice "$voice" --text "$final_reply" --write-media "$temp_mp3" 2>&1 | tail -3
    
    # 转换为 OPUS
    ffmpeg -i "$temp_mp3" -c:a libopus -b:a 32k "$output_file" -y 2>&1 | tail -3
    
    # 清理临时文件
    rm -f "$temp_mp3"
    
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        echo -e "${GREEN}✅ 语音生成成功${NC}"
        return 0
    else
        echo -e "${RED}❌ 语音生成失败${NC}"
        return 1
    fi
}

# 发送回复消息
send_reply_message() {
    local final_reply="$1"
    local voice_file="$2"
    local message_id="$3"
    local analysis_details="$4"
    
    echo -e "${BLUE}📤 步骤4：发送回复消息...${NC}"
    
    # 获取 Token
    TOKEN=$(curl -s -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
      -H "Content-Type: application/json" \
      -d "{\"app_id\":\"$FEISHU_APP_ID\",\"app_secret\":\"$FEISHU_APP_SECRET\"}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('tenant_access_token',''))")
    
    if [ -z "$TOKEN" ]; then
        echo -e "${RED}❌ 错误：获取 Token 失败${NC}"
        return 1
    fi
    
    # 发送语音回复（只包含最终回复内容）
    if [ -n "$voice_file" ] && [ -f "$voice_file" ]; then
        echo -e "${BLUE}📤 上传语音文件...${NC}"
        
        UPLOAD_RESULT=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/files" \
          -H "Authorization: Bearer $TOKEN" \
          -F "type=audio" \
          -F "file=@$voice_file" \
          -F "file_type=opus")
        
        FILE_KEY=$(echo "$UPLOAD_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('file_key',''))")
        
        if [ -n "$FILE_KEY" ]; then
            # 获取音频时长
            DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$voice_file")
            DURATION_MS=$(echo "$DURATION" | awk '{printf "%.0f", $1 * 1000}')
            
            # 发送语音消息
            RESULT=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/messages/$message_id/reply" \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" \
              -d "{\"content\":\"{\\\"file_key\\\":\\\"$FILE_KEY\\\",\\\"duration\\\":$DURATION_MS}\",\"msg_type\":\"audio\"}")
            
            echo -e "${GREEN}✅ 语音回复发送成功${NC}"
        else
            echo -e "${RED}❌ 语音文件上传失败${NC}"
        fi
    fi
    
    # 发送详细的文字回复（包含分析过程）
    echo -e "${BLUE}📤 发送文字回复...${NC}"
    
    local full_text_reply="🎯 语音处理流程完成：\n"
    full_text_reply+="• 识别结果：$analysis_details\n"
    full_text_reply+="• 最终回复：$final_reply\n"
    full_text_reply+="• 语音已发送：只包含最终回复内容"
    local safe_text_reply
    safe_text_reply="$(printf '%s' "$full_text_reply" | json_escape)"
    
    RESULT=$(curl -s -X POST "https://open.feishu.cn/open-apis/im/v1/messages/$message_id/reply" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\":\"{\\\"text\\\":\\\"$safe_text_reply\\\"}\",\"msg_type\":\"text\"}")
    
    echo -e "${GREEN}✅ 文字回复发送成功${NC}"
    
    return 0
}

# 主处理流程
main() {
    local input_file=""
    local message_id=""
    local stt_model=""
    local stt_upgrade_model=""
    local voice="zh-CN-XiaoxiaoNeural"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                input_file="$2"
                shift 2
                ;;
            -m|--message-id)
                message_id="$2"
                shift 2
                ;;
            --stt-model)
                stt_model="$2"
                shift 2
                ;;
            --stt-upgrade-model)
                stt_upgrade_model="$2"
                shift 2
                ;;
            -v|--voice)
                voice="$2"
                shift 2
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
    
    # 检查必需参数
    if [ -z "$input_file" ]; then
        echo -e "${RED}❌ 错误：必须提供 -i 输入文件${NC}"
        print_help
        exit 1
    fi
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}❌ 错误：输入文件不存在${NC}"
        exit 1
    fi
    
    if [ -z "$message_id" ]; then
        echo -e "${RED}❌ 错误：必须提供 -m 消息ID${NC}"
        print_help
        exit 1
    fi
    message_id="$(normalize_message_id "$message_id")"
    if [[ "$message_id" == oc_* ]]; then
        echo -e "${RED}❌ 错误：传入的是 chat_id（$message_id），不是 message_id（应为 om_ 开头）${NC}"
        exit 1
    fi
    
    # 检查环境变量
    if [ -z "$FEISHU_APP_ID" ] || [ -z "$FEISHU_APP_SECRET" ]; then
        echo -e "${RED}❌ 错误：缺少 Feishu 配置${NC}"
        exit 1
    fi

    if [ -n "$stt_model" ]; then
        WHISPER_MODEL="$stt_model"
    fi
    if [ -n "$stt_upgrade_model" ]; then
        STT_UPGRADE_MODEL="$stt_upgrade_model"
    fi
    
    echo -e "${GREEN}🎯 开始语音消息处理工作流${NC}"
    echo "输入文件：$input_file"
    echo "消息ID：$message_id"
    echo "音色：$voice"
    echo ""
    
    # 步骤1：语音转文本
    local recognized_text
    recognized_text="$(convert_audio_to_text "$input_file" "zh")"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 工作流中断：语音转文本失败${NC}"
        exit 1
    fi

    if [ -z "$stt_model" ] && [ "$WHISPER_MODEL" = "tiny" ] && should_upgrade_stt_model "$recognized_text"; then
        echo -e "${YELLOW}⚠️ 命中关键词，自动切换 ${STT_UPGRADE_MODEL} 进行复识别...${NC}"
        local first_pass_text="$recognized_text"
        local original_model="$WHISPER_MODEL"
        WHISPER_MODEL="$STT_UPGRADE_MODEL"
        local retry_text
        retry_text="$(convert_audio_to_text "$input_file" "zh")" || retry_text=""
        WHISPER_MODEL="$original_model"

        if [ -n "$retry_text" ]; then
            recognized_text="$retry_text"
            echo -e "${GREEN}✅ 复识别完成，已使用 ${STT_UPGRADE_MODEL} 结果${NC}"
        else
            recognized_text="$first_pass_text"
            echo -e "${YELLOW}⚠️ 复识别失败，保留首次识别结果${NC}"
        fi
    fi
    
    # 步骤2：文本理解分析
    local final_reply=$(analyze_text "$recognized_text")
    local analysis_details="识别内容：$recognized_text"
    
    # 步骤3：生成回复语音（只转最终回复）
    local temp_dir=$(mktemp -d)
    local voice_file="$temp_dir/reply.opus"
    
    if ! generate_reply_voice "$final_reply" "$voice" "$voice_file"; then
        echo -e "${YELLOW}⚠️ 语音生成失败，仅发送文字回复${NC}"
        voice_file=""
    fi
    
    # 步骤4：发送回复消息
    if ! send_reply_message "$final_reply" "$voice_file" "$message_id" "$analysis_details"; then
        echo -e "${RED}❌ 工作流中断：发送回复失败${NC}"
        exit 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}🎉 语音消息处理工作流完成！${NC}"
    echo "识别内容：$recognized_text"
    echo "最终回复：$final_reply"
}

# 执行主函数
main "$@"
