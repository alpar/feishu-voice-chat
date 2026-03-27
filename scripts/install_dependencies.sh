#!/bin/bash
# Feishu voice - 依赖安装脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎤 Feishu voice - 依赖安装${NC}"
echo ""

# 检查 Python
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✅ Python3 已安装${NC}"
else
    echo -e "${RED}❌ 错误：未安装 Python3${NC}"
    echo "请先安装 Python3：https://www.python.org/downloads/"
    exit 1
fi

# 检查 pip
if command -v pip3 &> /dev/null; then
    echo -e "${GREEN}✅ pip3 已安装${NC}"
else
    echo -e "${RED}❌ 错误：未安装 pip3${NC}"
    echo "请先安装 pip3"
    exit 1
fi

# 安装 edge-tts
echo -e "${BLUE}📦 安装 edge-tts...${NC}"
if pip3 install edge-tts; then
    echo -e "${GREEN}✅ edge-tts 安装成功${NC}"
else
    echo -e "${RED}❌ edge-tts 安装失败${NC}"
    exit 1
fi

# 安装 whisper（可选）
echo -e "${BLUE}📦 安装 whisper（语音转文字功能）...${NC}"
echo -e "${YELLOW}⚠️ 注意：whisper 安装可能需要较长时间${NC}"

read -p "是否安装 whisper？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if pip3 install openai-whisper; then
        echo -e "${GREEN}✅ whisper 安装成功${NC}"
    else
        echo -e "${YELLOW}⚠️ whisper 安装失败，语音转文字功能不可用${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ 跳过 whisper 安装，语音转文字功能不可用${NC}"
fi

# 检查 ffmpeg
echo -e "${BLUE}🔧 检查 ffmpeg...${NC}"
if command -v ffmpeg &> /dev/null; then
    echo -e "${GREEN}✅ ffmpeg 已安装${NC}"
else
    echo -e "${RED}❌ 错误：未安装 ffmpeg${NC}"
    echo "请安装 ffmpeg："
    echo "  macOS: brew install ffmpeg"
    echo "  Ubuntu/Debian: sudo apt install ffmpeg"
    echo "  CentOS: sudo yum install ffmpeg"
    exit 1
fi

# 检查 curl
echo -e "${BLUE}🔧 检查 curl...${NC}"
if command -v curl &> /dev/null; then
    echo -e "${GREEN}✅ curl 已安装${NC}"
else
    echo -e "${RED}❌ 错误：未安装 curl${NC}"
    echo "请安装 curl"
    exit 1
fi

# 测试脚本权限
echo -e "${BLUE}🔧 设置脚本权限...${NC}"
chmod +x scripts/*.sh

# 测试基本功能
echo -e "${BLUE}🧪 测试基本功能...${NC}"

# 测试 edge-tts
if command -v edge-tts &> /dev/null; then
    echo -e "${GREEN}✅ edge-tts 命令可用${NC}"
else
    echo -e "${RED}❌ edge-tts 命令不可用${NC}"
    exit 1
fi

# 测试 whisper（如果安装了）
if command -v whisper &> /dev/null; then
    echo -e "${GREEN}✅ whisper 命令可用${NC}"
else
    echo -e "${YELLOW}⚠️ whisper 命令不可用（可选）${NC}"
fi

echo -e "${GREEN}🎉 依赖安装完成！${NC}"
echo ""
echo -e "${BLUE}📖 下一步：${NC}"
echo "1. 配置环境变量："
echo "   export FEISHU_APP_ID=\"cli_xxx\""
echo "   export FEISHU_APP_SECRET=\"xxx\""
echo "   export FEISHU_CHAT_ID=\"oc_xxx\""
echo ""
echo "2. 测试功能："
echo "   bash scripts/send_voice.sh -t \"测试语音\""
echo "   bash scripts/send_voice_enhanced.sh -i voice.ogg"
echo ""
echo "3. 查看帮助："
echo "   bash scripts/send_voice_enhanced.sh --help"