package services

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/deadornot/backend/config"
	"github.com/deadornot/backend/models"
)

// TokenConfig Token配置
type TokenConfig struct {
	AccessTokenExpiry  time.Duration // Access Token 过期时间，默认 7 天
	RefreshTokenExpiry time.Duration // Refresh Token 过期时间，默认 30 天
}

// AuthService 认证服务
type AuthService struct {
	DB     *sql.DB
	config *config.Config
}

// NewAuthService 创建认证服务
func NewAuthService(db *sql.DB, cfg *config.Config) *AuthService {
	return &AuthService{
		DB:     db,
		config: cfg,
	}
}

// generateRandomString 生成随机字符串
func generateRandomString(length int) (string, error) {
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// Login 登录/注册
func (as *AuthService) Login(deviceID string) (*models.TokenResponse, error) {
	if deviceID == "" {
		return nil, errors.New("device_id is required")
	}

	// 查找或创建用户
	var userID int64
	err := as.DB.QueryRow(`
		SELECT id FROM users WHERE device_id = ?
	`, deviceID).Scan(&userID)

	if err == sql.ErrNoRows {
		// 创建新用户
		result, err := as.DB.Exec(`
			INSERT INTO users (device_id, timezone) VALUES (?, ?)
		`, deviceID, "UTC")
		if err != nil {
			return nil, fmt.Errorf("failed to create user: %w", err)
		}
		userID, err = result.LastInsertId()
		if err != nil {
			return nil, fmt.Errorf("failed to get user id: %w", err)
		}
	} else if err != nil {
		return nil, fmt.Errorf("failed to query user: %w", err)
	}

	// 生成 tokens
	accessToken, err := generateRandomString(32)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	refreshToken, err := generateRandomString(32)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// 设置过期时间
	accessTokenExpiry := 7 * 24 * time.Hour  // 7 天
	expiresAt := time.Now().Add(accessTokenExpiry)

	// 删除该设备的旧 tokens
	_, err = as.DB.Exec(`
		DELETE FROM tokens WHERE user_id = ? AND device_id = ?
	`, userID, deviceID)
	if err != nil {
		return nil, fmt.Errorf("failed to delete old tokens: %w", err)
	}

	// 插入新 token
	_, err = as.DB.Exec(`
		INSERT INTO tokens (user_id, device_id, access_token, refresh_token, token_type, expires_at)
		VALUES (?, ?, ?, ?, 'Bearer', ?)
	`, userID, deviceID, accessToken, refreshToken, expiresAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create token: %w", err)
	}

	return &models.TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int64(accessTokenExpiry.Seconds()),
	}, nil
}

// Refresh 刷新 Token
func (as *AuthService) Refresh(refreshToken string) (*models.TokenResponse, error) {
	if refreshToken == "" {
		return nil, errors.New("refresh_token is required")
	}

	// 查找 refresh token
	var token models.Token
	err := as.DB.QueryRow(`
		SELECT id, user_id, device_id, refresh_token, expires_at
		FROM tokens
		WHERE refresh_token = ?
	`, refreshToken).Scan(&token.ID, &token.UserID, &token.DeviceID, &token.RefreshToken, &token.ExpiresAt)

	if err == sql.ErrNoRows {
		return nil, errors.New("invalid refresh token")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to query token: %w", err)
	}

	// 检查是否过期
	if time.Now().After(token.ExpiresAt) {
		// 删除过期 token
		as.DB.Exec("DELETE FROM tokens WHERE id = ?", token.ID)
		return nil, errors.New("refresh token has expired")
	}

	// 生成新的 tokens
	accessToken, err := generateRandomString(32)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	newRefreshToken, err := generateRandomString(32)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// 设置过期时间
	accessTokenExpiry := 7 * 24 * time.Hour
	expiresAt := time.Now().Add(accessTokenExpiry)

	// 更新 token
	_, err = as.DB.Exec(`
		UPDATE tokens
		SET access_token = ?, refresh_token = ?, expires_at = ?, updated_at = NOW()
		WHERE id = ?
	`, accessToken, newRefreshToken, expiresAt, token.ID)
	if err != nil {
		return nil, fmt.Errorf("failed to update token: %w", err)
	}

	return &models.TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int64(accessTokenExpiry.Seconds()),
	}, nil
}

// ValidateAccessToken 验证 Access Token
func (as *AuthService) ValidateAccessToken(accessToken string) (*models.Token, error) {
	if accessToken == "" {
		return nil, errors.New("access_token is required")
	}

	var token models.Token
	err := as.DB.QueryRow(`
		SELECT id, user_id, device_id, access_token, refresh_token, token_type, expires_at
		FROM tokens
		WHERE access_token = ?
	`, accessToken).Scan(
		&token.ID,
		&token.UserID,
		&token.DeviceID,
		&token.AccessToken,
		&token.RefreshToken,
		&token.TokenType,
		&token.ExpiresAt,
	)

	if err == sql.ErrNoRows {
		return nil, errors.New("invalid access token")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to query token: %w", err)
	}

	// 检查是否过期
	if time.Now().After(token.ExpiresAt) {
		return nil, errors.New("access token has expired")
	}

	return &token, nil
}

// Logout 注销
func (as *AuthService) Logout(accessToken string) error {
	if accessToken == "" {
		return errors.New("access_token is required")
	}

	_, err := as.DB.Exec(`
		DELETE FROM tokens WHERE access_token = ?
	`, accessToken)
	if err != nil {
		return fmt.Errorf("failed to logout: %w", err)
	}

	return nil
}

// GetUserIDByToken 通过 token 获取用户 ID
func (as *AuthService) GetUserIDByToken(accessToken string) (int64, error) {
	token, err := as.ValidateAccessToken(accessToken)
	if err != nil {
		return 0, err
	}
	return token.UserID, nil
}
