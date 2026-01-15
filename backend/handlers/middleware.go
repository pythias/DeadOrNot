package handlers

import (
	"database/sql"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

// DeviceIDMiddleware 设备ID中间件，从Header提取设备ID并验证/创建用户
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
