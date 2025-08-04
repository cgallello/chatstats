//
//  StreakAnalytics.swift
//  chatstats
//
//  Created by Claude on 8/4/25.
//

import Foundation
import SwiftData

// MARK: - Streak Models

struct StreakStats {
    let conversationId: String
    let conversationName: String
    let currentStreak: Int
    let longestStreak: Int
    let lastMessageDate: Date
    let streakBroken: Bool
    let currentStreakStartDate: Date?
    let longestStreakStartDate: Date?
    let longestStreakEndDate: Date?
}

struct DayStreakInfo {
    let date: Date
    let hasMessage: Bool
    let messageCount: Int
}

// MARK: - Streak Analytics Engine

class StreakAnalytics {
    
    // MARK: - Main Streak Calculation
    
    static func calculateStreaks(for messages: [Message]) -> [StreakStats] {
        // Group messages by conversation (chatId)
        let conversationGroups = Dictionary(grouping: messages) { $0.chatId }
        
        var streakStats: [StreakStats] = []
        
        for (chatId, conversationMessages) in conversationGroups {
            // Skip unknown chats and ensure we have a reasonable conversation name
            guard chatId != "unknown_chat" else { continue }
            
            // Get conversation name from the messages
            let conversationName = getConversationName(from: conversationMessages)
            
            // Calculate streaks for this conversation
            if let stats = calculateConversationStreaks(
                conversationId: chatId,
                conversationName: conversationName,
                messages: conversationMessages
            ) {
                streakStats.append(stats)
            }
        }
        
        return streakStats.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    // MARK: - Individual Conversation Streak Calculation
    
    private static func calculateConversationStreaks(
        conversationId: String,
        conversationName: String,
        messages: [Message]
    ) -> StreakStats? {
        
        // Filter to only mutual conversations (both sent and received messages)
        let myMessages = messages.filter { $0.isFromMe }
        let theirMessages = messages.filter { !$0.isFromMe }
        
        // Skip if no mutual conversation
        guard !myMessages.isEmpty && !theirMessages.isEmpty else { return nil }
        
        // Create daily activity map
        let dailyActivity = createDailyActivityMap(from: messages)
        
        // Calculate current and longest streaks
        let currentStreak = calculateCurrentStreak(from: dailyActivity)
        let (longestStreak, longestStreakStart, longestStreakEnd) = calculateLongestStreak(from: dailyActivity)
        
        // Determine if streak is broken (no activity yesterday)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayKey = calendar.startOfDay(for: yesterday)
        let streakBroken = currentStreak == 0 || (dailyActivity[yesterdayKey] == nil)
        
        // Find current streak start date
        let currentStreakStartDate = findCurrentStreakStartDate(from: dailyActivity, streakLength: currentStreak)
        
        // Get last message date
        let lastMessageDate = messages.map { $0.date }.max() ?? Date()
        
        return StreakStats(
            conversationId: conversationId,
            conversationName: conversationName,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastMessageDate: lastMessageDate,
            streakBroken: streakBroken,
            currentStreakStartDate: currentStreakStartDate,
            longestStreakStartDate: longestStreakStart,
            longestStreakEndDate: longestStreakEnd
        )
    }
    
    // MARK: - Daily Activity Mapping
    
    private static func createDailyActivityMap(from messages: [Message]) -> [Date: DayStreakInfo] {
        let calendar = Calendar.current
        var dailyActivity: [Date: DayStreakInfo] = [:]
        
        // Group messages by day
        let messagesByDay = Dictionary(grouping: messages) { message in
            calendar.startOfDay(for: message.date)
        }
        
        for (day, dayMessages) in messagesByDay {
            // A day counts for streak if there's at least one message in each direction
            let hasMyMessage = dayMessages.contains { $0.isFromMe }
            let hasTheirMessage = dayMessages.contains { !$0.isFromMe }
            let hasMessage = hasMyMessage && hasTheirMessage
            
            dailyActivity[day] = DayStreakInfo(
                date: day,
                hasMessage: hasMessage,
                messageCount: dayMessages.count
            )
        }
        
        return dailyActivity
    }
    
    // MARK: - Current Streak Calculation
    
    private static func calculateCurrentStreak(from dailyActivity: [Date: DayStreakInfo]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var currentStreak = 0
        var currentDate = today
        
        // Check if today has activity, if not start from yesterday
        if dailyActivity[today]?.hasMessage != true {
            currentDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }
        
        // Count backwards while there's consecutive daily activity
        while let dayInfo = dailyActivity[currentDate], dayInfo.hasMessage {
            currentStreak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return currentStreak
    }
    
    // MARK: - Longest Streak Calculation
    
    private static func calculateLongestStreak(from dailyActivity: [Date: DayStreakInfo]) -> (length: Int, startDate: Date?, endDate: Date?) {
        let sortedDays = dailyActivity.keys.sorted()
        
        guard !sortedDays.isEmpty else { return (0, nil, nil) }
        
        let calendar = Calendar.current
        var longestStreak = 0
        var longestStreakStart: Date?
        var longestStreakEnd: Date?
        
        var currentStreak = 0
        var currentStreakStart: Date?
        
        // Iterate through all possible consecutive days
        let startDate = sortedDays.first!
        let endDate = sortedDays.last!
        
        var currentDate = startDate
        while currentDate <= endDate {
            if let dayInfo = dailyActivity[currentDate], dayInfo.hasMessage {
                // Extend current streak
                if currentStreak == 0 {
                    currentStreakStart = currentDate
                }
                currentStreak += 1
            } else {
                // Streak broken, check if it was the longest
                if currentStreak > longestStreak {
                    longestStreak = currentStreak
                    longestStreakStart = currentStreakStart
                    longestStreakEnd = calendar.date(byAdding: .day, value: -1, to: currentDate)
                }
                currentStreak = 0
                currentStreakStart = nil
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Check final streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
            longestStreakStart = currentStreakStart
            longestStreakEnd = endDate
        }
        
        return (longestStreak, longestStreakStart, longestStreakEnd)
    }
    
    // MARK: - Helper Functions
    
    private static func findCurrentStreakStartDate(from dailyActivity: [Date: DayStreakInfo], streakLength: Int) -> Date? {
        guard streakLength > 0 else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Start from today or yesterday if today has no activity
        var startDate = today
        if dailyActivity[today]?.hasMessage != true {
            startDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }
        
        // Go back (streakLength - 1) days to find start
        return calendar.date(byAdding: .day, value: -(streakLength - 1), to: startDate)
    }
    
    private static func getConversationName(from messages: [Message]) -> String {
        // Try to get a meaningful conversation name
        let otherParticipants = Set(messages.map { $0.sender }.filter { $0 != "Me" && $0 != "Unknown" })
        
        if otherParticipants.count == 1 {
            // 1-on-1 conversation
            return otherParticipants.first ?? "Unknown Contact"
        } else if otherParticipants.count > 1 {
            // Group conversation - try to use chat display name if available
            if let displayName = messages.first?.chatDisplayName, !displayName.isEmpty {
                return displayName
            }
            // Fallback to participant list
            let participants = Array(otherParticipants.prefix(2))
            if otherParticipants.count > 2 {
                return "\(participants.joined(separator: ", ")) + \(otherParticipants.count - 2) more"
            } else {
                return participants.joined(separator: ", ")
            }
        }
        
        return "Unknown Conversation"
    }
    
    // MARK: - Utility Functions
    
    static func getTopStreaks(from streakStats: [StreakStats], limit: Int = 5) -> [StreakStats] {
        return Array(streakStats.sorted { $0.currentStreak > $1.currentStreak }.prefix(limit))
    }
    
    static func getActiveStreaks(from streakStats: [StreakStats]) -> [StreakStats] {
        return streakStats.filter { $0.currentStreak > 0 && !$0.streakBroken }
    }
    
    static func getLongestAllTimeStreak(from streakStats: [StreakStats]) -> StreakStats? {
        return streakStats.max { $0.longestStreak < $1.longestStreak }
    }
    
    static func formatStreak(_ days: Int) -> String {
        switch days {
        case 0:
            return "No streak"
        case 1:
            return "1 day"
        default:
            return "\(days) days"
        }
    }
    
    static func getStreakEmoji(for streak: Int, isBroken: Bool) -> String {
        if isBroken || streak == 0 {
            return "💔"
        }
        
        switch streak {
        case 1...2:
            return "🔥"
        case 3...6:
            return "🚀"
        case 7...13:
            return "⭐"
        case 14...29:
            return "💎"
        case 30...99:
            return "👑"
        default:
            return "🏆"
        }
    }
}