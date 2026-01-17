# DeadOrNot Backend 部署文档

本文档介绍如何在阿里云 CentOS 服务器上部署 DeadOrNot 后端应用。

> **注意**: 本文档主要针对 CentOS 7+ / Alibaba Cloud Linux 2+ 系统。如果使用 Ubuntu/Debian，部分命令需要相应调整。

## 快速开始（CentOS）

```bash
# 1. 安装依赖
sudo yum install -y epel-release
sudo yum install -y supervisor mariadb-server mariadb

# 2. 安装 Go
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# 3. 启动服务
sudo systemctl enable supervisord mariadb
sudo systemctl start supervisord mariadb

# 4. 运行部署脚本
sudo ./deploy/deploy.sh
```

## 目录

- [系统要求](#系统要求)
- [准备工作](#准备工作)
- [安装依赖](#安装依赖)
- [配置环境](#配置环境)
- [部署应用](#部署应用)
- [服务管理](#服务管理)
- [维护和监控](#维护和监控)
- [常见问题](#常见问题)

## 系统要求

### 操作系统
- **CentOS 7+** / Alibaba Cloud Linux 2+（推荐）
- Ubuntu 20.04+ / Debian 11+（也支持）

### 软件要求
- Go 1.21 或更高版本
- MySQL 5.7+ 或 MySQL 8.0+ / MariaDB 10.3+
- Supervisor（进程管理）

### 硬件要求
- CPU: 1 核或以上
- 内存: 512MB 或以上
- 磁盘: 10GB 或以上

## 准备工作

### 1. 创建数据库

在 MySQL 中创建数据库和用户：

```sql
CREATE DATABASE deadornot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'deadornot'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON deadornot.* TO 'deadornot'@'localhost';
FLUSH PRIVILEGES;
```

### 2. 准备 APNs Key 文件

如果使用 iOS 推送通知，需要准备 APNs Key 文件（.p8）：

1. 从 Apple Developer 下载 APNs Key
2. 将文件上传到服务器，建议放在 `/opt/deadornot/backend/config/` 目录
3. 设置正确的文件权限：`chmod 600 /opt/deadornot/backend/config/AuthKey_*.p8`

## 安装依赖

### 1. 安装 Go（CentOS）

```bash
# 下载 Go
cd /tmp
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz

# 安装到 /usr/local
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz

# 配置环境变量
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
source ~/.bashrc

# 验证安装
go version
```

### 2. 安装 Supervisor（CentOS）

```bash
# CentOS 7/8
sudo yum install -y epel-release
sudo yum install -y supervisor

# 启动并设置开机自启
sudo systemctl enable supervisord
sudo systemctl start supervisord

# 验证服务状态
sudo systemctl status supervisord
```

**注意**: CentOS 中 Supervisor 的服务名是 `supervisord`（不是 `supervisor`）

### 3. 安装 MySQL（CentOS）

```bash
# CentOS 7
sudo yum install -y mariadb-server mariadb
sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo mysql_secure_installation

# CentOS 8+ 或使用 MySQL 8.0
# 如果使用 MySQL 官方仓库
sudo yum install -y mysql-server
sudo systemctl enable mysqld
sudo systemctl start mysqld
sudo mysql_secure_installation
```

**注意**: CentOS 7 默认使用 MariaDB，CentOS 8+ 可以使用 MySQL 8.0

### 4. 安装 Nginx（CentOS）

```bash
# CentOS 7/8
sudo yum install -y nginx

# 启动并设置开机自启
sudo systemctl enable nginx
sudo systemctl start nginx

# 验证服务状态
sudo systemctl status nginx
```

**注意**: Nginx 会在部署脚本中自动安装和配置，也可以手动安装

## 配置环境

### 1. 创建部署目录

```bash
# 创建目录结构
sudo mkdir -p /opt/deadornot/backend/{bin,config,logs,deploy}

# 设置所有者（CentOS 通常使用 www 或 nginx 用户）
sudo chown -R www:www /opt/deadornot
# 或者如果没有 www 用户，创建并设置
sudo useradd -r -s /sbin/nologin www 2>/dev/null || true
sudo chown -R www:www /opt/deadornot
```

### 2. 配置环境变量

```bash
cd /opt/deadornot/backend/config
cp /path/to/deploy/env.example .env
nano .env  # 或使用其他编辑器
```

编辑 `.env` 文件，填写以下配置：

- **数据库配置**: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
- **APNs 配置**: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_PATH, APNS_PRODUCTION
- **邮件配置**: EMAIL_PROVIDER, ALIYUN_ACCESS_KEY, ALIYUN_ACCESS_SECRET, FROM_EMAIL
- **服务器配置**: PORT

### 3. 设置文件权限

```bash
# CentOS 使用 www 用户（或 nginx）
sudo chmod 640 /opt/deadornot/backend/config/.env
sudo chown www:www /opt/deadornot/backend/config/.env

# 如果 www 用户不存在，创建它
sudo useradd -r -s /sbin/nologin www 2>/dev/null || true
```

## 部署应用

### 方式一：使用部署脚本（推荐）

```bash
# 1. 将代码上传到服务器
cd /path/to/backend

# 2. 运行部署脚本（需要 root 权限）
sudo ./deploy/deploy.sh
```

部署脚本会自动完成：
- 编译应用
- 创建目录结构
- 复制文件
- 设置权限
- 配置 Supervisor
- 配置 Nginx
- 启动服务

### 方式二：手动部署

```bash
# 1. 编译应用
cd /path/to/backend
make build

# 2. 复制文件
sudo cp bin/deadornot-backend /opt/deadornot/backend/bin/
sudo cp deploy/supervisor.conf /opt/deadornot/backend/deploy/

# 3. 设置权限
sudo chown -R www-data:www-data /opt/deadornot/backend
sudo chmod +x /opt/deadornot/backend/bin/deadornot-backend

# 4. 配置 Supervisor
# CentOS 使用 /etc/supervisord.d/ 目录，配置文件使用 .ini 扩展名
sudo ln -sf /opt/deadornot/backend/deploy/supervisor.conf /etc/supervisord.d/deadornot-backend.ini
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start deadornot-backend

# 如果 Supervisor 服务未运行，启动它
sudo systemctl restart supervisord
```

## Nginx 和 SSL 配置

### 1. 配置域名

部署脚本会自动复制 Nginx 配置文件，但需要手动修改域名：

```bash
# 编辑 Nginx 配置文件
sudo nano /etc/nginx/conf.d/deadornot.conf
```

如果使用了 SSL 配置模板，也需要更新：

```bash
# 编辑 SSL 配置文件
sudo nano /etc/nginx/conf.d/ssl.conf
```

### 2. 配置防火墙

开放 80 和 443 端口：

```bash
# CentOS 7 (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# 或者使用 iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo service iptables save
```

### 3. 获取 Let's Encrypt SSL 证书

#### 方式一：使用自动脚本（推荐）

**单域名证书**（如 alive.xiaodao.fun）：

```bash
# 运行 SSL 证书获取脚本
sudo /opt/deadornot/backend/deploy/certbot/setup-ssl.sh alive.xiaodao.fun your-email@example.com

# 示例
sudo /opt/deadornot/backend/deploy/certbot/setup-ssl.sh alive.xiaodao.fun admin@example.com
```

脚本会自动：
- 检查并安装 certbot
- 更新 Nginx 配置中的域名
- 获取 SSL 证书
- 配置自动续期
- 重启 Nginx

**通配符证书**（如 *.xiaodao.fun）：

Let's Encrypt 支持通配符证书，可以覆盖所有子域名（如 *.xiaodao.fun）。

```bash
# 运行通配符证书获取脚本
sudo /opt/deadornot/backend/deploy/certbot/setup-wildcard-ssl.sh xiaodao.fun your-email@example.com

# 示例
sudo /opt/deadornot/backend/deploy/certbot/setup-wildcard-ssl.sh xiaodao.fun admin@example.com
```

**通配符证书说明**：
- 证书将覆盖 `xiaodao.fun` 和 `*.xiaodao.fun`（所有子域名）
- 需要使用 **DNS-01 验证方式**（不是 HTTP-01）
- 需要手动添加 DNS TXT 记录进行验证
- 证书路径：`/etc/letsencrypt/live/xiaodao.fun/`
- 在 Nginx 配置中使用相同的证书路径即可

**通配符证书申请步骤**：
1. 运行脚本后，certbot 会显示需要添加的 DNS TXT 记录
2. 在 DNS 管理界面添加 TXT 记录：
   - 记录类型：TXT
   - 记录名称：`_acme-challenge.xiaodao.fun`
   - 记录值：certbot 显示的值
3. 等待 DNS 记录生效（通常几分钟）
4. 按回车继续，certbot 会验证并颁发证书

**使用通配符证书的 Nginx 配置**：
```nginx
# 如果使用通配符证书 *.xiaodao.fun
ssl_certificate /etc/letsencrypt/live/xiaodao.fun/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/xiaodao.fun/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/xiaodao.fun/chain.pem;
```

#### 方式二：手动配置

**单域名证书**：

```bash
# 1. 安装 certbot
sudo yum install -y epel-release
sudo yum install -y certbot python3-certbot-nginx

# 2. 获取证书（使用 nginx 插件）
sudo certbot --nginx -d alive.xiaodao.fun --email your-email@example.com --agree-tos --non-interactive

# 3. 测试证书续期
sudo certbot renew --dry-run
```

**通配符证书（手动方式）**：

```bash
# 1. 安装 certbot
sudo yum install -y epel-release
sudo yum install -y certbot

# 2. 申请通配符证书（使用 DNS-01 验证）
sudo certbot certonly --manual --preferred-challenges dns \
  -d xiaodao.fun -d '*.xiaodao.fun' \
  --email your-email@example.com --agree-tos

# 3. 按照提示添加 DNS TXT 记录
# 4. 等待 DNS 生效后按回车继续
```

### 4. 配置证书自动续期

Let's Encrypt 证书有效期为 90 天，需要定期续期。certbot 会自动配置续期，但建议手动测试：

```bash
# 测试续期
sudo certbot renew --dry-run

# 手动续期
sudo certbot renew

# 查看证书信息
sudo certbot certificates
```

配置 cron 任务自动续期（可选，certbot 通常已自动配置）：

```bash
# 编辑 crontab
sudo crontab -e

# 添加以下行（每月 1 号凌晨 3 点检查续期）
0 3 1 * * /opt/deadornot/backend/deploy/certbot/renew-cert.sh >> /var/log/certbot-renew.log 2>&1
```

### 5. 重启 Nginx

配置完成后重启 Nginx：

```bash
# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx

# 查看状态
sudo systemctl status nginx
```

### 6. 验证 SSL 配置

```bash
# 测试 HTTPS 连接
curl -I https://your-domain.com/api/health

# 使用浏览器访问
# https://your-domain.com/api/health
```

## 服务管理

### Supervisor 命令（CentOS）

```bash
# 查看服务状态
sudo supervisorctl status deadornot-backend

# 启动服务
sudo supervisorctl start deadornot-backend

# 停止服务
sudo supervisorctl stop deadornot-backend

# 重启服务
sudo supervisorctl restart deadornot-backend

# 查看日志
sudo supervisorctl tail -f deadornot-backend

# 重载配置
sudo supervisorctl reread
sudo supervisorctl update

# CentOS 中重启 Supervisor 服务
sudo systemctl restart supervisord
sudo systemctl status supervisord
```

### 查看应用日志

```bash
# 应用日志
tail -f /opt/deadornot/backend/logs/app.log

# 错误日志
tail -f /opt/deadornot/backend/logs/error.log
```

### Nginx 命令

```bash
# 查看 Nginx 状态
sudo systemctl status nginx

# 启动 Nginx
sudo systemctl start nginx

# 停止 Nginx
sudo systemctl stop nginx

# 重启 Nginx
sudo systemctl restart nginx

# 重载配置（不中断服务）
sudo systemctl reload nginx

# 测试配置
sudo nginx -t

# 查看 Nginx 日志
sudo tail -f /var/log/nginx/deadornot-access.log
sudo tail -f /var/log/nginx/deadornot-error.log
```

### 健康检查

应用提供健康检查端点：

```bash
curl http://localhost:8080/api/health
```

## 维护和监控

### 日志轮转

创建 logrotate 配置 `/etc/logrotate.d/deadornot-backend`：

**CentOS 配置**:
```
/opt/deadornot/backend/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www www
    sharedscripts
    postrotate
        supervisorctl restart deadornot-backend > /dev/null
    endscript
}
```

**Ubuntu/Debian 配置**:
```
/opt/deadornot/backend/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        supervisorctl restart deadornot-backend > /dev/null
    endscript
}
```

### 更新应用

```bash
# 1. 停止服务
sudo supervisorctl stop deadornot-backend

# 2. 备份当前版本
sudo cp /opt/deadornot/backend/bin/deadornot-backend /opt/deadornot/backend/bin/deadornot-backend.backup

# 3. 编译新版本
cd /path/to/backend
make build

# 4. 复制新版本
sudo cp bin/deadornot-backend /opt/deadornot/backend/bin/
sudo chown www-data:www-data /opt/deadornot/backend/bin/deadornot-backend
sudo chmod +x /opt/deadornot/backend/bin/deadornot-backend

# 5. 启动服务
sudo supervisorctl start deadornot-backend
```

### 监控

建议使用以下工具监控应用：

- **系统监控**: htop, iotop
- **日志监控**: tail, grep, less
- **网络监控**: netstat, ss
- **进程监控**: ps, top

## 常见问题

### 1. 服务无法启动

**问题**: Supervisor 显示服务为 FATAL 或 EXITED

**解决方案**:
```bash
# 查看错误日志
sudo tail -100 /opt/deadornot/backend/logs/error.log

# 检查配置文件
sudo supervisorctl status deadornot-backend

# 手动运行测试（CentOS 使用 www 用户）
sudo -u www /opt/deadornot/backend/bin/deadornot-backend

# 检查 Supervisor 服务状态（CentOS）
sudo systemctl status supervisord
```

### 2. 数据库连接失败

**问题**: 应用无法连接到数据库

**解决方案**:
- 检查数据库服务是否运行: `sudo systemctl status mysql`
- 检查数据库用户权限
- 检查防火墙设置
- 验证 `.env` 文件中的数据库配置

### 3. 端口被占用

**问题**: 端口 8080 已被占用

**解决方案**:
```bash
# 查看端口占用
sudo netstat -tlnp | grep 8080
# 或
sudo ss -tlnp | grep 8080

# 修改 .env 文件中的 PORT 配置
```

### 4. 权限问题

**问题**: 权限不足导致文件无法访问

**解决方案**:
```bash
# 检查文件权限
ls -la /opt/deadornot/backend/

# 修复权限（CentOS 使用 www 用户）
sudo chown -R www:www /opt/deadornot/backend
sudo chmod 750 /opt/deadornot/backend/bin/deadornot-backend

# 如果 www 用户不存在，创建它
sudo useradd -r -s /sbin/nologin www
```

### 5. APNs 推送失败

**问题**: iOS 推送通知无法发送

**解决方案**:
- 检查 APNs Key 文件路径和权限
- 验证 APNS_KEY_ID 和 APNS_TEAM_ID 是否正确
- 确认 APNS_PRODUCTION 设置是否正确（开发/生产环境）
- 检查网络连接（需要访问 Apple 服务器）

### 6. 邮件发送失败

**问题**: 邮件无法发送

**解决方案**:
- 检查阿里云 Access Key 和 Secret 是否正确
- 验证 FROM_EMAIL 是否已配置
- 检查阿里云邮件服务是否已开通
- 查看错误日志获取详细错误信息

### 7. Nginx 无法启动

**问题**: Nginx 服务无法启动

**解决方案**:
```bash
# 检查配置语法
sudo nginx -t

# 查看错误日志
sudo tail -50 /var/log/nginx/error.log

# 检查端口占用
sudo netstat -tlnp | grep -E ':(80|443)'

# 检查 SELinux（CentOS）
sudo getenforce
# 如果为 Enforcing，可能需要设置 SELinux 上下文
```

### 8. SSL 证书获取失败

**问题**: Let's Encrypt 证书获取失败

**解决方案**:
- 确保域名已正确解析到服务器 IP
- 检查防火墙是否开放 80 端口（Let's Encrypt 需要验证）
- 确保 Nginx 配置正确，可以访问 `http://your-domain.com/.well-known/acme-challenge/`
- 检查 certbot 日志: `sudo tail -f /var/log/letsencrypt/letsencrypt.log`
- 如果使用测试模式: `TEST_MODE=true sudo /opt/deadornot/backend/deploy/certbot/setup-ssl.sh your-domain.com`

### 9. HTTPS 访问失败

**问题**: 无法通过 HTTPS 访问

**解决方案**:
- 检查 SSL 证书是否存在: `sudo ls -la /etc/letsencrypt/live/alive.xiaodao.fun/`
- 检查 Nginx 配置中的证书路径是否正确
- 检查防火墙是否开放 443 端口
- 查看 Nginx 错误日志: `sudo tail -f /var/log/nginx/deadornot-error.log`
- 测试 SSL 连接: `openssl s_client -connect alive.xiaodao.fun:443`

### 10. 通配符证书申请失败

**问题**: 通配符证书（*.xiaodao.fun）申请失败

**解决方案**:
- 确保使用 DNS-01 验证方式（不是 HTTP-01）
- 检查 DNS TXT 记录是否正确添加：
  ```bash
  # 检查 DNS 记录
  dig _acme-challenge.xiaodao.fun TXT
  ```
- 确保 DNS 记录已生效（可能需要几分钟到几小时）
- 检查域名解析是否正确
- 如果使用测试模式，设置 `TEST_MODE=true` 环境变量
- 查看 certbot 日志: `sudo tail -f /var/log/letsencrypt/letsencrypt.log`

**通配符证书使用说明**：
- 通配符证书路径：`/etc/letsencrypt/live/xiaodao.fun/`（注意是根域名，不是子域名）
- 在 Nginx 配置中，所有使用 `*.xiaodao.fun` 的 server 块都可以使用同一个证书
- 证书同时覆盖 `xiaodao.fun` 和 `*.xiaodao.fun`

## 安全建议

1. **防火墙配置**: 只开放必要的端口（80, 443, 22）
2. **SSL/TLS**: 使用 Let's Encrypt 配置 HTTPS，确保所有通信加密
3. **数据库安全**: 使用强密码，限制数据库用户权限
4. **文件权限**: 确保敏感文件（.env, .p8, SSL 证书）权限正确
5. **定期更新**: 及时更新系统和应用依赖
6. **日志监控**: 定期检查日志，发现异常及时处理
7. **备份**: 定期备份数据库和配置文件
8. **证书续期**: 确保 SSL 证书自动续期正常工作

## 联系支持

如遇到问题，请查看：
- 应用日志: `/opt/deadornot/backend/logs/`
- Supervisor 日志: `/var/log/supervisor/`
- 系统日志: `/var/log/syslog` 或 `/var/log/messages`

## 附录

### Makefile 常用命令

```bash
make build          # 编译 Linux amd64 版本
make build-local    # 编译本地版本
make run            # 本地运行
make test           # 运行测试
make clean           # 清理编译产物
make help            # 查看帮助
```

### 环境变量说明

详细的环境变量说明请参考 `deploy/env.example` 文件。
