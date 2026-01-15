package routes

import (
	"database/sql"

	"github.com/deadornot/backend/handlers"
	"github.com/deadornot/backend/services"
	"github.com/gin-gonic/gin"
)

// SetupRoutes 设置路由
func SetupRoutes(router *gin.Engine, db *sql.DB, notificationService *services.NotificationService) {
	api := router.Group("/api")
	{
		// 健康检查
		api.GET("/health", handlers.HealthCheck(db))

		// 用户相关
		userGroup := api.Group("/user")
		userGroup.Use(handlers.DeviceIDMiddleware(db))
		{
			userGroup.GET("", handlers.GetUser(db))
			userGroup.PUT("", handlers.UpdateUser(db))
		}

		// 打卡相关
		checkinGroup := api.Group("/checkin")
		checkinGroup.Use(handlers.DeviceIDMiddleware(db))
		{
			checkinGroup.POST("", handlers.CheckIn(db))
			checkinGroup.GET("/history", handlers.GetCheckInHistory(db))
			checkinGroup.GET("/stats", handlers.GetCheckInStats(db))
		}
	}
}
