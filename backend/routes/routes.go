package routes

import (
	"database/sql"

	"github.com/deadornot/backend/handlers"
	"github.com/deadornot/backend/services"
	"github.com/gin-gonic/gin"
)

// SetupRoutes 设置路由
func SetupRoutes(router *gin.Engine, db *sql.DB, notificationService *services.NotificationService, authService *services.AuthService) {
	api := router.Group("/api")
	{
		// 健康检查
		api.GET("/health", handlers.HealthCheck(db))

		// 认证相关
		authGroup := api.Group("/auth")
		{
			// 登录（不需要认证）
			authGroup.POST("/login", handlers.NewAuthHandler(authService).Login(db))
			// 刷新 Token（不需要认证，使用 refresh_token）
			authGroup.POST("/refresh", handlers.NewAuthHandler(authService).Refresh())
			// 注销（需要认证）
			authGroup.POST("/logout", handlers.AuthMiddleware(authService), handlers.NewAuthHandler(authService).Logout())
		}

		// 用户相关（需要Token认证）
		userGroup := api.Group("/user")
		userGroup.Use(handlers.AuthMiddleware(authService))
		{
			userGroup.GET("", handlers.GetUser(db))
			userGroup.PUT("", handlers.UpdateUser(db))
		}

		// 打卡相关（需要Token认证）
		checkinGroup := api.Group("/checkin")
		checkinGroup.Use(handlers.AuthMiddleware(authService))
		{
			checkinGroup.POST("", handlers.CheckIn(db))
			checkinGroup.GET("/history", handlers.GetCheckInHistory(db))
			checkinGroup.GET("/stats", handlers.GetCheckInStats(db))
		}
	}
}
