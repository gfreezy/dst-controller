#!/bin/bash

# 饥荒联机版 Mod 同步脚本
# 用于自动同步 mod 文件到游戏 mods 目录

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录（即 mod 源目录）
MOD_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_NAME="enhanced_controller"

# 检测操作系统并设置目标目录
detect_dst_mods_dir() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - 优先检查 Steam 安装目录
        STEAM_MODS_DIR="$HOME/Library/Application Support/Steam/steamapps/common/Don't Starve Together/dontstarve_steam.app/Contents/mods"
        KLEI_MODS_DIR="$HOME/Documents/Klei/DoNotStarveTogether/mods"

        if [ -d "$STEAM_MODS_DIR" ]; then
            DST_MODS_DIR="$STEAM_MODS_DIR"
        elif [ -d "$KLEI_MODS_DIR" ]; then
            DST_MODS_DIR="$KLEI_MODS_DIR"
        else
            DST_MODS_DIR="$KLEI_MODS_DIR"  # 默认使用 Klei 目录
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        DST_MODS_DIR="$HOME/.klei/DoNotStarveTogether/mods"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows (Git Bash or Cygwin)
        DST_MODS_DIR="$USERPROFILE/Documents/Klei/DoNotStarveTogether/mods"
    else
        echo -e "${RED}错误: 无法识别的操作系统 $OSTYPE${NC}"
        exit 1
    fi
}

# 检查配置文件
if [ -f "$MOD_SOURCE_DIR/sync.config" ]; then
    source "$MOD_SOURCE_DIR/sync.config"
    echo -e "${GREEN}已加载自定义配置${NC}"
fi

# 检测目标目录
detect_dst_mods_dir

# 允许通过命令行参数覆盖目标目录
if [ -n "$1" ]; then
    DST_MODS_DIR="$1"
fi

MOD_TARGET_DIR="$DST_MODS_DIR/$MOD_NAME"

echo "========================================"
echo "饥荒联机版 Mod 同步工具"
echo "========================================"
echo -e "源目录: ${YELLOW}$MOD_SOURCE_DIR${NC}"
echo -e "目标目录: ${YELLOW}$MOD_TARGET_DIR${NC}"
echo ""

# 检查源目录
if [ ! -f "$MOD_SOURCE_DIR/modinfo.lua" ]; then
    echo -e "${RED}错误: 未找到 modinfo.lua，请确认当前目录是 mod 源目录${NC}"
    exit 1
fi

# 检查目标目录是否存在
if [ ! -d "$DST_MODS_DIR" ]; then
    echo -e "${RED}错误: 饥荒 mods 目录不存在: $DST_MODS_DIR${NC}"
    echo ""
    echo "请手动指定目录："
    echo "  ./sync.sh /path/to/mods"
    echo ""
    echo "或创建配置文件 sync.config："
    echo "  DST_MODS_DIR=\"/path/to/mods\""
    exit 1
fi

# 创建目标目录
if [ ! -d "$MOD_TARGET_DIR" ]; then
    echo -e "${YELLOW}创建目标目录...${NC}"
    mkdir -p "$MOD_TARGET_DIR"
fi

# 定义需要同步的文件
FILES_TO_SYNC=(
    "modinfo.lua"
    "modmain.lua"
    "modicon.xml"
)

# 可选文件（如果存在则同步）
OPTIONAL_FILES=(
    "modicon.tex"
    "images"
)

# 排除的目录（不同步这些目录）
EXCLUDED_DIRS=(
    "scripts"
    ".git"
    ".vscode"
    ".claude"
    "node_modules"
)

# 同步文件
echo -e "${GREEN}开始同步文件...${NC}"
for file in "${FILES_TO_SYNC[@]}"; do
    if [ -e "$MOD_SOURCE_DIR/$file" ]; then
        echo "  复制: $file"
        cp -r "$MOD_SOURCE_DIR/$file" "$MOD_TARGET_DIR/"
    else
        echo -e "  ${YELLOW}跳过: $file (不存在)${NC}"
    fi
done

# 同步可选文件
for file in "${OPTIONAL_FILES[@]}"; do
    if [ -e "$MOD_SOURCE_DIR/$file" ]; then
        echo "  复制: $file"
        cp -r "$MOD_SOURCE_DIR/$file" "$MOD_TARGET_DIR/"
    fi
done

# 显示排除的目录
echo ""
echo -e "${YELLOW}已排除以下目录:${NC}"
for dir in "${EXCLUDED_DIRS[@]}"; do
    echo "  - $dir"
done

echo ""
echo -e "${GREEN}✓ 同步完成！${NC}"
echo ""
echo "下一步:"
echo "  1. 启动饥荒联机版"
echo "  2. 在主菜单选择 'Mods'"
echo "  3. 启用 'Enhanced Controller'"
echo "  4. 重启游戏"
echo ""
