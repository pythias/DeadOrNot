package services

import (
	"fmt"
	"time"
)

// EmailTemplate 邮件模板服务
type EmailTemplate struct{}

// NewEmailTemplate 创建邮件模板服务
func NewEmailTemplate() *EmailTemplate {
	return &EmailTemplate{}
}

// EmergencyReminderData 紧急提醒数据
type EmergencyReminderData struct {
	Name           string
	DaysSince      int
	LastCheckinAt  *time.Time
	TotalCheckins  int
	EmergencyPhone string // 紧急联系人电话（如果有）
}

// BuildEmergencyReminderEmail 构建紧急提醒邮件
func (et *EmailTemplate) BuildEmergencyReminderEmail(data EmergencyReminderData) (subject, body string) {
	subject = fmt.Sprintf("紧急提醒：%s 已连续多天未打卡", data.Name)

	// 获取日期描述
	dateDescription := ""
	if data.LastCheckinAt != nil {
		dateDescription = data.LastCheckinAt.Format("2006年1月2日 15:04")
	} else {
		dateDescription = "未知"
	}

	// 构建 HTML 邮件
	htmlBody := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>紧急提醒</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .container {
            background-color: #ffffff;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            padding: 30px 20px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 24px;
            font-weight: 600;
        }
        .content {
            padding: 30px 20px;
        }
        .alert-box {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .alert-box strong {
            color: #856404;
        }
        .info-table {
            width: 100%%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        .info-table th, .info-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eeeeee;
        }
        .info-table th {
            color: #666666;
            font-weight: 500;
            width: 40%%;
        }
        .info-table td {
            font-weight: 600;
        }
        .cta-button {
            display: inline-block;
            background-color: #667eea;
            color: white !important;
            padding: 12px 24px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 500;
            margin-top: 20px;
        }
        .footer {
            text-align: center;
            padding: 20px;
            color: #999999;
            font-size: 12px;
            border-top: 1px solid #eeeeee;
        }
        .app-name {
            color: #667eea;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚠️ 安全确认提醒</h1>
        </div>
        <div class="content">
            <p>您好，</p>

            <div class="alert-box">
                <strong>%s 的紧急联系人</strong><br>
                %s 已连续 <strong>%d 天</strong> 未在"死了么"应用打卡，请您留意！
            </div>

            <table class="info-table">
                <tr>
                    <th>姓名</th>
                    <td>%s</td>
                </tr>
                <tr>
                    <th>未打卡天数</th>
                    <td>%d 天</td>
                </tr>
                <tr>
                    <th>最后打卡时间</th>
                    <td>%s</td>
                </tr>
                <tr>
                    <th>累计打卡天数</th>
                    <td>%d 次</td>
                </tr>
            </table>

            <p>请尽快通过电话或其他方式联系 %s，确认其安全状况。</p>

            <p style="color: #666666; font-size: 14px;">
                如已确认 %s 安全，请忽略此邮件。
            </p>

            <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eeeeee;">
                <p style="color: #999999; font-size: 12px; margin: 0;">
                    此邮件由 <span class="app-name">死了么</span> 自动发送<br>
                    如果您不希望再收到此类通知，请联系 %s 修改紧急联系人设置
                </p>
            </div>
        </div>
    </div>
</body>
</html>`, data.Name, data.Name, data.DaysSince, data.Name, data.DaysSince, dateDescription, data.TotalCheckins, data.Name, data.Name, data.Name)

	return subject, htmlBody
}

// DailyReminderData 每日提醒数据
type DailyReminderData struct {
	Name         string
	ReminderTime string
}

// BuildDailyReminderEmail 构建每日打卡提醒邮件
func (et *EmailTemplate) BuildDailyReminderEmail(data DailyReminderData) (subject, body string) {
	subject = fmt.Sprintf("%s，该打卡了！", data.Name)

	htmlBody := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .container { background: #ffffff; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #48c6ef 0%%, #6f86d6 100%%); color: white; padding: 30px; text-align: center; }
        .content { padding: 30px; }
        .button { display: inline-block; background: #48c6ef; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 500; }
        .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📢 打卡提醒</h1>
        </div>
        <div class="content">
            <p>%s，您好：</p>
            <p>今天是%s，您还没有完成打卡哦！</p>
            <p>请打开"死了么"应用，点击打卡按钮完成每日打卡。</p>
            <p style="text-align: center;">
                <a href="#" class="button">立即打卡</a>
            </p>
        </div>
        <div class="footer">
            此邮件由"死了么"自动发送
        </div>
    </div>
</body>
</html>`, data.Name, data.ReminderTime)

	return subject, htmlBody
}
