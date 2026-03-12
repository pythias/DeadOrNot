package services

import (
	"crypto/hmac"
	"crypto/sha1"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/smtp"
	"net/url"
	"sort"
	"strings"
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
	if es.config.Email.AliyunKey == "" || es.config.Email.AliyunSecret == "" {
		return fmt.Errorf("Aliyun access key or secret is not configured")
	}

	// 阿里云邮件推送API endpoint
	endpoint := fmt.Sprintf("https://dm.%s.aliyuncs.com/", es.config.Email.AliyunRegion)

	// 公共参数
	timestamp := time.Now().UTC().Format("2006-01-02T15:04:05Z")
	params := url.Values{}
	params.Set("Format", "JSON")
	params.Set("Version", "2015-11-23")
	params.Set("AccessKeyId", es.config.Email.AliyunKey)
	params.Set("SignatureMethod", "HMAC-SHA1")
	params.Set("Timestamp", timestamp)
	params.Set("SignatureVersion", "1.0")
	params.Set("SignatureNonce", fmt.Sprintf("%d", time.Now().UnixNano()))

	// 业务参数
	params.Set("Action", "SingleSendMail")
	params.Set("AccountName", es.config.Email.FromEmail)
	params.Set("ReplyToAddress", "false")
	params.Set("AddressType", "1")
	params.Set("ToAddress", to)
	params.Set("Subject", subject)
	params.Set("HtmlBody", body)
	if es.config.Email.FromName != "" {
		params.Set("FromAlias", es.config.Email.FromName)
	}

	// 计算签名
	signature := es.calculateAliyunSignature("POST", params)
	params.Set("Signature", signature)

	// 发送请求
	resp, err := es.client.PostForm(endpoint, params)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("aliyun API error: %s", string(bodyBytes))
	}

	// 检查返回是否有错误
	if strings.Contains(string(bodyBytes), "Code") {
		return fmt.Errorf("aliyun API error: %s", string(bodyBytes))
	}

	log.Printf("Email sent successfully to %s via Aliyun", to)
	return nil
}

// calculateAliyunSignature 计算阿里云 API 签名
func (es *EmailService) calculateAliyunSignature(method string, params url.Values) string {
	// 1. 参数排序
	keys := make([]string, 0, len(params))
	for k := range params {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	// 2. 构造待签名字符串
	var paramStr strings.Builder
	for i, k := range keys {
		if i > 0 {
			paramStr.WriteString("&")
		}
		paramStr.WriteString(url.QueryEscape(k))
		paramStr.WriteString("=")
		paramStr.WriteString(url.QueryEscape(params.Get(k)))
	}

	// 3. 构造待签名字符串
	stringToSign := method + "&" + url.QueryEscape("/") + "&" + url.QueryEscape(paramStr.String())

	// 4. 计算 HMAC-SHA1
	mac := hmac.New(sha1.New, []byte(es.config.Email.AliyunSecret+"&"))
	mac.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	return signature
}

// sendViaSMTP 通过SMTP发送
func (es *EmailService) sendViaSMTP(to, subject, body string) error {
	if es.config.Email.SMTPHost == "" || es.config.Email.SMTPUser == "" || es.config.Email.SMTPPassword == "" {
		return fmt.Errorf("SMTP configuration is incomplete")
	}

	// 构建邮件头
	header := make(map[string]string)
	header["From"] = fmt.Sprintf("%s <%s>", es.config.Email.FromName, es.config.Email.FromEmail)
	header["To"] = to
	header["Subject"] = subject
	header["MIME-Version"] = "1.0"
	header["Content-Type"] = "text/html; charset=utf-8"

	// 构造邮件内容
	var msg strings.Builder
	for k, v := range header {
		msg.WriteString(fmt.Sprintf("%s: %s\r\n", k, v))
	}
	msg.WriteString("\r\n")
	msg.WriteString(body)

	// 连接到 SMTP 服务器并发送
	addr := fmt.Sprintf("%s:%s", es.config.Email.SMTPHost, es.config.Email.SMTPPort)

	// 根据端口判断是否使用 TLS
	port := es.config.Email.SMTPPort
	var auth smtp.Auth
	if port == "465" {
		// 使用 SSL/TLS
		auth = smtp.PlainAuth("", es.config.Email.SMTPUser, es.config.Email.SMTPPassword, es.config.Email.SMTPHost)
		err := smtp.SendMail(addr, auth, es.config.Email.FromEmail, []string{to}, []byte(msg.String()))
		if err != nil {
			return fmt.Errorf("failed to send email via SMTP: %w", err)
		}
	} else {
		// 使用 STARTTLS
		auth = smtp.PlainAuth("", es.config.Email.SMTPUser, es.config.Email.SMTPPassword, es.config.Email.SMTPHost)

		// 建立连接
		conn, err := smtp.Dial(addr)
		if err != nil {
			return fmt.Errorf("failed to connect to SMTP server: %w", err)
		}
		defer conn.Close()

		// 进行 TLS 握手
		if err := conn.StartTLS(&tls.Config{ServerName: es.config.Email.SMTPHost}); err != nil {
			return fmt.Errorf("failed to start TLS: %w", err)
		}

		// 认证
		if err := conn.Auth(auth); err != nil {
			return fmt.Errorf("SMTP auth failed: %w", err)
		}

		// 发送邮件
		if err := conn.Mail(es.config.Email.FromEmail); err != nil {
			return fmt.Errorf("SMTP mail failed: %w", err)
		}
		if err := conn.Rcpt(to); err != nil {
			return fmt.Errorf("SMTP rcpt failed: %w", err)
		}

		w, err := conn.Data()
		if err != nil {
			return fmt.Errorf("SMTP data failed: %w", err)
		}
		_, err = w.Write([]byte(msg.String()))
		if err != nil {
			return fmt.Errorf("failed to write message: %w", err)
		}
		err = w.Close()
		if err != nil {
			return fmt.Errorf("failed to close message: %w", err)
		}
	}

	log.Printf("Email sent successfully to %s via SMTP", to)
	return nil
}
