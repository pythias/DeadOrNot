package handlers

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/deadornot/backend/utils"
	"github.com/gin-gonic/gin"
)

// CheckIn 打卡
func CheckIn(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetInt64("user_id")
		timezone := c.GetString("timezone")
		if timezone == "" {
			timezone = "UTC"
		}

		var req struct {
			Date string `json:"date"` // yyyy-MM-dd格式，可选
		}

		c.ShouldBindJSON(&req)

		var checkInDate time.Time
		var err error

		if req.Date != "" {
			// 使用提供的日期
			checkInDate, err = utils.ParseDateInTimezone(req.Date, timezone)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format"})
				return
			}
		} else {
			// 使用今天
			checkInDate, err = utils.GetTodayInTimezone(timezone)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get today's date"})
				return
			}
		}

		// 插入打卡记录（使用ON DUPLICATE KEY UPDATE处理重复）
		_, err = db.Exec(`
			INSERT INTO checkins (user_id, checkin_date) 
			VALUES (?, DATE(?))
			ON DUPLICATE KEY UPDATE created_at = created_at
		`, userID, checkInDate)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check in"})
			return
		}

		dateStr, _ := utils.GetDateStringInTimezone(checkInDate, timezone)
		c.JSON(http.StatusOK, gin.H{
			"message": "Check-in successful",
			"date":    dateStr,
		})
	}
}

// GetCheckInHistory 获取打卡记录
func GetCheckInHistory(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetInt64("user_id")
		timezone := c.GetString("timezone")
		if timezone == "" {
			timezone = "UTC"
		}

		startDate := c.Query("start_date")
		endDate := c.Query("end_date")

		query := "SELECT checkin_date FROM checkins WHERE user_id = ?"
		args := []interface{}{userID}

		if startDate != "" {
			query += " AND checkin_date >= DATE(?)"
			startTime, _ := utils.ParseDateInTimezone(startDate, timezone)
			args = append(args, startTime)
		}

		if endDate != "" {
			query += " AND checkin_date <= DATE(?)"
			endTime, _ := utils.ParseDateInTimezone(endDate, timezone)
			args = append(args, endTime)
		}

		query += " ORDER BY checkin_date DESC"

		rows, err := db.Query(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}
		defer rows.Close()

		var dates []string
		for rows.Next() {
			var date time.Time
			if err := rows.Scan(&date); err != nil {
				continue
			}
			dateStr, _ := utils.GetDateStringInTimezone(date, timezone)
			dates = append(dates, dateStr)
		}

		c.JSON(http.StatusOK, gin.H{"dates": dates})
	}
}

// GetCheckInStats 获取打卡统计
func GetCheckInStats(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetInt64("user_id")
		timezone := c.GetString("timezone")
		if timezone == "" {
			timezone = "UTC"
		}

		// 获取最后打卡日期
		var lastCheckIn sql.NullTime
		err := db.QueryRow(`
			SELECT MAX(checkin_date) FROM checkins WHERE user_id = ?
		`, userID).Scan(&lastCheckIn)

		if err != nil && err != sql.ErrNoRows {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		var lastCheckInDate *string
		var currentStreak int
		var totalDays int

		if lastCheckIn.Valid {
			dateStr, _ := utils.GetDateStringInTimezone(lastCheckIn.Time, timezone)
			lastCheckInDate = &dateStr

			// 计算连续打卡天数
			daysSince, _ := utils.DaysSinceInTimezone(lastCheckIn.Time, timezone)

			if daysSince == 0 {
				// 今天已打卡，计算连续天数
				currentStreak = 1
				checkDate := lastCheckIn.Time
				for {
					checkDate = checkDate.AddDate(0, 0, -1)
					var exists bool
					err := db.QueryRow(`
						SELECT EXISTS(SELECT 1 FROM checkins WHERE user_id = ? AND checkin_date = DATE(?))
					`, userID, checkDate).Scan(&exists)
					if err != nil || !exists {
						break
					}
					currentStreak++
				}
			}
		}

		// 获取总打卡天数
		err = db.QueryRow(`
			SELECT COUNT(DISTINCT checkin_date) FROM checkins WHERE user_id = ?
		`, userID).Scan(&totalDays)

		if err != nil {
			totalDays = 0
		}

		c.JSON(http.StatusOK, gin.H{
			"current_streak":    currentStreak,
			"last_checkin_date": lastCheckInDate,
			"total_days":        totalDays,
		})
	}
}
