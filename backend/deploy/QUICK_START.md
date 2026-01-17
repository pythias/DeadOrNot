# 快速配置指南 - alive.xiaodao.fun

## 域名配置

- **主域名**: `alive.xiaodao.fun`
- **根域名**: `xiaodao.fun`（用于通配符证书）

## 快速部署步骤

### 1. 部署应用

```bash
cd /path/to/backend
sudo ./deploy/deploy.sh
```

### 2. 配置 Nginx 域名

```bash
# 编辑配置文件
sudo nano /etc/nginx/conf.d/deadornot.conf
```

### 3. 选择证书类型

#### 选项 A：单域名证书（仅 alive.xiaodao.fun）

```bash
sudo /opt/deadornot/backend/deploy/certbot/setup-ssl.sh alive.xiaodao.fun your-email@example.com
```

#### 选项 B：通配符证书（*.xiaodao.fun，推荐）

```bash
sudo /opt/deadornot/backend/deploy/certbot/setup-wildcard-ssl.sh xiaodao.fun your-email@example.com
```

**通配符证书说明**：
- 证书覆盖 `xiaodao.fun` 和所有 `*.xiaodao.fun` 子域名
- 需要使用 DNS-01 验证（需要添加 DNS TXT 记录）
- 证书路径：`/etc/letsencrypt/live/xiaodao.fun/`

**如果使用通配符证书，需要更新 Nginx 配置**：
```nginx
ssl_certificate /etc/letsencrypt/live/xiaodao.fun/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/xiaodao.fun/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/xiaodao.fun/chain.pem;
```

### 4. 重启 Nginx

```bash
sudo nginx -t  # 测试配置
sudo systemctl restart nginx
```

### 5. 验证

```bash
# 测试 HTTPS
curl https://alive.xiaodao.fun/api/health

# 查看证书信息
sudo certbot certificates
```

## 防火墙配置

```bash
# CentOS 7
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## 证书续期

证书会自动续期，也可以手动测试：

```bash
# 测试续期
sudo certbot renew --dry-run

# 手动续期
sudo certbot renew
```

## 常用命令

```bash
# 查看服务状态
sudo supervisorctl status deadornot-backend
sudo systemctl status nginx

# 查看日志
tail -f /opt/deadornot/backend/logs/app.log
tail -f /var/log/nginx/deadornot-error.log

# 重启服务
sudo supervisorctl restart deadornot-backend
sudo systemctl restart nginx
```
