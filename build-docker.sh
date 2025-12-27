#!/bin/bash

# SaveXTube Docker 镜像构建和推送脚本
# 作者: SaveXTube
# 仓库: kyfour/savetube

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
DOCKER_USERNAME="kyfour"
IMAGE_NAME="savetube"
FULL_IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}"
VERSION="${1:-latest}"  # 从参数获取版本，默认为 latest

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   SaveXTube Docker 镜像构建和推送工具      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# 检查 Docker 是否安装
echo -e "${YELLOW}[1/7] 检查 Docker 安装...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ 错误: Docker 未安装或不在 PATH 中${NC}"
    echo -e "${YELLOW}请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop/${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker 已安装: $(docker --version)${NC}"
echo ""

# 检查 Docker 是否运行
echo -e "${YELLOW}[2/7] 检查 Docker 服务状态...${NC}"
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ 错误: Docker 服务未运行${NC}"
    echo -e "${YELLOW}请启动 Docker Desktop${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker 服务正常运行${NC}"
echo ""

# 检查 Docker 登录状态
echo -e "${YELLOW}[3/7] 检查 DockerHub 登录状态...${NC}"
if ! docker info 2>&1 | grep -q "Username"; then
    echo -e "${YELLOW}⚠️  未登录 DockerHub，开始登录...${NC}"
    docker login
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 登录失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ 已登录 DockerHub${NC}"
fi
echo ""

# 显示构建信息
echo -e "${YELLOW}[4/7] 构建配置信息:${NC}"
echo -e "  📦 镜像名称: ${BLUE}${FULL_IMAGE}${NC}"
echo -e "  🏷️  版本标签: ${BLUE}${VERSION}${NC}"
echo -e "  🖥️  平台支持: ${BLUE}linux/amd64, linux/arm64${NC}"
echo ""

# 询问是否继续
read -p "是否继续构建? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}已取消构建${NC}"
    exit 0
fi

# 创建 buildx 构建器（如果不存在）
echo -e "${YELLOW}[5/7] 准备 buildx 构建器...${NC}"
if ! docker buildx ls | grep -q "mybuilder"; then
    echo -e "${BLUE}创建新的 buildx 构建器...${NC}"
    docker buildx create --name mybuilder --use
    docker buildx inspect --bootstrap
else
    echo -e "${BLUE}使用现有的 buildx 构建器...${NC}"
    docker buildx use mybuilder
fi
echo -e "${GREEN}✅ buildx 构建器已就绪${NC}"
echo ""

# 开始构建
echo -e "${YELLOW}[6/7] 开始构建多平台镜像...${NC}"
echo -e "${BLUE}这可能需要几分钟时间，请耐心等待...${NC}"
echo ""

BUILD_START=$(date +%s)

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ${FULL_IMAGE}:${VERSION} \
  -t ${FULL_IMAGE}:latest \
  --push \
  .

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ 构建成功！${NC}"
    echo -e "${GREEN}⏱️  构建耗时: ${BUILD_TIME} 秒${NC}"
else
    echo ""
    echo -e "${RED}❌ 构建失败${NC}"
    exit 1
fi
echo ""

# 验证推送结果
echo -e "${YELLOW}[7/7] 验证镜像推送...${NC}"
echo -e "${BLUE}正在从 DockerHub 拉取镜像进行验证...${NC}"

# 删除本地镜像（如果存在）
docker rmi ${FULL_IMAGE}:${VERSION} 2>/dev/null || true

# 拉取验证
if docker pull ${FULL_IMAGE}:${VERSION} &> /dev/null; then
    echo -e "${GREEN}✅ 镜像已成功推送到 DockerHub${NC}"
else
    echo -e "${RED}❌ 镜像拉取失败，请检查 DockerHub${NC}"
    exit 1
fi
echo ""

# 完成
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 构建和推送完成！              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📦 镜像信息:${NC}"
echo -e "  • 名称: ${FULL_IMAGE}"
echo -e "  • 标签: ${VERSION}, latest"
echo -e "  • 平台: linux/amd64, linux/arm64"
echo ""
echo -e "${BLUE}🔗 访问地址:${NC}"
echo -e "  • DockerHub: https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}"
echo ""
echo -e "${BLUE}🚀 使用方法:${NC}"
echo -e "  docker pull ${FULL_IMAGE}:${VERSION}"
echo -e "  docker run -d -p 8530:8530 ${FULL_IMAGE}:${VERSION}"
echo ""
echo -e "${GREEN}感谢使用 SaveXTube！${NC}"
