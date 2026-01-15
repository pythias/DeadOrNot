package services

import (
	"encoding/json"
	"fmt"
	"log"

	"github.com/deadornot/backend/config"
	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/token"
)

// PushService APNs推送服务
type PushService struct {
	client *apns2.Client
	config *config.Config
}

// NewPushService 创建推送服务
func NewPushService(cfg *config.Config) *PushService {
	ps := &PushService{
		config: cfg,
	}

	// 初始化APNs客户端
	if cfg.APNs.KeyPath != "" && cfg.APNs.KeyID != "" && cfg.APNs.TeamID != "" {
		// 使用Token认证（.p8文件）
		authKey, err := token.AuthKeyFromFile(cfg.APNs.KeyPath)
		if err != nil {
			log.Printf("Failed to load APNs key file: %v", err)
			return ps
		}

		apnsToken := &token.Token{
			AuthKey: authKey,
			KeyID:   cfg.APNs.KeyID,
			TeamID:  cfg.APNs.TeamID,
		}

		if cfg.APNs.Production {
			ps.client = apns2.NewTokenClient(apnsToken).Production()
		} else {
			ps.client = apns2.NewTokenClient(apnsToken).Development()
		}
	} else {
		log.Println("APNs configuration incomplete, push service will be disabled")
	}

	return ps
}

// SendPush 发送推送通知
func (ps *PushService) SendPush(deviceToken string, title, body string, data map[string]interface{}) error {
	if ps.client == nil {
		return fmt.Errorf("push service not initialized")
	}

	// 构建payload
	payload := map[string]interface{}{
		"aps": map[string]interface{}{
			"alert": map[string]string{
				"title": title,
				"body":  body,
			},
			"sound": "default",
		},
	}

	// 添加自定义数据
	if len(data) > 0 {
		for k, v := range data {
			payload[k] = v
		}
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal payload: %w", err)
	}

	notification := &apns2.Notification{}
	notification.DeviceToken = deviceToken
	notification.Topic = ps.config.APNs.BundleID
	notification.Payload = payloadBytes

	res, err := ps.client.Push(notification)
	if err != nil {
		return fmt.Errorf("failed to send push: %w", err)
	}

	if !res.Sent() {
		return fmt.Errorf("push failed: %s", res.Reason)
	}

	log.Printf("Push sent successfully to %s", deviceToken)
	return nil
}

// IsAvailable 检查推送服务是否可用
func (ps *PushService) IsAvailable() bool {
	return ps.client != nil
}
