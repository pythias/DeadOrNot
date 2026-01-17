package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/deadornot/backend/models"
)

// NotificationService 通知服务，统一管理邮件、短信等通知
type NotificationService struct {
	db            *sql.DB
	emailService  *EmailService
	pushService   *PushService
}

// NewNotificationService 创建通知服务
func NewNotificationService(db *sql.DB, emailService *EmailService, pushService *PushService) *NotificationService {
	return &NotificationService{
		db:           db,
		emailService: emailService,
		pushService:  pushService,
	}
}

// CreateNotification 创建通知记录
func (ns *NotificationService) CreateNotification(userID int64, notificationType, recipient, timezone string, scheduledAt time.Time, content models.NotificationContent, uniqueKey string) error {
	contentJSON, _ := json.Marshal(content)

	_, err := ns.db.Exec(`
		INSERT INTO notifications 
		(user_id, notification_type, recipient, status, scheduled_at, content, timezone, unique_key, max_retries)
		VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, 3)
		ON DUPLICATE KEY UPDATE updated_at = updated_at
	`, userID, notificationType, recipient, scheduledAt, string(contentJSON), timezone, uniqueKey)

	if err != nil {
		return fmt.Errorf("failed to create notification: %w", err)
	}

	return nil
}

// ProcessPendingNotifications 处理待发送的通知
func (ns *NotificationService) ProcessPendingNotifications() error {
	// 查询待发送的通知（状态为pending且scheduled_at已到）
	rows, err := ns.db.Query(`
		SELECT id, user_id, notification_type, recipient, content, timezone, retry_count, max_retries
		FROM notifications
		WHERE status = 'pending' AND scheduled_at <= NOW()
		ORDER BY scheduled_at ASC
		LIMIT 100
	`)
	if err != nil {
		return fmt.Errorf("failed to query notifications: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var notif models.Notification
		var contentJSON string

		err := rows.Scan(
			&notif.ID, &notif.UserID, &notif.NotificationType,
			&notif.Recipient, &contentJSON, &notif.Timezone,
			&notif.RetryCount, &notif.MaxRetries,
		)
		if err != nil {
			log.Printf("Failed to scan notification: %v", err)
			continue
		}

		// 解析内容
		json.Unmarshal([]byte(contentJSON), &notif.Content)

		// 使用事务更新状态为sending，防止并发重复处理
		tx, err := ns.db.Begin()
		if err != nil {
			log.Printf("Failed to begin transaction: %v", err)
			continue
		}

		// 尝试将状态从pending更新为sending
		result, err := tx.Exec(`
			UPDATE notifications 
			SET status = 'sending', updated_at = NOW()
			WHERE id = ? AND status = 'pending'
		`, notif.ID)

		if err != nil {
			tx.Rollback()
			log.Printf("Failed to update notification status: %v", err)
			continue
		}

		affected, _ := result.RowsAffected()
		if affected == 0 {
			// 状态已被其他进程更新，跳过
			tx.Rollback()
			continue
		}

		// 发送通知
		err = ns.sendNotification(&notif)
		now := time.Now()

		if err != nil {
			// 发送失败
			if notif.RetryCount < notif.MaxRetries {
				// 可以重试
				nextRetryDelay := ns.getRetryDelay(notif.RetryCount + 1)
				nextScheduledAt := now.Add(nextRetryDelay)

				_, updateErr := tx.Exec(`
					UPDATE notifications 
					SET status = 'retrying', retry_count = retry_count + 1, 
					    scheduled_at = ?, error_message = ?, updated_at = NOW()
					WHERE id = ?
				`, nextScheduledAt, err.Error(), notif.ID)

				if updateErr != nil {
					tx.Rollback()
					log.Printf("Failed to update notification for retry: %v", updateErr)
					continue
				}
			} else {
				// 达到最大重试次数
				_, updateErr := tx.Exec(`
					UPDATE notifications 
					SET status = 'failed', failed_at = ?, error_message = ?, updated_at = NOW()
					WHERE id = ?
				`, now, err.Error(), notif.ID)

				if updateErr != nil {
					tx.Rollback()
					log.Printf("Failed to update notification as failed: %v", updateErr)
					continue
				}
			}
		} else {
			// 发送成功
			_, updateErr := tx.Exec(`
				UPDATE notifications 
				SET status = 'sent', sent_at = ?, updated_at = NOW()
				WHERE id = ?
			`, now, notif.ID)

			if updateErr != nil {
				tx.Rollback()
				log.Printf("Failed to update notification as sent: %v", updateErr)
				continue
			}
		}

		if err := tx.Commit(); err != nil {
			log.Printf("Failed to commit transaction: %v", err)
		}
	}

	return nil
}

// sendNotification 发送通知
func (ns *NotificationService) sendNotification(notif *models.Notification) error {
	switch notif.NotificationType {
	case "email":
		return ns.emailService.SendEmail(
			notif.Recipient,
			notif.Content.Subject,
			notif.Content.Body,
		)
	case "push":
		if !ns.pushService.IsAvailable() {
			return fmt.Errorf("push service not available")
		}
		// 需要从数据库获取用户的APNS token
		var apnsToken sql.NullString
		err := ns.db.QueryRow(`
			SELECT apns_token FROM users WHERE id = ?
		`, notif.UserID).Scan(&apnsToken)
		if err != nil {
			return fmt.Errorf("failed to get APNS token: %w", err)
		}
		if !apnsToken.Valid || apnsToken.String == "" {
			return fmt.Errorf("APNS token not available for user")
		}
		return ns.pushService.SendPush(apnsToken.String, notif.Content.Subject, notif.Content.Body, notif.Content.Data)
	case "sms":
		return fmt.Errorf("SMS not yet implemented")
	default:
		return fmt.Errorf("unknown notification type: %s", notif.NotificationType)
	}
}

// getRetryDelay 获取重试延迟（指数退避）
func (ns *NotificationService) getRetryDelay(retryCount int) time.Duration {
	delays := []time.Duration{
		1 * time.Minute,
		5 * time.Minute,
		30 * time.Minute,
	}

	if retryCount <= len(delays) {
		return delays[retryCount-1]
	}
	return delays[len(delays)-1]
}

// ProcessRetryingNotifications 处理重试中的通知
func (ns *NotificationService) ProcessRetryingNotifications() error {
	// 查询重试中的通知（状态为retrying且scheduled_at已到）
	rows, err := ns.db.Query(`
		SELECT id, user_id, notification_type, recipient, content, timezone, retry_count, max_retries
		FROM notifications
		WHERE status = 'retrying' AND scheduled_at <= NOW()
		ORDER BY scheduled_at ASC
		LIMIT 100
	`)
	if err != nil {
		return fmt.Errorf("failed to query retrying notifications: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var notif models.Notification
		var contentJSON string

		err := rows.Scan(
			&notif.ID, &notif.UserID, &notif.NotificationType,
			&notif.Recipient, &contentJSON, &notif.Timezone,
			&notif.RetryCount, &notif.MaxRetries,
		)
		if err != nil {
			log.Printf("Failed to scan notification: %v", err)
			continue
		}

		json.Unmarshal([]byte(contentJSON), &notif.Content)

		// 更新状态为sending
		tx, err := ns.db.Begin()
		if err != nil {
			continue
		}

		result, err := tx.Exec(`
			UPDATE notifications 
			SET status = 'sending', updated_at = NOW()
			WHERE id = ? AND status = 'retrying'
		`, notif.ID)

		if err != nil {
			tx.Rollback()
			continue
		}

		affected, _ := result.RowsAffected()
		if affected == 0 {
			tx.Rollback()
			continue
		}

		// 发送通知
		err = ns.sendNotification(&notif)
		now := time.Now()

		if err != nil {
			if notif.RetryCount < notif.MaxRetries {
				nextRetryDelay := ns.getRetryDelay(notif.RetryCount + 1)
				nextScheduledAt := now.Add(nextRetryDelay)

				tx.Exec(`
					UPDATE notifications 
					SET status = 'retrying', retry_count = retry_count + 1, 
					    scheduled_at = ?, error_message = ?, updated_at = NOW()
					WHERE id = ?
				`, nextScheduledAt, err.Error(), notif.ID)
			} else {
				tx.Exec(`
					UPDATE notifications 
					SET status = 'failed', failed_at = ?, error_message = ?, updated_at = NOW()
					WHERE id = ?
				`, now, err.Error(), notif.ID)
			}
		} else {
			tx.Exec(`
				UPDATE notifications 
				SET status = 'sent', sent_at = ?, updated_at = NOW()
				WHERE id = ?
			`, now, notif.ID)
		}

		tx.Commit()
	}

	return nil
}
