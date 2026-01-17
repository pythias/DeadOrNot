#!/bin/bash

# DeadOrNot Backend 部署脚本
# 用于在阿里云服务器上部署应用

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量（根据实际情况修改）
APP_NAME="deadornot-backend"
DEPLOY_DIR="/opt/deadornot/backend"
SUPERVISOR_CONF_FILE="$DEPLOY_DIR/deploy/supervisor.conf"

# 检测系统类型并设置相应变量
detect_system() {
    if [ -f /etc/redhat-release ]; then
        # CentOS/RHEL/Alibaba Cloud Linux
        SYSTEM_TYPE="centos"
        SERVICE_USER="www"
        SUPERVISOR_CONF_DIR="/etc/supervisord.d"
        SUPERVISOR_SERVICE="supervisord"
        # 如果 www 用户不存在，使用 nginx 或创建 www 用户
        if ! id -u www &>/dev/null; then
            if id -u nginx &>/dev/null; then
                SERVICE_USER="nginx"
            else
                useradd -r -s /sbin/nologin www 2>/dev/null || true
            fi
        fi
    elif [ -f /etc/debian_version ]; then
        # Ubuntu/Debian
        SYSTEM_TYPE="debian"
        SERVICE_USER="www-data"
        SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d"
        SUPERVISOR_SERVICE="supervisor"
    else
        # 默认使用 CentOS 配置
        SYSTEM_TYPE="centos"
        SERVICE_USER="www"
        SUPERVISOR_CONF_DIR="/etc/supervisord.d"
        SUPERVISOR_SERVICE="supervisord"
    fi
    
    log_info "检测到系统类型: $SYSTEM_TYPE"
    log_info "使用服务用户: $SERVICE_USER"
}

# 初始化系统检测
detect_system

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

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# 检查 Go 环境
check_go() {
    log_info "检查 Go 环境..."
    if ! command -v go &> /dev/null; then
        log_error "Go 未安装，请先安装 Go 1.21 或更高版本"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}')
    log_info "Go 版本: $GO_VERSION"
}

# 编译应用
build_app() {
    log_info "开始编译应用..."
    cd "$(dirname "$0")/.."
    
    # 使用 Makefile 编译
    if [ -f Makefile ]; then
        make build
    else
        log_warn "Makefile 不存在，使用 go build 直接编译..."
        mkdir -p bin
        GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bin/$APP_NAME ./main.go
    fi
    
    if [ ! -f "bin/$APP_NAME" ]; then
        log_error "编译失败，二进制文件不存在"
        exit 1
    fi
    
    log_info "编译完成"
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    mkdir -p "$DEPLOY_DIR/bin"
    mkdir -p "$DEPLOY_DIR/config"
    mkdir -p "$DEPLOY_DIR/logs"
    mkdir -p "$DEPLOY_DIR/deploy"
    
    log_info "目录创建完成"
}

# 复制文件
copy_files() {
    log_info "复制文件到部署目录..."
    
    # 复制二进制文件
    cp bin/$APP_NAME "$DEPLOY_DIR/bin/"
    chmod +x "$DEPLOY_DIR/bin/$APP_NAME"
    
    # 复制 Supervisor 配置
    if [ -f deploy/supervisor.conf ]; then
        cp deploy/supervisor.conf "$DEPLOY_DIR/deploy/"
    fi
    
    # 复制环境变量示例（如果不存在）
    if [ ! -f "$DEPLOY_DIR/config/.env" ] && [ -f deploy/env.example ]; then
        log_warn ".env 文件不存在，请从 env.example 创建并配置"
        cp deploy/env.example "$DEPLOY_DIR/config/.env.example"
    fi
    
    log_info "文件复制完成"
}

# 设置权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 设置目录所有者
    chown -R $SERVICE_USER:$SERVICE_USER "$DEPLOY_DIR"
    
    # 设置目录权限
    chmod 755 "$DEPLOY_DIR"
    chmod 755 "$DEPLOY_DIR/bin"
    chmod 755 "$DEPLOY_DIR/logs"
    chmod 750 "$DEPLOY_DIR/config"
    
    # 设置文件权限
    chmod 750 "$DEPLOY_DIR/bin/$APP_NAME"
    chmod 640 "$DEPLOY_DIR/config/.env" 2>/dev/null || true
    
    log_info "权限设置完成"
}

# 配置 Supervisor
setup_supervisor() {
    log_info "配置 Supervisor..."
    
    # 检查 Supervisor 是否安装
    if ! command -v supervisorctl &> /dev/null; then
        log_warn "Supervisor 未安装，跳过配置"
        if [ "$SYSTEM_TYPE" = "centos" ]; then
            log_info "安装 Supervisor (CentOS): yum install -y epel-release && yum install -y supervisor"
        else
            log_info "安装 Supervisor (Debian/Ubuntu): apt-get install supervisor"
        fi
        return
    fi
    
    # 创建 Supervisor 配置目录（如果不存在）
    mkdir -p "$SUPERVISOR_CONF_DIR"
    
    # 创建 Supervisor 配置链接
    if [ -f "$SUPERVISOR_CONF_FILE" ]; then
        ln -sf "$SUPERVISOR_CONF_FILE" "$SUPERVISOR_CONF_DIR/$APP_NAME.ini"
        log_info "Supervisor 配置链接已创建: $SUPERVISOR_CONF_DIR/$APP_NAME.ini"
    else
        log_warn "Supervisor 配置文件不存在: $SUPERVISOR_CONF_FILE"
    fi
    
    # 重载 Supervisor 配置
    supervisorctl reread
    supervisorctl update
    
    # CentOS 需要重启 supervisord 服务
    if [ "$SYSTEM_TYPE" = "centos" ]; then
        systemctl restart supervisord 2>/dev/null || true
    fi
    
    log_info "Supervisor 配置完成"
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    if command -v supervisorctl &> /dev/null; then
        supervisorctl start $APP_NAME
        sleep 2
        
        # 检查服务状态
        if supervisorctl status $APP_NAME 2>/dev/null | grep -q RUNNING; then
            log_info "服务启动成功"
        else
            log_error "服务启动失败，请检查日志: $DEPLOY_DIR/logs/error.log"
            log_info "查看详细状态: supervisorctl status $APP_NAME"
            exit 1
        fi
    else
        log_warn "Supervisor 未安装，请手动启动服务"
    fi
}

# 主函数
main() {
    log_info "开始部署 $APP_NAME..."
    
    check_root
    check_go
    build_app
    create_directories
    copy_files
    set_permissions
    setup_supervisor
    start_service
    
    log_info "部署完成！"
    log_info "应用目录: $DEPLOY_DIR"
    log_info "日志目录: $DEPLOY_DIR/logs"
    log_info "配置文件: $DEPLOY_DIR/config/.env"
    log_info ""
    log_info "常用命令:"
    log_info "  查看状态: supervisorctl status $APP_NAME"
    log_info "  查看日志: tail -f $DEPLOY_DIR/logs/app.log"
    log_info "  重启服务: supervisorctl restart $APP_NAME"
    log_info "  停止服务: supervisorctl stop $APP_NAME"
    if [ "$SYSTEM_TYPE" = "centos" ]; then
        log_info "  重启 Supervisor: systemctl restart supervisord"
    fi
}

# 执行主函数
main
