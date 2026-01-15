package utils

import (
	"time"
)

// GetTodayInTimezone 获取指定时区的今天日期（返回该时区今天的开始时间，UTC）
func GetTodayInTimezone(timezone string) (time.Time, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return time.Time{}, err
	}

	now := time.Now().In(loc)
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	return today.UTC(), nil
}

// GetTimeInTimezone 获取指定时区的指定时间（返回UTC时间）
func GetTimeInTimezone(timezone string, hour, minute int) (time.Time, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return time.Time{}, err
	}

	now := time.Now().In(loc)
	targetTime := time.Date(now.Year(), now.Month(), now.Day(), hour, minute, 0, 0, loc)
	return targetTime.UTC(), nil
}

// ParseDateInTimezone 在指定时区解析日期字符串（格式：yyyy-MM-dd）
func ParseDateInTimezone(dateStr string, timezone string) (time.Time, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return time.Time{}, err
	}

	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return time.Time{}, err
	}

	// 将日期设置为该时区的午夜
	dateInTZ := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, loc)
	return dateInTZ.UTC(), nil
}

// DaysSinceInTimezone 计算指定时区下距离某个日期的天数
func DaysSinceInTimezone(date time.Time, timezone string) (int, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return 0, err
	}

	now := time.Now().In(loc)
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)

	dateInTZ := date.In(loc)
	dateOnly := time.Date(dateInTZ.Year(), dateInTZ.Month(), dateInTZ.Day(), 0, 0, 0, 0, loc)

	days := int(today.Sub(dateOnly).Hours() / 24)
	return days, nil
}

// GetDateStringInTimezone 获取指定时区下某个UTC时间的日期字符串（yyyy-MM-dd）
func GetDateStringInTimezone(utcTime time.Time, timezone string) (string, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return "", err
	}

	timeInTZ := utcTime.In(loc)
	return timeInTZ.Format("2006-01-02"), nil
}
