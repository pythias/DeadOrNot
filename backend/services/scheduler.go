package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/deadornot/backend/config"
	"github.com/deadornot/backend/models"
	"github.com/deadornot/backend/utils"
	"github.com/robfig/cron/v3"
)

// SchedulerService 定时任务服务
type SchedulerService struct {
	db                  *sql.DB
	notificationService *NotificationService
	config              *config.Config
	cron                *cron.Cron
}

// NewSchedulerService 创建定时任务服务
func NewSchedulerService(db *sql.DB, notificationService *NotificationService, cfg *config.Config) *SchedulerService {
	return &SchedulerService{
		db:                  db,
		notificationService: notificationService,
		config:              cfg,
		cron:                cron.New(cron.WithSeconds()),
	}
}

// Start 启动定时任务
func (ss *SchedulerService) Start() {
	log.Println("Starting scheduler service...")

	// 通知发送处理器：每分钟执行一次
	ss.cron.AddFunc("0 * * * * *", func() {
		if err := ss.notificationService.ProcessPendingNotifications(); err != nil {
			log.Printf("Error processing pending notifications: %v", err)
		}
		if err := ss.notificationService.ProcessRetryingNotifications(); err != nil {
			log.Printf("Error processing retrying notifications: %v", err)
		}
	})

	// 每日推送提醒：每天早上9点（根据用户时区）
	// 每小时检查一次，为每个时区的用户安排当天的提醒
	ss.cron.AddFunc("0 0 * * * *", func() {
		ss.scheduleDailyPushReminders()
	})

	// 三天未打卡邮件提醒：每小时检查一次
	ss.cron.AddFunc("0 0 * * * *", func() {
		ss.checkThreeDaysMissedCheckIns()
	})

	ss.cron.Start()
	log.Println("Scheduler service started")
}

// Stop 停止定时任务
func (ss *SchedulerService) Stop() {
	ss.cron.Stop()
	log.Println("Scheduler service stopped")
}

