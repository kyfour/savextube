#!/bin/bash

# SaveXTube GitHub Actions 快速设置脚本
# 此脚本帮助您快速配置并推送代码到 GitHub

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   SaveXTube GitHub Actions 快速设置       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# 检查是否在 Git 仓库中
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ 错误: 当前目录不是 Git 仓库${NC}"
    echo -e "${YELLOW}正在初始化 Git 仓库...${NC}"
    git init
    echo -e "${GREEN}✅ Git 仓库已初始化${NC}"
fi

echo ""
echo -e "${YELLOW}[1/5] 配置 Git 分支${NC}"
# 重命名分支为 main
if git rev-parse --verify master >/dev/null 2>&1; then
    git branch -m master main
    echo -e "${GREEN}✅ 分支已重命名为 'main'${NC}"
else
    echo -e "${GREEN}✅ 当前分支: $(git branch --show-current)${NC}"
fi

echo ""
echo -e "${YELLOW}[2/5] 检查 GitHub 远程仓库${NC}"
if git remote | grep -q "origin"; then
    REMOTE_URL=$(git remote get-url origin)
    echo -e "${GREEN}✅ 已配置远程仓库: ${REMOTE_URL}${NC}"
else
    echo -e "${RED}⚠️  未配置远程仓库${NC}"
    echo ""
    echo -e "${BLUE}请输入您的 GitHub 仓库 URL:${NC}"
    echo -e "${YELLOW}格式示例: https://github.com/您的用户名/savextube.git${NC}"
    read -p "仓库 URL: " REPO_URL
    
    if [ -n "$REPO_URL" ]; then
        git remote add origin "$REPO_URL"
        echo -e "${GREEN}✅ 远程仓库已配置: ${REPO_URL}${NC}"
    else
        echo -e "${RED}❌ 未输入仓库 URL，跳过此步骤${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}[3/5] 添加文件到 Git${NC}"
git add .
echo -e "${GREEN}✅ 文件已添加${NC}"

echo ""
echo -e "${YELLOW}[4/5] 提交更改${NC}"
git commit -m "Add GitHub Actions workflow for Docker build and push" || echo -e "${YELLOW}⚠️  没有新的更改需要提交${NC}"

echo ""
echo -e "${YELLOW}[5/5] 推送到 GitHub${NC}"
if git remote | grep -q "origin"; then
    echo -e "${BLUE}准备推送到远程仓库...${NC}"
    echo ""
    read -p "是否现在推送代码到 GitHub? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push -u origin main
        echo -e "${GREEN}✅ 代码已推送到 GitHub${NC}"
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           🎉 设置完成！                    ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}📋 下一步操作:${NC}"
        echo ""
        echo -e "${YELLOW}1. 获取 DockerHub Access Token${NC}"
        echo -e "   访问: https://hub.docker.com/"
        echo -e "   进入 Account Settings → Security → New Access Token"
        echo ""
        echo -e "${YELLOW}2. 在 GitHub 配置 Secret${NC}"
        echo -e "   访问您的仓库 Settings → Secrets and variables → Actions"
        echo -e "   添加 Secret: Name = DOCKERHUB_TOKEN, Value = [您的 Token]"
        echo ""
        echo -e "${YELLOW}3. 触发构建${NC}"
        echo -e "   方式 1: 进入 GitHub Actions 标签，手动运行 workflow"
        echo -e "   方式 2: 推送新的提交会自动触发构建"
        echo ""
        echo -e "${BLUE}📖 详细说明请查看:${NC}"
        echo -e "   github_actions_setup_guide.md"
    else
        echo -e "${YELLOW}⏸️  已取消推送，您可以稍后手动推送:${NC}"
        echo -e "   ${BLUE}git push -u origin main${NC}"
    fi
else
    echo -e "${RED}❌ 未配置远程仓库，无法推送${NC}"
    echo -e "${YELLOW}请先配置远程仓库:${NC}"
    echo -e "   ${BLUE}git remote add origin https://github.com/您的用户名/savextube.git${NC}"
fi

echo ""
echo -e "${GREEN}感谢使用 SaveXTube！${NC}"
