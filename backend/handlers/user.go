package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/deadornot/backend/models"
	"github.com/gin-gonic/gin"
)

// GetUser 获取用户信息
func GetUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetInt64("user_id")

		var user models.User
		var emailsJSON string
		var apnsToken sql.NullString
		err := db.QueryRow(`
			SELECT id, device_id, name, emergency_contact_emails, apns_token, 
			       push_enabled, email_enabled, timezone, created_at, updated_at
			FROM users WHERE id = ?
		`, userID).Scan(
			&user.ID, &user.DeviceID, &user.Name, &emailsJSON,
			&apnsToken, &user.PushEnabled, &user.EmailEnabled,
			&user.Timezone, &user.CreatedAt, &user.UpdatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		// 处理可能为 NULL 的 apns_token
		if apnsToken.Valid {
			user.APNSToken = apnsToken.String
		} else {
			user.APNSToken = ""
		}

		// 解析JSON字段
		if err := json.Unmarshal([]byte(emailsJSON), &user.EmergencyContactEmails); err != nil {
			user.EmergencyContactEmails = []string{}
		}

		c.JSON(http.StatusOK, user)
	}
}

// UpdateUser 更新用户设置
func UpdateUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetInt64("user_id")

		var req struct {
			Name                   string   `json:"name"`
			EmergencyContactEmails []string `json:"emergency_contact_emails"`
			APNSToken              string   `json:"apns_token"`
			PushEnabled            *bool    `json:"push_enabled"`
			EmailEnabled           *bool    `json:"email_enabled"`
			Timezone               string   `json:"timezone"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// 限制紧急联系人数量
		if len(req.EmergencyContactEmails) > 3 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Maximum 3 emergency contact emails allowed"})
			return
		}

		// 构建更新SQL
		updates := []string{}
		args := []interface{}{}

		if req.Name != "" {
			updates = append(updates, "name = ?")
			args = append(args, req.Name)
		}

		if req.EmergencyContactEmails != nil {
			emailsJSON, _ := json.Marshal(req.EmergencyContactEmails)
			updates = append(updates, "emergency_contact_emails = ?")
			args = append(args, string(emailsJSON))
		}

		if req.APNSToken != "" {
			updates = append(updates, "apns_token = ?")
			args = append(args, req.APNSToken)
		}

		if req.PushEnabled != nil {
			updates = append(updates, "push_enabled = ?")
			args = append(args, *req.PushEnabled)
		}

		if req.EmailEnabled != nil {
			updates = append(updates, "email_enabled = ?")
			args = append(args, *req.EmailEnabled)
		}

		if req.Timezone != "" {
			updates = append(updates, "timezone = ?")
			args = append(args, req.Timezone)
		}

		if len(updates) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "No fields to update"})
			return
		}

		args = append(args, userID)

		query := "UPDATE users SET " + joinStrings(updates, ", ") + " WHERE id = ?"
		_, err := db.Exec(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "User updated successfully"})
	}
}

func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += sep + strs[i]
	}
	return result
}
