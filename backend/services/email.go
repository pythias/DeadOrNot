package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/deadornot/backend/config"
)

// EmailService 邮件发送服务
type EmailService struct {
	config *config.Config
	client *http.Client
}

// NewEmailService 创建邮件服务
func NewEmailService(cfg *config.Config) *EmailService {
	return &EmailService{
		config: cfg,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// SendEmail 发送邮件
func (es *EmailService) SendEmail(to, subject, body string) error {
	if es.config.Email.Provider == "aliyun" {
		return es.sendViaAliyun(to, subject, body)
	} else if es.config.Email.Provider == "smtp" {
		return es.sendViaSMTP(to, subject, body)
	}
	return fmt.Errorf("unsupported email provider: %s", es.config.Email.Provider)
}

// sendViaAliyun 通过阿里云邮件推送发送
func (es *EmailService) sendViaAliyun(to, subject, body string) error {
	// 阿里云邮件推送API
	// 这里使用阿里云DirectMail API
	// 需要安装阿里云SDK或直接调用HTTP API

	url := fmt.Sprintf("https://dm.%s.aliyuncs.com/", es.config.Email.AliyunRegion)

	// 构建请求体（简化版，实际需要根据阿里云API文档）
	payload := map[string]interface{}{
		"Action":           "SingleSendMail",
		"AccountName":       es.config.Email.FromEmail,
		"ReplyToAddress":   "false",
		"AddressType":      "1",
		"ToAddress":        to,
		"Subject":          subject,
		"HtmlBody":         body,
		"FromAlias":        es.config.Email.FromName,
		"AccessKeyId":      es.config.Email.AliyunKey,
		"Format":           "JSON",
		"SignatureMethod": "HMAC-SHA1",
		"SignatureVersion": "1.0",
		"Version":          "2015-11-23",
		"Timestamp":        time.Now().UTC().Format("2006-01-02T15:04:05Z"),
	}

	// 注意：实际使用时需要正确签名
	jsonData, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := es.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("aliyun API error: %s", string(bodyBytes))
	}

	log.Printf("Email sent successfully to %s via Aliyun", to)
	return nil
}

// sendViaSMTP 通过SMTP发送
func (es *EmailService) sendViaSMTP(to, subject, body string) error {
	// 这里可以使用gopkg.in/mail.v2或其他SMTP库
	// 为了简化，这里返回一个占位实现
	return fmt.Errorf("SMTP provider not yet implemented, please use Aliyun provider")
}
