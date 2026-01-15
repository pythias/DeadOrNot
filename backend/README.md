# DeadOrNot Backend Service

后端服务，使用 Golang + Gin 框架开发。

## 功能

1. 用户设置管理
2. 打卡功能
3. 打卡提醒 Push（每天早上9点，根据用户时区）
4. 邮件提醒（三天不打卡）

## 技术栈

- Gin Web框架
- MySQL数据库
- APNs推送通知
- 阿里云邮件推送（或SMTP）

## 配置

复制 `.env.example` 为 `.env` 并填写配置：

```bash
cp .env.example .env
```

### 环境变量说明

- `DB_*`: 数据库配置
- `APNS_*`: Apple Push Notification Service配置
- `EMAIL_PROVIDER`: 邮件服务提供商（aliyun 或 smtp）
- `ALIYUN_*`: 阿里云邮件推送配置
- `PORT`: 服务端口（默认8080）

## 运行

```bash
# 安装依赖
go mod download

# 运行服务
go run main.go
```

## API接口

### 基础路径
- 域名: `alive.xiaodao.fun`
- API前缀: `/api`

### 接口列表

#### 健康检查
- `GET /api/health`

#### 用户设置
- `GET /api/user` - 获取用户信息
- `PUT /api/user` - 更新用户设置

#### 打卡
- `POST /api/checkin` - 打卡
- `GET /api/checkin/history` - 获取打卡记录
- `GET /api/checkin/stats` - 获取打卡统计

所有接口都需要在Header中提供 `X-Device-ID`。

## 数据库

服务启动时会自动运行数据库迁移，创建以下表：

- `users` - 用户表
- `checkins` - 打卡记录表
- `notifications` - 通知记录表（包含状态机）

## 定时任务

- 每分钟：处理待发送和重试中的通知
- 每小时：安排每日推送提醒（根据用户时区）
- 每小时：检查三天未打卡并发送邮件提醒

## 时区支持

系统支持多时区用户，所有日期计算基于用户设置的时区。
