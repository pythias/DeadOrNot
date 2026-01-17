#!/bin/bash

# Supervisor 启动脚本
# 用于加载环境变量并启动应用

# 加载环境变量
if [ -f /opt/deadornot/backend/config/.env ]; then
    export $(cat /opt/deadornot/backend/config/.env | grep -v '^#' | xargs)
fi

# 切换到工作目录
cd /opt/deadornot/backend

# 启动应用
exec /opt/deadornot/backend/bin/deadornot-backend
