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

		var req struct {
			DateTime string `json:"datetime"` // RFC 3339 格式，可选
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		var checkInDateTime time.Time
		var err error

		if req.DateTime != "" {
			// 解析 RFC 3339 格式时间
			checkInDateTime, err = time.Parse(time.RFC3339, req.DateTime)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid datetime format, expected RFC 3339"})
				return
			}
		} else {
			// 如果没有提供时间，使用当前 UTC 时间
			checkInDateTime = time.Now().UTC()
		}

		// 转换为 UTC（确保是 UTC）
		checkInDateTime = checkInDateTime.UTC()

		// 检查同一天是否已打卡
		var exists bool
		err = db.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM checkins 
				WHERE user_id = ? AND DATE(checkin_datetime) = DATE(?)
			)
		`, userID, checkInDateTime).Scan(&exists)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		if exists {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Already checked in today"})
			return
		}

		// 插入打卡记录
		_, err = db.Exec(`
			INSERT INTO checkins (user_id, checkin_datetime) 
			VALUES (?, ?)
		`, userID, checkInDateTime)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check in"})
			return
		}

		// 返回 RFC 3339 格式的时间
		c.JSON(http.StatusOK, gin.H{
			"message":  "Check-in successful",
			"datetime": checkInDateTime.Format(time.RFC3339),
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

		query := "SELECT checkin_datetime FROM checkins WHERE user_id = ?"
		args := []interface{}{userID}

		if startDate != "" {
			query += " AND DATE(checkin_datetime) >= DATE(?)"
			startTime, _ := utils.ParseDateInTimezone(startDate, timezone)
			args = append(args, startTime)
		}

		if endDate != "" {
			query += " AND DATE(checkin_datetime) <= DATE(?)"
			endTime, _ := utils.ParseDateInTimezone(endDate, timezone)
			args = append(args, endTime)
		}

		query += " ORDER BY checkin_datetime DESC"

		rows, err := db.Query(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}
		defer rows.Close()

		var datetimes []string = []string{}
		for rows.Next() {
			var datetime time.Time
			if err := rows.Scan(&datetime); err != nil {
				continue
			}
			// 返回 RFC 3339 格式
			datetimes = append(datetimes, datetime.Format(time.RFC3339))
		}

		c.JSON(http.StatusOK, gin.H{"datetimes": datetimes})
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

		// 获取最后打卡时间
		var lastCheckIn sql.NullTime
		err := db.QueryRow(`
			SELECT MAX(checkin_datetime) FROM checkins WHERE user_id = ?
		`, userID).Scan(&lastCheckIn)

		if err != nil && err != sql.ErrNoRows {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		var lastCheckInDateTime *string
		var currentStreak int
		var totalDays int

		if lastCheckIn.Valid {
			// 返回 RFC 3339 格式
			datetimeStr := lastCheckIn.Time.Format(time.RFC3339)
			lastCheckInDateTime = &datetimeStr

			// 计算连续打卡天数
			daysSince, _ := utils.DaysSinceInTimezone(lastCheckIn.Time, timezone)

			if daysSince == 0 {
				// 今天已打卡，计算连续天数
				currentStreak = 1
				checkDateTime := lastCheckIn.Time
				for {
					checkDateTime = checkDateTime.AddDate(0, 0, -1)
					var exists bool
					err := db.QueryRow(`
						SELECT EXISTS(SELECT 1 FROM checkins WHERE user_id = ? AND DATE(checkin_datetime) = DATE(?))
					`, userID, checkDateTime).Scan(&exists)
					if err != nil || !exists {
						break
					}
					currentStreak++
				}
			}
		}

		// 获取总打卡天数（使用生成列 checkin_date 或 DATE 函数）
		err = db.QueryRow(`
			SELECT COUNT(DISTINCT DATE(checkin_datetime)) FROM checkins WHERE user_id = ?
		`, userID).Scan(&totalDays)

		if err != nil {
			totalDays = 0
		}

		c.JSON(http.StatusOK, gin.H{
			"current_streak":        currentStreak,
			"last_checkin_datetime": lastCheckInDateTime,
			"total_days":            totalDays,
		})
	}
}
