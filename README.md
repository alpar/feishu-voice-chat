# Feishu-Voice-Chat - 飞书双向语音

使用OpenAi Whisper（免费），微软 Edge TTS（免费）生成语音，发送到飞书。集成语音转文本、文本转语音功能，支持双向转换。无需 API key，音质优秀，支持多语言多音色。

## 🎯 功能特点

- ✅ **完全免费**：纯本地部署，无需 API key
- ✅ **语音转文本**：使用OpenAi Whisper将语音转换为文字
- ✅ **双向转换**：文字→语音 + 语音→文字
- ✅ **智能集成**：语音识别后自动发送语音+文字组合
- ✅ **音质优秀**：微软 Azure 同款语音引擎
- ✅ **多音色支持**：支持中文/英文/日文等多种语言
- ✅ **语音条格式**：发送真正的飞书语音条（点击即播）
- ✅ **语速调节**：支持 0.5x - 2.0x 语速
- ✅ **音调调节**：支持音调高低调整


## 技术实现架构
- **技能路径**：`skills/feishu-voice-chat/`
- **语音桥接入口**： `scripts/openclaw_audio_bridge.sh` 
- **语音转换脚本**：`voice_to_text.sh`
- **语音发送脚本**：`send_voice.sh`
- **配置来源**：自动读取 `~/.openclaw/openclaw.json` 中的 `channels.feishu` 配置
- **执行引擎**：微软 Edge TTS（免费，无需 API key）
- **发送方式**：飞书云存储上传 + 语音条发送

### 正确调用方式
```bash
# OpenClaw 已下载入站语音后，直接桥接到本技能链路
bash scripts/openclaw_audio_bridge.sh \
  -i ~/.openclaw/media/inbound/xxx.ogg \
  -m om_xxx \
  --stt-model small \
  --stt-upgrade-model small

# 语音转文本
`bash scripts/voice_to_text.sh -i voice.ogg`

# 文本转语音并发送
bash scripts/send_voice.sh -t "语音内容" --reply-to "om_消息ID"
```

## 🎤 可用音色

### 中文音色
- **zh-CN-XiaoxiaoNeural** - 女声，温暖亲切（推荐）
- **zh-CN-YunxiNeural** - 男声，沉稳专业
- **zh-CN-YunjianNeural** - 男声，激情澎湃
- **zh-CN-XiaoyiNeural** - 女声，活泼可爱
- **zh-CN-liaoning-XiaobeiNeural** - 东北话女声
- **zh-CN-shaanxi-XiaoniNeural** - 陕西话女声

### 英文音色
- **en-US-JennyNeural** - 女声，美式英语（推荐）
- **en-US-GuyNeural** - 男声，美式英语
- **en-GB-SoniaNeural** - 女声，英式英语

### 更多音色
支持全球 100+ 语言，400+ 音色！

## 🚀 快速开始

### 步骤 1：安装依赖

```bash
# 基础依赖
pip install edge-tts

# 语音转文字功能（可选）
pip install openai-whisper

# 安装 ffmpeg
yum install -y ffmpeg  # CentOS/OpenCloudOS
apt-get install -y ffmpeg  # Ubuntu/Debian
```

### 步骤 2：OpenClaw 桥接入口

```bash
# OpenClaw 已下载入站语音后，直接桥接到本技能链路
bash scripts/openclaw_audio_bridge.sh \
  -i ~/.openclaw/media/inbound/xxx.ogg \
  -m om_xxx \
  --stt-model small
```

### 步骤 3：发送语音

```bash
# 使用默认音色（女声）
bash scripts/send_voice.sh -t "主人晚上好～" --reply-to "om_消息ID"
```

## 💡 使用示例

### 1. 温暖女声问候

```bash
bash scripts/send_voice.sh -t "主人早上好～ 新的一天开始啦，今天也要加油哦～" -v zh-CN-XiaoxiaoNeural
```

### 2. 专业男声播报

```bash
bash scripts/send_voice.sh -t "现在是北京时间上午 8 点，为您播报今日新闻。" -v zh-CN-YunxiNeural
```

### 3. 英文语音

```bash
bash scripts/send_voice.sh -t "Good morning! Have a nice day!" -v en-US-JennyNeural
```

### 4. 方言趣味

```bash
bash scripts/send_voice.sh -t "哎呀妈呀，这旮瘩真冷啊！" -v zh-CN-liaoning-XiaobeiNeural
```

### 5. 语音转文字功能

```bash
# 语音转文字（输出到控制台）
bash scripts/voice_to_text.sh -i voice.ogg

# 语音转文字并保存到文件
bash scripts/voice_to_text.sh -i voice.ogg -o result.txt

# 指定语言识别
bash scripts/voice_to_text.sh -i voice.ogg -l English

# 查看支持的语言
bash scripts/voice_to_text.sh --list-languages
```

### 6. 增强版：语音转文字 + 语音发送

```bash
# 语音转文字并发送语音+文字
bash scripts/send_voice_enhanced.sh -i voice.ogg

# 仅发送语音，不发送文字
bash scripts/send_voice_enhanced.sh -i voice.ogg --no-text

# 文字转语音（与原始脚本相同）
bash scripts/send_voice_enhanced.sh -t "你好"
```

## 📖 命令参数

```bash
bash scripts/send_voice.sh [选项]

选项:
  -t, --text <text>       要转换的文字（必需）
  -v, --voice <voice>     音色名称（默认：zh-CN-XiaoxiaoNeural）
  -r, --rate <1.0>        语速（-50% 到 +50%，默认 0%）
  -p, --pitch <0>         音调（-50Hz 到 +50Hz，默认 0）
  -o, --output <file>     输出音频文件路径
  --list-voices           列出所有可用音色
  --no-send               只生成音频，不发送
  -h, --help              显示帮助

```

## 🎵 音色列表

```bash
# 查看所有可用音色
bash scripts/send_voice.sh --list-voices

# 查看中文音色
bash scripts/send_voice.sh --list-voices | grep zh-CN
```

## ⚙️ 高级配置

### 1. 自定义默认音色

当前保留脚本中未单独维护 `config.sh`，默认值直接在脚本内声明；如需自定义，请修改对应脚本中的默认变量。

```bash
DEFAULT_VOICE="zh-CN-YunxiNeural"  # 男声
DEFAULT_RATE="0"                    # 正常语速
DEFAULT_PITCH="0"                   # 正常音调
```

### 2. 批量生成

```bash
# 从文件读取文字，批量生成
cat messages.txt | while read line; do
    bash scripts/send_voice.sh -t "$line"
    sleep 2
done
```

## 📦 文件结构

```
feishu-voice-chat/
├── SKILL.md
├── README.md
├── scripts/
│   ├── install_dependencies.sh
│   ├── openclaw_audio_bridge.sh
│   ├── send_voice.sh
│   ├── send_voice_enhanced.sh
│   ├── voice_message_handler.sh
│   └── voice_to_text.sh
```

## 💰 商业授权

- **个人使用**：免费
- **商业使用**：请联系作者获取授权

---

**Made with ❤️ by 何昕 (Alpar)**
