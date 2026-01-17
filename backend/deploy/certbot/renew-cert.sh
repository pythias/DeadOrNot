#!/bin/bash

# Let's Encrypt 证书续期脚本
# 可以配置为 cron 任务自动运行

set -e

# 日志文件
LOG_FILE="/var/log/certbot-renew.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# 日志函数
log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

log "开始证书续期检查..."

# 检查 certbot 是否安装
if ! command -v certbot &> /dev/null; then
    log "错误: certbot 未安装"
    exit 1
fi

# 续期证书
if certbot renew --quiet --no-self-upgrade; then
    log "证书续期成功"
    
    # 重载 nginx 配置
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        log "Nginx 配置已重载"
    elif systemctl is-active --quiet httpd; then
        systemctl reload httpd
        log "Apache 配置已重载"
    else
        log "警告: 未找到运行中的 web 服务器"
    fi
    
    log "证书续期完成"
    exit 0
else
    log "错误: 证书续期失败"
    exit 1
fi
