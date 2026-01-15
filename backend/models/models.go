package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"
)

// User 用户模型
type User struct {
	ID                     int64       `json:"id" db:"id"`
	DeviceID               string      `json:"device_id" db:"device_id"`
	Name                   string      `json:"name" db:"name"`
	EmergencyContactEmails StringArray `json:"emergency_contact_emails" db:"emergency_contact_emails"`
	APNSToken              string      `json:"apns_token" db:"apns_token"`
	PushEnabled            bool        `json:"push_enabled" db:"push_enabled"`
	EmailEnabled           bool        `json:"email_enabled" db:"email_enabled"`
	Timezone               string      `json:"timezone" db:"timezone"`
	CreatedAt              time.Time   `json:"created_at" db:"created_at"`
	UpdatedAt              time.Time   `json:"updated_at" db:"updated_at"`
}

// CheckIn 打卡记录模型
type CheckIn struct {
	ID          int64     `json:"id" db:"id"`
	UserID      int64     `json:"user_id" db:"user_id"`
	CheckInDate time.Time `json:"checkin_date" db:"checkin_date"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// Notification 通知记录模型
type Notification struct {
	ID               int64               `json:"id" db:"id"`
	UserID           int64               `json:"user_id" db:"user_id"`
	NotificationType string              `json:"notification_type" db:"notification_type"`
	Recipient        string              `json:"recipient" db:"recipient"`
	Status           string              `json:"status" db:"status"`
	RetryCount       int                 `json:"retry_count" db:"retry_count"`
	MaxRetries       int                 `json:"max_retries" db:"max_retries"`
	ScheduledAt      time.Time           `json:"scheduled_at" db:"scheduled_at"`
	SentAt           *time.Time          `json:"sent_at" db:"sent_at"`
	FailedAt         *time.Time          `json:"failed_at" db:"failed_at"`
	ErrorMessage     string              `json:"error_message" db:"error_message"`
	Content          NotificationContent `json:"content" db:"content"`
	Timezone         string              `json:"timezone" db:"timezone"`
	UniqueKey        string              `json:"unique_key" db:"unique_key"`
	CreatedAt        time.Time           `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time           `json:"updated_at" db:"updated_at"`
}

// NotificationContent 通知内容
type NotificationContent struct {
	Subject string                 `json:"subject"`
	Body    string                 `json:"body"`
	Data    map[string]interface{} `json:"data,omitempty"`
}

// StringArray 字符串数组类型，用于JSON字段
type StringArray []string

// Value 实现 driver.Valuer 接口
func (a StringArray) Value() (driver.Value, error) {
	if len(a) == 0 {
		return "[]", nil
	}
	return json.Marshal(a)
}

// Scan 实现 sql.Scanner 接口
func (a *StringArray) Scan(value interface{}) error {
	if value == nil {
		*a = []string{}
		return nil
	}

	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return errors.New("cannot scan non-string value into StringArray")
	}

	return json.Unmarshal(bytes, a)
}

// Value 实现 driver.Valuer 接口
func (nc NotificationContent) Value() (driver.Value, error) {
	return json.Marshal(nc)
}

// Scan 实现 sql.Scanner 接口
func (nc *NotificationContent) Scan(value interface{}) error {
	if value == nil {
		*nc = NotificationContent{}
		return nil
	}

	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return errors.New("cannot scan non-NotificationContent value into NotificationContent")
	}

	return json.Unmarshal(bytes, nc)
}
