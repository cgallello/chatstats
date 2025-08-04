//
//  chatstatsTests.swift
//  chatstatsTests
//
//  Created by Christopher Gallello on 7/18/25.
//

import Testing
@testable import chatstats
import Foundation

struct chatstatsTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    // MARK: - Streak Analytics Tests
    
    @Test func testStreakCalculation_NoMessages() async throws {
        let messages: [Message] = []
        let streakStats = StreakAnalytics.calculateStreaks(for: messages)
        
        #expect(streakStats.isEmpty)
    }
    
    @Test func testStreakCalculation_SingleDayConversation() async throws {
        let today = Date()
        let messages = createTestMessages(
            chatId: "test_chat",
            conversationName: "Test User",
            dates: [today],
            hasMutualExchange: true
        )
        
        let streakStats = StreakAnalytics.calculateStreaks(for: messages)
        
        #expect(streakStats.count == 1)
        let streak = streakStats[0]
        #expect(streak.currentStreak == 1)
        #expect(streak.longestStreak == 1)
        #expect(streak.conversationId == "test_chat")
        #expect(!streak.streakBroken)
    }
    
    @Test func testStreakCalculation_ConsecutiveDays() async throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!
        
        let messages = createTestMessages(
            chatId: "test_chat",
            conversationName: "Test User",
            dates: [dayBefore, yesterday, today],
            hasMutualExchange: true
        )
        
        let streakStats = StreakAnalytics.calculateStreaks(for: messages)
        
        #expect(streakStats.count == 1)
        let streak = streakStats[0]
        #expect(streak.currentStreak == 3)
        #expect(streak.longestStreak == 3)
        #expect(!streak.streakBroken)
    }
    
    @Test func testStreakCalculation_BrokenStreak() async throws {
        let calendar = Calendar.current
        let today = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        
        // Gap between fourDaysAgo and today (missing 2 days)
        let messages = createTestMessages(
            chatId: "test_chat",
            conversationName: "Test User",
            dates: [fourDaysAgo, threeDaysAgo, today],
            hasMutualExchange: true
        )
        
        let streakStats = StreakAnalytics.calculateStreaks(for: messages)
        
        #expect(streakStats.count == 1)
        let streak = streakStats[0]
        #expect(streak.currentStreak == 1) // Only today
        #expect(streak.longestStreak == 2) // fourDaysAgo and threeDaysAgo
    }
    
    @Test func testStreakCalculation_OnlyOneWayMessages() async throws {
        let today = Date()
        let messages = [
            createMessage(date: today, isFromMe: true, chatId: "test_chat", sender: "Me"),
            createMessage(date: today, isFromMe: true, chatId: "test_chat", sender: "Me")
        ]
        
        let streakStats = StreakAnalytics.calculateStreaks(for: messages)
        
        // Should be empty because there's no mutual exchange
        #expect(streakStats.isEmpty)
    }
    
    @Test func testStreakCalculation_MultipleConversations() async throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let messagesChat1 = createTestMessages(
            chatId: "chat1",
            conversationName: "User 1",
            dates: [yesterday, today],
            hasMutualExchange: true
        )
        
        let messagesChat2 = createTestMessages(
            chatId: "chat2", 
            conversationName: "User 2",
            dates: [today],
            hasMutualExchange: true
        )
        
        let allMessages = messagesChat1 + messagesChat2
        let streakStats = StreakAnalytics.calculateStreaks(for: allMessages)
        
        #expect(streakStats.count == 2)
        
        // Should be sorted by current streak (descending)
        #expect(streakStats[0].currentStreak >= streakStats[1].currentStreak)
        
        let chat1Stats = streakStats.first { $0.conversationId == "chat1" }
        let chat2Stats = streakStats.first { $0.conversationId == "chat2" }
        
        #expect(chat1Stats?.currentStreak == 2)
        #expect(chat2Stats?.currentStreak == 1)
    }
    
    @Test func testStreakUtilityFunctions() async throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let messages = createTestMessages(
            chatId: "test_chat",
            conversationName: "Test User",
            dates: [yesterday, today],
            hasMutualExchange: true
        )
        
        let streakStats = StreakAnalytics.calculateStreaks(for: messages)
        
        // Test getTopStreaks
        let topStreaks = StreakAnalytics.getTopStreaks(from: streakStats, limit: 1)
        #expect(topStreaks.count == 1)
        
        // Test getActiveStreaks
        let activeStreaks = StreakAnalytics.getActiveStreaks(from: streakStats)
        #expect(activeStreaks.count == 1)
        #expect(activeStreaks[0].currentStreak > 0)
        
        // Test getLongestAllTimeStreak
        let longestStreak = StreakAnalytics.getLongestAllTimeStreak(from: streakStats)
        #expect(longestStreak != nil)
        #expect(longestStreak?.longestStreak == 2)
    }
    
    @Test func testStreakFormatting() async throws {
        #expect(StreakAnalytics.formatStreak(0) == "No streak")
        #expect(StreakAnalytics.formatStreak(1) == "1 day")
        #expect(StreakAnalytics.formatStreak(5) == "5 days")
        #expect(StreakAnalytics.formatStreak(100) == "100 days")
    }
    
    @Test func testStreakEmojis() async throws {
        #expect(StreakAnalytics.getStreakEmoji(for: 0, isBroken: false) == "💔")
        #expect(StreakAnalytics.getStreakEmoji(for: 5, isBroken: true) == "💔")
        #expect(StreakAnalytics.getStreakEmoji(for: 1, isBroken: false) == "🔥")
        #expect(StreakAnalytics.getStreakEmoji(for: 5, isBroken: false) == "🚀")
        #expect(StreakAnalytics.getStreakEmoji(for: 10, isBroken: false) == "⭐")
        #expect(StreakAnalytics.getStreakEmoji(for: 20, isBroken: false) == "💎")
        #expect(StreakAnalytics.getStreakEmoji(for: 50, isBroken: false) == "👑")
        #expect(StreakAnalytics.getStreakEmoji(for: 100, isBroken: false) == "🏆")
    }
    
    // MARK: - Helper Functions for Testing
    
    private func createTestMessages(
        chatId: String,
        conversationName: String,
        dates: [Date],
        hasMutualExchange: Bool
    ) -> [Message] {
        var messages: [Message] = []
        
        for date in dates {
            if hasMutualExchange {
                // Add message from me
                messages.append(createMessage(
                    date: date,
                    isFromMe: true,
                    chatId: chatId,
                    sender: "Me"
                ))
                
                // Add message from other person
                messages.append(createMessage(
                    date: Calendar.current.date(byAdding: .minute, value: 30, to: date) ?? date,
                    isFromMe: false,
                    chatId: chatId,
                    sender: conversationName
                ))
            } else {
                // Add only one-way message
                messages.append(createMessage(
                    date: date,
                    isFromMe: true,
                    chatId: chatId,
                    sender: "Me"
                ))
            }
        }
        
        return messages
    }
    
    private func createMessage(
        date: Date,
        isFromMe: Bool,
        chatId: String,
        sender: String
    ) -> Message {
        return Message(
            guid: UUID().uuidString,
            text: "Test message",
            date: date,
            sender: sender,
            isFromMe: isFromMe,
            chatId: chatId,
            chatDisplayName: nil,
            chatGroupId: nil
        )
    }
}
