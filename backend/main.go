package main

import (
	"log"
	"os"

	"github.com/deadornot/backend/config"
	"github.com/deadornot/backend/database"
	"github.com/deadornot/backend/routes"
	"github.com/deadornot/backend/services"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Load configuration
	cfg := config.Load()

	// Initialize database
	db, err := database.InitDB(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	// Run database migrations
	if err := database.RunMigrations(db); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Initialize services
	pushService := services.NewPushService(cfg)
	emailService := services.NewEmailService(cfg)
	notificationService := services.NewNotificationService(db, emailService, pushService)
	schedulerService := services.NewSchedulerService(db, notificationService, cfg)

	// Start scheduler
	go schedulerService.Start()

	// Setup router
	router := gin.Default()

	// Setup routes
	routes.SetupRoutes(router, db, notificationService)

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
