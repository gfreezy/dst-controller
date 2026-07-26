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
PUBLISH_DIR="$MOD_SOURCE_DIR/publish"

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
echo -e "发布目录: ${YELLOW}$PUBLISH_DIR${NC}"
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

# macOS may protect another application's bundle through App Management even
# when POSIX ownership looks writable. Stop before rsync --delete can leave a
# partially-deployed mod behind.
if [ ! -w "$MOD_TARGET_DIR" ]; then
    echo -e "${RED}错误: 目标目录受系统保护，当前进程不可写:${NC}"
    echo "  $MOD_TARGET_DIR"
    echo ""
    echo "请在 macOS 系统设置 > 隐私与安全性 > App 管理中允许当前终端/Codex，"
    echo "或通过 Finder 将模组复制到该目录后再重试。"
    exit 1
fi

# 只同步发布所需内容，避免把 scripts-raw、测试、文档和开发配置上传到创意工坊。
# /*** 会同时匹配目录本身及其全部子项。
INCLUDED_PATTERNS=(
    "/modinfo.lua"
    "/modmain.lua"
    "/modicon.xml"
    "/modicon.tex"
    "/preview.jpg"
    "/preview.jpeg"
    "/preview.png"
    "/scripts/***"
    "/images/***"
    "/anim/***"
    "/sound/***"
    "/fonts/***"
    "/bigportraits/***"
    "/minimap/***"
    "/portraits/***"
)

INCLUDE_ARGS=()
for pattern in "${INCLUDED_PATTERNS[@]}"; do
    INCLUDE_ARGS+=(--include="$pattern")
done

# 先在源码目录生成一份可直接交给 Steam Mod Uploader 的发布目录。
# --delete-excluded 会清理发布目录中以前残留的开发文件。
echo -e "${GREEN}生成发布目录...${NC}"
mkdir -p "$PUBLISH_DIR"
rsync -av --delete --delete-excluded --prune-empty-dirs \
    --exclude=".DS_Store" "${INCLUDE_ARGS[@]}" --exclude="*" \
    "$MOD_SOURCE_DIR/" "$PUBLISH_DIR/"

# 游戏目录与发布目录保持完全一致。
echo ""
echo -e "${GREEN}同步到游戏 Mod 目录...${NC}"
rsync -av --delete "$PUBLISH_DIR/" "$MOD_TARGET_DIR/"

# 显示发布白名单
echo ""
echo -e "${YELLOW}只同步以下发布内容:${NC}"
for pattern in "${INCLUDED_PATTERNS[@]}"; do
    echo "  - $pattern"
done

echo ""
echo -e "${GREEN}✓ 同步完成！${NC}"
echo ""
