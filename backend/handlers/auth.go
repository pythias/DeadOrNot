package handlers

import (
	"database/sql"
	"net/http"

	"github.com/deadornot/backend/services"
	"github.com/gin-gonic/gin"
)

// AuthHandler 认证处理器
type AuthHandler struct {
	authService *services.AuthService
}

// NewAuthHandler 创建认证处理器
func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

// Login 登录
func (h *AuthHandler) Login(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			DeviceID string `json:"device_id"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		// 优先使用请求中的 device_id，否则使用 header 中的
		deviceID := req.DeviceID
		if deviceID == "" {
			deviceID = c.GetHeader("X-Device-ID")
		}

		if deviceID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "device_id is required"})
			return
		}

		tokenResponse, err := h.authService.Login(deviceID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, tokenResponse)
	}
}

// Refresh 刷新 Token
func (h *AuthHandler) Refresh() gin.HandlerFunc {
	return func(c *gin.Context) {
		var req struct {
			RefreshToken string `json:"refresh_token"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		tokenResponse, err := h.authService.Refresh(req.RefreshToken)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, tokenResponse)
	}
}

// Logout 注销
func (h *AuthHandler) Logout() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 从 context 中获取 token（在中间件中设置的）
		token := c.GetString("access_token")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}

		err := h.authService.Logout(token)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
	}
}
