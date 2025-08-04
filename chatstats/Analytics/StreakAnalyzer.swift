//
//  StreakAnalyzer.swift
//  chatstats
//
//  Created by Claude on 8/3/25.
//

import Foundation

class StreakAnalyzer {
    
    func computeStreaks(for messages: [Message]) -> StreakAnalysis {
        let myMessages = messages.filter { $0.isFromMe }
        
        let dailyMessageCounts = computeDailyMessageCounts(from: myMessages)
        let currentStreak = computeCurrentStreak(from: dailyMessageCounts)
        let longestStreak = computeLongestStreak(from: dailyMessageCounts)
        let activeDays = dailyMessageCounts.count
        let totalDays = computeTotalDaySpan(from: myMessages)
        let averageMessagesPerDay = computeAverageMessagesPerDay(from: dailyMessageCounts)
        
        return StreakAnalysis(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            averageMessagesPerDay: averageMessagesPerDay,
            activeDays: activeDays,
            totalDays: totalDays
        )
    }
    
    func getStreakDetails(for messages: [Message]) -> (current: StreakPeriod?, longest: StreakPeriod?) {
        let myMessages = messages.filter { $0.isFromMe }
        let dailyMessageCounts = computeDailyMessageCounts(from: myMessages)
        
        let currentStreakPeriod = findCurrentStreakPeriod(from: dailyMessageCounts)
        let longestStreakPeriod = findLongestStreakPeriod(from: dailyMessageCounts)
        
        return (current: currentStreakPeriod, longest: longestStreakPeriod)
    }
    
    func getDailyStreakCalendar(for messages: [Message]) -> [Date: Int] {
        let myMessages = messages.filter { $0.isFromMe }
        return computeDailyMessageCounts(from: myMessages)
    }
    
    private func computeDailyMessageCounts(from messages: [Message]) -> [Date: Int] {
        var dailyCounts: [Date: Int] = [:]
        let calendar = Calendar.current
        
        for message in messages {
            let day = calendar.startOfDay(for: message.date)
            dailyCounts[day, default: 0] += 1
        }
        
        return dailyCounts
    }
    
    private func computeCurrentStreak(from dailyCounts: [Date: Int]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var streakCount = 0
        var currentDate = today
        
        while dailyCounts[currentDate] != nil {
            streakCount += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streakCount
    }
    
    private func computeLongestStreak(from dailyCounts: [Date: Int]) -> Int {
        let sortedDates = dailyCounts.keys.sorted()
        guard !sortedDates.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var longestStreak = 1
        var currentStreak = 1
        
        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i - 1]
            let currentDate = sortedDates[i]
            
            if let daysDifference = calendar.dateComponents([.day], from: previousDate, to: currentDate).day,
               daysDifference == 1 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        
        return longestStreak
    }
    
    private func computeTotalDaySpan(from messages: [Message]) -> Int {
        guard let earliest = messages.min(by: { $0.date < $1.date })?.date,
              let latest = messages.max(by: { $0.date < $1.date })?.date else {
            return 0
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: earliest, to: latest)
        return (components.day ?? 0) + 1
    }
    
    private func computeAverageMessagesPerDay(from dailyCounts: [Date: Int]) -> Double {
        guard !dailyCounts.isEmpty else { return 0 }
        
        let totalMessages = dailyCounts.values.reduce(0, +)
        return Double(totalMessages) / Double(dailyCounts.count)
    }
    
    private func findCurrentStreakPeriod(from dailyCounts: [Date: Int]) -> StreakPeriod? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var startDate = today
        var endDate = today
        var currentDate = today
        
        while dailyCounts[currentDate] != nil {
            startDate = currentDate
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        guard dailyCounts[startDate] != nil else { return nil }
        
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let totalMessages = dailyCounts.filter { date, _ in
            date >= startDate && date <= endDate
        }.values.reduce(0, +)
        
        return StreakPeriod(
            startDate: startDate,
            endDate: endDate,
            days: days + 1,
            totalMessages: totalMessages
        )
    }
    
    private func findLongestStreakPeriod(from dailyCounts: [Date: Int]) -> StreakPeriod? {
        let sortedDates = dailyCounts.keys.sorted()
        guard !sortedDates.isEmpty else { return nil }
        
        let calendar = Calendar.current
        var longestPeriod: StreakPeriod?
        var currentStart = sortedDates[0]
        var currentEnd = sortedDates[0]
        var longestDays = 1
        
        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i - 1]
            let currentDate = sortedDates[i]
            
            if let daysDifference = calendar.dateComponents([.day], from: previousDate, to: currentDate).day,
               daysDifference == 1 {
                currentEnd = currentDate
            } else {
                let currentDays = calendar.dateComponents([.day], from: currentStart, to: currentEnd).day ?? 0
                if currentDays + 1 > longestDays {
                    longestDays = currentDays + 1
                    let totalMessages = dailyCounts.filter { date, _ in
                        date >= currentStart && date <= currentEnd
                    }.values.reduce(0, +)
                    
                    longestPeriod = StreakPeriod(
                        startDate: currentStart,
                        endDate: currentEnd,
                        days: longestDays,
                        totalMessages: totalMessages
                    )
                }
                currentStart = currentDate
                currentEnd = currentDate
            }
        }
        
        let finalDays = calendar.dateComponents([.day], from: currentStart, to: currentEnd).day ?? 0
        if finalDays + 1 > longestDays {
            let totalMessages = dailyCounts.filter { date, _ in
                date >= currentStart && date <= currentEnd
            }.values.reduce(0, +)
            
            longestPeriod = StreakPeriod(
                startDate: currentStart,
                endDate: currentEnd,
                days: finalDays + 1,
                totalMessages: totalMessages
            )
        }
        
        return longestPeriod
    }
}

struct StreakPeriod {
    let startDate: Date
    let endDate: Date
    let days: Int
    let totalMessages: Int
}