#!/bin/bash

# Let's Encrypt 通配符证书获取脚本
# 用于为 *.xiaodao.fun 申请通配符 SSL 证书
# 注意：通配符证书需要使用 DNS-01 验证方式

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
if [ $# -lt 1 ]; then
    log_error "用法: $0 <base-domain> [email]"
    log_info "示例: $0 xiaodao.fun admin@example.com"
    log_info "这将申请 *.xiaodao.fun 和 xiaodao.fun 的证书"
    exit 1
fi

BASE_DOMAIN=$1
EMAIL=${2:-""}
WILDCARD_DOMAIN="*.$BASE_DOMAIN"

log_info "开始为域名 $BASE_DOMAIN 和 $WILDCARD_DOMAIN 配置通配符 SSL 证书..."
log_warn "注意：通配符证书需要使用 DNS-01 验证，需要手动添加 DNS TXT 记录"

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    log_error "请使用 root 权限运行此脚本"
    exit 1
fi

# 检测系统类型
if [ -f /etc/redhat-release ]; then
    SYSTEM_TYPE="centos"
    NGINX_USER="nginx"
else
    SYSTEM_TYPE="debian"
    NGINX_USER="www-data"
fi

# 检查 certbot 是否安装
if ! command -v certbot &> /dev/null; then
    log_info "certbot 未安装，开始安装..."
    
    if [ "$SYSTEM_TYPE" = "centos" ]; then
        yum install -y epel-release
        yum install -y certbot python3-certbot-dns-* || yum install -y certbot
    else
        apt-get update
        apt-get install -y certbot python3-certbot-dns-* || apt-get install -y certbot
    fi
    
    log_info "certbot 安装完成"
else
    log_info "certbot 已安装"
fi

# 检查 DNS 插件（可选，用于自动 DNS 验证）
log_info "检查可用的 DNS 插件..."

# 通配符证书申请（使用手动 DNS 验证）
log_info "开始申请通配符证书..."
log_warn "通配符证书需要使用 DNS-01 验证方式"
log_info "certbot 会提示你添加 DNS TXT 记录，请按照提示操作"

CERTBOT_OPTS="--manual --preferred-challenges dns --non-interactive --agree-tos"
if [ -n "$EMAIL" ]; then
    CERTBOT_OPTS="$CERTBOT_OPTS --email $EMAIL"
else
    CERTBOT_OPTS="$CERTBOT_OPTS --register-unsafely-without-email"
fi

# 首次获取证书（可以使用 --test-cert 进行测试）
if [ "$TEST_MODE" = "true" ]; then
    log_warn "使用测试模式获取证书（不会生成真实证书）"
    CERTBOT_OPTS="$CERTBOT_OPTS --test-cert"
fi

log_info "运行 certbot 申请证书..."
log_info "请按照提示添加 DNS TXT 记录："
log_info "  - 记录类型: TXT"
log_info "  - 记录名称: _acme-challenge.$BASE_DOMAIN"
log_info "  - 记录值: certbot 会显示的值"

# 申请通配符证书（包含根域名和通配符）
if certbot certonly $CERTBOT_OPTS -d "$BASE_DOMAIN" -d "$WILDCARD_DOMAIN"; then
    log_info "通配符 SSL 证书获取成功！"
    log_info "证书路径: /etc/letsencrypt/live/$BASE_DOMAIN/"
else
    log_error "SSL 证书获取失败"
    log_info "提示："
    log_info "1. 确保域名 DNS 解析正确"
    log_info "2. 按照提示添加 DNS TXT 记录"
    log_info "3. 等待 DNS 记录生效（通常几分钟）"
    log_info "4. 如果使用测试模式，设置 TEST_MODE=true"
    exit 1
fi

# 配置自动续期
log_info "配置证书自动续期..."

# 测试续期
if certbot renew --dry-run; then
    log_info "证书自动续期测试成功"
else
    log_warn "证书自动续期测试失败，请手动检查"
fi

log_info "通配符 SSL 证书配置完成！"
log_info "证书路径: /etc/letsencrypt/live/$BASE_DOMAIN/"
log_info ""
log_info "在 Nginx 配置中使用："
log_info "  ssl_certificate /etc/letsencrypt/live/$BASE_DOMAIN/fullchain.pem;"
log_info "  ssl_certificate_key /etc/letsencrypt/live/$BASE_DOMAIN/privkey.pem;"
log_info ""
log_info "此证书可用于："
log_info "  - $BASE_DOMAIN"
log_info "  - $WILDCARD_DOMAIN (所有子域名)"
log_info ""
log_info "证书将在到期前自动续期"
log_info "手动续期命令: certbot renew"
