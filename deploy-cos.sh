#!/usr/bin/env bash
# ==============================================================================
# 腾讯云 COS 静态网站部署脚本
# ==============================================================================
# 前置条件：
#   1. 已安装腾讯云 COSCMD 工具
#      pip install coscmd  (或 brew install coscmd)
#
#   2. 已配置 COSCMD（取你的 SecretId / SecretKey / Region / Bucket）
#      coscmd config -a <SecretId> -s <SecretKey> -b <Bucket-APPID> -r <Region>
#      示例 Region：ap-shanghai / ap-beijing / ap-guangzhou
#
#   3. 已在 COS 控制台开启"静态网站"功能：
#      - 索引文档：index.html
#      - 错误文档：404.html
#
# 使用：
#   chmod +x deploy-cos.sh
#   ./deploy-cos.sh
# ==============================================================================

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置区（可改）
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_PREFIX="/"            # COS 上的前缀路径，"/"表示根目录
EXCLUDE_PATTERNS=(           # 不上传的文件
  "*.sh"
  "*.md"
  "nginx.conf"
  ".DS_Store"
  ".git*"
  "deploy-cos.sh"
)

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  腾讯云 COS 静态站点部署${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# 检查 coscmd
if ! command -v coscmd >/dev/null 2>&1; then
  echo -e "${RED}✗ 未检测到 coscmd 工具${NC}"
  echo "  请先安装：pip install coscmd"
  exit 1
fi
echo -e "${GREEN}✓${NC} coscmd 已安装：$(coscmd --version 2>&1 | head -1)"

# 检查配置
CONFIG_FILE="${HOME}/.cos.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}✗ 未发现 ${CONFIG_FILE}${NC}"
  echo "  请先运行：coscmd config -a <SecretId> -s <SecretKey> -b <Bucket-APPID> -r <Region>"
  exit 1
fi
echo -e "${GREEN}✓${NC} 配置文件存在：${CONFIG_FILE}"

# 检查源文件
if [[ ! -f "${SOURCE_DIR}/index.html" ]]; then
  echo -e "${RED}✗ 未找到 index.html${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} 源目录：${SOURCE_DIR}"
echo ""

# 列出将要上传的文件
echo -e "${YELLOW}将上传以下文件：${NC}"
cd "${SOURCE_DIR}"
FILES_TO_UPLOAD=()
while IFS= read -r -d '' file; do
  rel="${file#./}"
  skip=false
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$rel" == $pattern ]]; then
      skip=true
      break
    fi
  done
  if [[ "$skip" == false ]]; then
    FILES_TO_UPLOAD+=("$rel")
    echo "  • $rel"
  fi
done < <(find . -type f -not -path './.*' -print0)

if [[ ${#FILES_TO_UPLOAD[@]} -eq 0 ]]; then
  echo -e "${RED}✗ 没有可上传的文件${NC}"
  exit 1
fi
echo ""

# 二次确认
read -p "$(echo -e ${YELLOW}确认上传以上 ${#FILES_TO_UPLOAD[@]} 个文件到 COS？[y/N] ${NC})" -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "已取消"
  exit 0
fi

# 开始上传
echo ""
echo -e "${BLUE}━━ 开始上传 ━━${NC}"
for file in "${FILES_TO_UPLOAD[@]}"; do
  echo -e "${BLUE}↑${NC} ${file}"
  coscmd upload "${file}" "${REMOTE_PREFIX}${file}"
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ 部署完成${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}访问地址（在 COS 控制台→静态网站 里查看）：${NC}"
echo "  https://<Bucket>.cos-website.<Region>.myqcloud.com"
echo ""
echo -e "${YELLOW}如配了自定义域名 + CDN：${NC}"
echo "  https://your-domain.com"
echo ""
echo -e "${YELLOW}注意：${NC}"
echo "  - 如开启了 CDN，需到腾讯云 CDN 控制台刷新缓存"
echo "  - 命令：腾讯云控制台 → CDN → 刷新预热 → 提交 /index.html"