// scheduleDailyPushReminders 安排每日推送提醒
func (ss *SchedulerService) scheduleDailyPushReminders() {
	// 查询所有启用推送的用户
	rows, err := ss.db.Query(`
		SELECT id, apns_token, timezone, push_enabled
		FROM users
		WHERE push_enabled = TRUE AND apns_token != '' AND apns_token IS NOT NULL
	`)
	if err != nil {
		log.Printf("Failed to query users for push reminders: %v", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var userID int64
		var apnsToken sql.NullString
		var timezone string
		var pushEnabled bool

		if err := rows.Scan(&userID, &apnsToken, &timezone, &pushEnabled); err != nil {
			log.Printf("Failed to scan user: %v", err)
			continue
		}

		// 跳过无效的 token
		if !apnsToken.Valid || apnsToken.String == "" {
			continue
		}

		if timezone == "" {
			timezone = "UTC"
		}

		// 获取用户时区的今天日期
		today, err := utils.GetTodayInTimezone(timezone)
		if err != nil {
			log.Printf("Failed to get today for timezone %s: %v", timezone, err)
			continue
		}

		// 检查今天是否已打卡
		var exists bool
		err = ss.db.QueryRow(`
			SELECT EXISTS(SELECT 1 FROM checkins WHERE user_id = ? AND DATE(checkin_datetime) = DATE(?))
		`, userID, today).Scan(&exists)

		if err != nil {
			log.Printf("Failed to check checkin: %v", err)
			continue
		}

		// 如果已打卡，跳过
		if exists {
			continue
		}

		// 计算今天早上9点的UTC时间
		scheduledAt, err := utils.GetTimeInTimezone(timezone, 9, 0)
		if err != nil {
			log.Printf("Failed to get scheduled time: %v", err)
			continue
		}

		// 如果已经过了9点，立即发送
		if scheduledAt.Before(time.Now()) {
			scheduledAt = time.Now()
		}

		// 生成唯一键
		dateStr, _ := utils.GetDateStringInTimezone(scheduledAt, timezone)
		uniqueKey := fmt.Sprintf("%d_push_%s", userID, dateStr)

		// 检查是否已创建过今天的提醒
		var count int
		err = ss.db.QueryRow(`
			SELECT COUNT(*) FROM notifications 
			WHERE unique_key = ? AND status != 'failed'
		`, uniqueKey).Scan(&count)

		if err == nil && count == 0 {
			// 创建推送通知记录
			content := models.NotificationContent{
				Subject: "打卡提醒",
				Body:    "今天还没有打卡，快打开\"死了么\"打个卡吧！",
			}

			err = ss.notificationService.CreateNotification(
				userID, "push", apnsToken.String, timezone, scheduledAt, content, uniqueKey,
			)

			if err != nil {
				log.Printf("Failed to create push notification for user %d: %v", userID, err)
			}
		}
	}
}

// checkThreeDaysMissedCheckIns 检查三天未打卡的用户并发送邮件提醒
func (ss *SchedulerService) checkThreeDaysMissedCheckIns() {
	// 查询所有启用邮件提醒的用户
	rows, err := ss.db.Query(`
		SELECT id, name, emergency_contact_emails, timezone, email_enabled
		FROM users
		WHERE email_enabled = TRUE
	`)
	if err != nil {
		log.Printf("Failed to query users for email reminders: %v", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var userID int64
		var name, emailsJSON, timezone string
		var emailEnabled bool

		if err := rows.Scan(&userID, &name, &emailsJSON, &timezone, &emailEnabled); err != nil {
			log.Printf("Failed to scan user: %v", err)
			continue
		}

		if timezone == "" {
			timezone = "UTC"
		}

		// 解析紧急联系人邮箱
		var emails []string
		if err := json.Unmarshal([]byte(emailsJSON), &emails); err != nil || len(emails) == 0 {
			continue
		}

		// 获取最后打卡时间
		var lastCheckIn sql.NullTime
		err = ss.db.QueryRow(`
			SELECT MAX(checkin_datetime) FROM checkins WHERE user_id = ?
		`, userID).Scan(&lastCheckIn)

		if err != nil && err != sql.ErrNoRows {
			log.Printf("Failed to get last checkin: %v", err)
			continue
		}

		// 计算距离最后打卡的天数（基于用户时区）
		var daysSince int
		if lastCheckIn.Valid {
			daysSince, err = utils.DaysSinceInTimezone(lastCheckIn.Time, timezone)
			if err != nil {
				log.Printf("Failed to calculate days since: %v", err)
				continue
			}
		} else {
			// 从未打卡，从今天开始计算
			daysSince = 0
		}

		// 如果超过3天未打卡，但小于7天，则发送邮件提醒
		if daysSince >= 3 && daysSince < 7 {
			// 获取用户时区的今天日期字符串
			today, _ := utils.GetTodayInTimezone(timezone)
			dateStr, _ := utils.GetDateStringInTimezone(today, timezone)
			uniqueKey := fmt.Sprintf("%d_email_%s", userID, dateStr)

			// 检查今天是否已发送过邮件
			var count int
			err = ss.db.QueryRow(`
				SELECT COUNT(*) FROM notifications 
				WHERE unique_key = ? AND status = 'sent'
			`, uniqueKey).Scan(&count)

			if err == nil && count == 0 {
				// 为每个紧急联系人创建邮件通知
				for _, email := range emails {
					if email == "" {
						continue
					}

					subject := "紧急提醒：" + name + " 已连续多日未打卡"
					body := fmt.Sprintf(`
您好，

%s 已连续 %d 天未在"死了么"应用中打卡。

请及时联系确认其安全状况。

此邮件由系统自动发送。
					`, name, daysSince)

					content := models.NotificationContent{
						Subject: subject,
						Body:    body,
					}

					// 立即发送
					err = ss.notificationService.CreateNotification(
						userID, "email", email, timezone, time.Now(), content, uniqueKey+"_"+email,
					)

					if err != nil {
						log.Printf("Failed to create email notification for user %d: %v", userID, err)
					}
				}
			}
		}
	}
}
