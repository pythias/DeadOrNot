package config

import (
	"os"
)

type Config struct {
	Database DatabaseConfig
	APNs     APNsConfig
	Email    EmailConfig
	Server   ServerConfig
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
}

type APNsConfig struct {
	KeyID      string
	TeamID     string
	BundleID   string
	KeyPath    string
	Production bool
}

type EmailConfig struct {
	Provider     string // "aliyun" or "smtp"
	AliyunRegion string
	AliyunKey    string
	AliyunSecret string
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPassword string
	FromEmail    string
	FromName     string
}

type ServerConfig struct {
	Port string
}

func Load() *Config {
	return &Config{
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "3306"),
			User:     getEnv("DB_USER", "root"),
			Password: getEnv("DB_PASSWORD", ""),
			DBName:   getEnv("DB_NAME", "deadornot"),
		},
		APNs: APNsConfig{
			KeyID:      getEnv("APNS_KEY_ID", ""),
			TeamID:     getEnv("APNS_TEAM_ID", ""),
			BundleID:   getEnv("APNS_BUNDLE_ID", ""),
			KeyPath:    getEnv("APNS_KEY_PATH", ""),
			Production: getEnv("APNS_PRODUCTION", "false") == "true",
		},
		Email: EmailConfig{
			Provider:     getEnv("EMAIL_PROVIDER", "aliyun"),
			AliyunRegion: getEnv("ALIYUN_REGION", "cn-hangzhou"),
			AliyunKey:    getEnv("ALIYUN_ACCESS_KEY", ""),
			AliyunSecret: getEnv("ALIYUN_ACCESS_SECRET", ""),
			SMTPHost:     getEnv("SMTP_HOST", ""),
			SMTPPort:     getEnv("SMTP_PORT", "587"),
			SMTPUser:     getEnv("SMTP_USER", ""),
			SMTPPassword: getEnv("SMTP_PASSWORD", ""),
			FromEmail:    getEnv("FROM_EMAIL", ""),
			FromName:     getEnv("FROM_NAME", "死了么"),
		},
		Server: ServerConfig{
			Port: getEnv("PORT", "8080"),
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
