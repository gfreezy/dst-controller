#!/bin/bash

# 饥荒联机版 Mod 自动监控同步脚本
# 监控文件变化并自动同步到游戏目录

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOD_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "饥荒联机版 Mod 自动同步工具"
echo "========================================"
echo -e "${YELLOW}监控目录: $MOD_SOURCE_DIR${NC}"
echo -e "${BLUE}按 Ctrl+C 停止监控${NC}"
echo ""

# 检查是否安装了 fswatch (Mac) 或 inotifywait (Linux)
if command -v fswatch &> /dev/null; then
    # macOS
    echo -e "${GREEN}使用 fswatch 监控文件变化...${NC}"
    echo ""

    fswatch -o "$MOD_SOURCE_DIR" --exclude='.git' --exclude='node_modules' --exclude='.vscode' | while read -r
    do
        echo -e "${YELLOW}检测到文件变化，开始同步...${NC}"
        bash "$MOD_SOURCE_DIR/sync.sh"
        echo ""
        echo -e "${GREEN}等待下次变化...${NC}"
    done

elif command -v inotifywait &> /dev/null; then
    # Linux
    echo -e "${GREEN}使用 inotifywait 监控文件变化...${NC}"
    echo ""

    while inotifywait -r -e modify,create,delete --exclude '(\.git|node_modules|\.vscode)' "$MOD_SOURCE_DIR"; do
        echo -e "${YELLOW}检测到文件变化，开始同步...${NC}"
        bash "$MOD_SOURCE_DIR/sync.sh"
        echo ""
        echo -e "${GREEN}等待下次变化...${NC}"
    done

else
    echo -e "${YELLOW}警告: 未找到文件监控工具${NC}"
    echo ""
    echo "请安装以下工具之一:"
    echo "  macOS: brew install fswatch"
    echo "  Linux: apt install inotify-tools (Debian/Ubuntu)"
    echo "         yum install inotify-tools (CentOS/RHEL)"
    echo ""
    echo "或者使用手动同步:"
    echo "  ./sync.sh"
    exit 1
fi
