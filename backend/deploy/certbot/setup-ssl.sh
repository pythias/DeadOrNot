#!/bin/bash

# Let's Encrypt SSL 证书获取脚本
# 用于为 DeadOrNot 后端配置 SSL 证书

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
    log_error "用法: $0 <domain> [email]"
    log_info "示例: $0 example.com admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-""}

log_info "开始为域名 $DOMAIN 配置 SSL 证书..."
log_info "注意：如需申请通配符证书（如 *.xiaodao.fun），请使用 setup-wildcard-ssl.sh 脚本"

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
        # CentOS 安装 certbot
        yum install -y epel-release
        yum install -y certbot python3-certbot-nginx
    else
        # Ubuntu/Debian 安装 certbot
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    log_info "certbot 安装完成"
else
    log_info "certbot 已安装"
fi

# 创建 certbot webroot 目录
WEBROOT="/var/www/certbot"
mkdir -p $WEBROOT
chown -R $NGINX_USER:$NGINX_USER $WEBROOT

# 检查域名解析
log_info "检查域名解析..."
if ! nslookup $DOMAIN &> /dev/null; then
    log_warn "无法解析域名 $DOMAIN，请确保域名已正确解析到服务器 IP"
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查 nginx 配置
NGINX_CONF="/etc/nginx/conf.d/deadornot.conf"
if [ ! -f "$NGINX_CONF" ]; then
    log_error "Nginx 配置文件不存在: $NGINX_CONF"
    log_info "请先运行部署脚本配置 nginx"
    exit 1
fi

# 测试 nginx 配置
log_info "测试 Nginx 配置..."
if ! nginx -t; then
    log_error "Nginx 配置测试失败"
    exit 1
fi

# 重载 nginx（不重启，因为证书还未配置）
log_info "重载 Nginx 配置..."
systemctl reload nginx || service nginx reload

# 获取 SSL 证书
log_info "开始获取 SSL 证书..."

CERTBOT_OPTS="--nginx --non-interactive --agree-tos --redirect"
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

if certbot $CERTBOT_OPTS -d $DOMAIN; then
    log_info "SSL 证书获取成功！"
else
    log_error "SSL 证书获取失败"
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

# 重启 nginx
log_info "重启 Nginx..."
systemctl restart nginx || service nginx restart

log_info "SSL 证书配置完成！"
log_info "证书路径: /etc/letsencrypt/live/$DOMAIN/"
log_info ""
log_info "证书将在到期前自动续期"
log_info "手动续期命令: certbot renew"
log_info "查看证书信息: certbot certificates"
