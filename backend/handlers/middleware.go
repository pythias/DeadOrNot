package handlers

import (
	"database/sql"
	"log"
	"net/http"
	"strings"

	"github.com/deadornot/backend/services"
	"github.com/gin-gonic/gin"
)

// AuthMiddleware Token认证中间件
func AuthMiddleware(authService *services.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 从 Authorization header 获取 token
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		// 解析 Bearer token
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization header format"})
			c.Abort()
			return
		}

		accessToken := parts[1]

		// 验证 token
		token, err := authService.ValidateAccessToken(accessToken)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
			c.Abort()
			return
		}

		// 将用户ID和设备ID存储到上下文
		c.Set("user_id", token.UserID)
		c.Set("device_id", token.DeviceID)
		c.Set("access_token", accessToken)

		// 查询用户时区
		var timezone string
		err = authService.DB.QueryRow(`
			SELECT timezone FROM users WHERE id = ?
		`, token.UserID).Scan(&timezone)
		if err != nil || timezone == "" {
			timezone = "UTC"
		}
		c.Set("timezone", timezone)

		c.Next()
	}
}

// DeviceIDMiddleware 设备ID中间件（保留作为备选，用于首次登录）
func DeviceIDMiddleware(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		deviceID := c.GetHeader("X-Device-ID")
		if deviceID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "X-Device-ID header is required"})
			c.Abort()
			return
		}

		// 查询或创建用户
		var userID int64
		var timezone string
		err := db.QueryRow(`
			SELECT id, timezone FROM users WHERE device_id = ?
		`, deviceID).Scan(&userID, &timezone)

		if err == sql.ErrNoRows {
			// 创建新用户
			result, err := db.Exec(`
				INSERT INTO users (device_id, timezone) VALUES (?, 'UTC')
			`, deviceID)
			if err != nil {
				log.Printf("Failed to create user: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
				c.Abort()
				return
			}
			userID, _ = result.LastInsertId()
			timezone = "UTC"
		} else if err != nil {
			log.Printf("Failed to query user: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			c.Abort()
			return
		}

		// 将用户ID和时区存储到上下文
		c.Set("user_id", userID)
		c.Set("device_id", deviceID)
		c.Set("timezone", timezone)

		c.Next()
	}
}
