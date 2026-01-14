# 死了么 (DeadOrNot)

简单的每日打卡 App 示例（SwiftUI + 本地通知）。当连续 3 天未打卡时发送本地提醒。

## 文件
- DeadOrNotApp.swift — App 入口
- Models/CheckInStore.swift — 打卡逻辑、数据持久化与提醒调度
- Helpers/NotificationManager.swift — 本地通知封装
- Views/ContentView.swift — 简单 UI
- Info.plist — 应用配置
- Assets.xcassets — 图标占位

## 快速运行
1. 用 Xcode 创建一个新的 App（SwiftUI）、或把本仓库放入 Xcode。
2. 运行到设备（推荐真机测试通知），首次启动会请求通知权限。
3. 点击“打卡”以记录今天；若连续 3 天未打卡，系统会发送本地通知。

## 打包为 zip
在项目父目录执行（macOS 终端）：
