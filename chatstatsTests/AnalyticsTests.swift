//
//  AnalyticsTests.swift
//  chatstatsTests
//
//  Created by Claude on 8/3/25.
//

import XCTest
@testable import chatstats
import Foundation

final class AnalyticsTests: XCTestCase {
    
    var sampleMessages: [Message]!
    var responseTimeAnalyzer: ResponseTimeAnalyzer!
    var emojiAnalyzer: EmojiAnalyzer!
    var activityPatternAnalyzer: ActivityPatternAnalyzer!
    var streakAnalyzer: StreakAnalyzer!
    var groupChatAnalyzer: GroupChatAnalyzer!
    var analyticsManager: AnalyticsManager!
    
    override func setUp() {
        super.setUp()
        
        responseTimeAnalyzer = ResponseTimeAnalyzer()
        emojiAnalyzer = EmojiAnalyzer()
        activityPatternAnalyzer = ActivityPatternAnalyzer()
        streakAnalyzer = StreakAnalyzer()
        groupChatAnalyzer = GroupChatAnalyzer()
        analyticsManager = AnalyticsManager()
        
        sampleMessages = createSampleMessages()
    }
    
    override func tearDown() {
        sampleMessages = nil
        responseTimeAnalyzer = nil
        emojiAnalyzer = nil
        activityPatternAnalyzer = nil
        streakAnalyzer = nil
        groupChatAnalyzer = nil
        analyticsManager = nil
        super.tearDown()
    }
    
    func testResponseTimeAnalyzer() {
        let responseStats = responseTimeAnalyzer.computeResponseTimes(for: sampleMessages)
        
        XCTAssertFalse(responseStats.isEmpty, "Response stats should not be empty")
        
        for (contact, stats) in responseStats {
            XCTAssertFalse(contact.isEmpty, "Contact name should not be empty")
            XCTAssertGreaterThan(stats.totalResponses, 0, "Total responses should be greater than 0")
            XCTAssertGreaterThan(stats.averageSeconds, 0, "Average response time should be positive")
            XCTAssertGreaterThanOrEqual(stats.medianSeconds, 0, "Median response time should be non-negative")
            XCTAssertGreaterThanOrEqual(stats.p95Seconds, stats.medianSeconds, "P95 should be >= median")
        }
    }
    
    func testEmojiAnalyzer() {
        let emojiUsage = emojiAnalyzer.computeEmojiUsage(for: sampleMessages)
        
        XCTAssertFalse(emojiUsage.isEmpty, "Emoji usage should not be empty")
        
        var totalPercentage: Double = 0
        for usage in emojiUsage {
            XCTAssertFalse(usage.emoji.isEmpty, "Emoji should not be empty")
            XCTAssertGreaterThan(usage.count, 0, "Emoji count should be positive")
            XCTAssertGreaterThan(usage.percentage, 0, "Emoji percentage should be positive")
            totalPercentage += usage.percentage
        }
        
        XCTAssertLessThanOrEqual(totalPercentage, 100.1, "Total percentage should not exceed 100%")
        
        let topEmojis = emojiAnalyzer.getTopEmojis(for: sampleMessages, limit: 3)
        XCTAssertLessThanOrEqual(topEmojis.count, 3, "Should return at most 3 emojis")
        
        let diversity = emojiAnalyzer.getEmojiDiversity(for: sampleMessages)
        XCTAssertGreaterThanOrEqual(diversity.uniqueEmojis, 0, "Unique emojis should be non-negative")
        XCTAssertGreaterThanOrEqual(diversity.totalEmojis, diversity.uniqueEmojis, "Total should be >= unique")
        XCTAssertGreaterThanOrEqual(diversity.diversityScore, 0, "Diversity score should be non-negative")
        XCTAssertLessThanOrEqual(diversity.diversityScore, 1, "Diversity score should be <= 1")
    }
    
    func testActivityPatternAnalyzer() {
        let patterns = activityPatternAnalyzer.computeActivityPatterns(for: sampleMessages)
        
        XCTAssertGreaterThanOrEqual(patterns.nightOwlScore, 0, "Night owl score should be non-negative")
        XCTAssertLessThanOrEqual(patterns.nightOwlScore, 100, "Night owl score should be <= 100")
        XCTAssertGreaterThanOrEqual(patterns.earlyBirdScore, 0, "Early bird score should be non-negative")
        XCTAssertLessThanOrEqual(patterns.earlyBirdScore, 100, "Early bird score should be <= 100")
        XCTAssertGreaterThanOrEqual(patterns.mostActiveHour, 0, "Most active hour should be >= 0")
        XCTAssertLessThan(patterns.mostActiveHour, 24, "Most active hour should be < 24")
        
        XCTAssertFalse(patterns.dayOfWeekStats.isEmpty, "Day of week stats should not be empty")
        XCTAssertFalse(patterns.hourlyDistribution.isEmpty, "Hourly distribution should not be empty")
        
        let hotspots = activityPatternAnalyzer.getDayOfWeekHotspots(for: sampleMessages)
        XCTAssertFalse(hotspots.isEmpty, "Day of week hotspots should not be empty")
        
        var totalPercentage: Double = 0
        for hotspot in hotspots {
            XCTAssertFalse(hotspot.day.isEmpty, "Day name should not be empty")
            XCTAssertGreaterThan(hotspot.count, 0, "Count should be positive")
            XCTAssertGreaterThan(hotspot.percentage, 0, "Percentage should be positive")
            totalPercentage += hotspot.percentage
        }
        
        XCTAssertEqual(totalPercentage, 100, accuracy: 0.1, "Total percentage should be 100%")
    }
    
    func testStreakAnalyzer() {
        let streaks = streakAnalyzer.computeStreaks(for: sampleMessages)
        
        XCTAssertGreaterThanOrEqual(streaks.currentStreak, 0, "Current streak should be non-negative")
        XCTAssertGreaterThanOrEqual(streaks.longestStreak, streaks.currentStreak, "Longest streak should be >= current")
        XCTAssertGreaterThan(streaks.averageMessagesPerDay, 0, "Average messages per day should be positive")
        XCTAssertGreaterThan(streaks.activeDays, 0, "Active days should be positive")
        XCTAssertGreaterThanOrEqual(streaks.totalDays, streaks.activeDays, "Total days should be >= active days")
        
        let streakDetails = streakAnalyzer.getStreakDetails(for: sampleMessages)
        if let currentStreak = streakDetails.current {
            XCTAssertGreaterThan(currentStreak.days, 0, "Current streak days should be positive")
            XCTAssertGreaterThan(currentStreak.totalMessages, 0, "Current streak messages should be positive")
        }
        
        if let longestStreak = streakDetails.longest {
            XCTAssertGreaterThan(longestStreak.days, 0, "Longest streak days should be positive")
            XCTAssertGreaterThan(longestStreak.totalMessages, 0, "Longest streak messages should be positive")
        }
        
        let dailyCalendar = streakAnalyzer.getDailyStreakCalendar(for: sampleMessages)
        XCTAssertFalse(dailyCalendar.isEmpty, "Daily calendar should not be empty")
    }
    
    func testGroupChatAnalyzer() {
        let engagement = groupChatAnalyzer.computeGroupChatEngagement(for: sampleMessages)
        
        XCTAssertGreaterThanOrEqual(engagement.totalGroupChats, 0, "Total group chats should be non-negative")
        XCTAssertGreaterThanOrEqual(engagement.averageParticipation, 0, "Average participation should be non-negative")
        
        let topGroupChats = groupChatAnalyzer.getTopGroupChats(from: sampleMessages, limit: 5)
        XCTAssertLessThanOrEqual(topGroupChats.count, 5, "Should return at most 5 group chats")
        
        for groupChat in topGroupChats {
            XCTAssertFalse(groupChat.name.isEmpty, "Group chat name should not be empty")
            XCTAssertGreaterThan(groupChat.totalMessages, 0, "Total messages should be positive")
            XCTAssertGreaterThanOrEqual(groupChat.myMessageCount, 0, "My message count should be non-negative")
            XCTAssertGreaterThanOrEqual(groupChat.myPercentage, 0, "My percentage should be non-negative")
            XCTAssertLessThanOrEqual(groupChat.myPercentage, 100, "My percentage should be <= 100")
            XCTAssertGreaterThanOrEqual(groupChat.participants.count, 3, "Group chat should have >= 3 participants")
            XCTAssertGreaterThanOrEqual(groupChat.engagementScore, 0, "Engagement score should be non-negative")
        }
        
        let participationAnalysis = groupChatAnalyzer.getGroupChatParticipationAnalysis(for: sampleMessages)
        XCTAssertGreaterThanOrEqual(participationAnalysis.totalGroupChats, 0, "Total group chats should be non-negative")
        XCTAssertGreaterThanOrEqual(participationAnalysis.averageParticipantCount, 0, "Average participant count should be non-negative")
        XCTAssertGreaterThanOrEqual(participationAnalysis.myAverageParticipation, 0, "My average participation should be non-negative")
    }
    
    func testAnalyticsManager() {
        let responseStats = analyticsManager.computeResponseTimes(for: sampleMessages)
        XCTAssertFalse(responseStats.isEmpty, "Response stats should not be empty")
        
        let emojiUsage = analyticsManager.computeEmojiUsage(for: sampleMessages)
        XCTAssertFalse(emojiUsage.isEmpty, "Emoji usage should not be empty")
        
        let activityPatterns = analyticsManager.computeActivityPatterns(for: sampleMessages)
        XCTAssertGreaterThanOrEqual(activityPatterns.nightOwlScore, 0, "Night owl score should be non-negative")
        
        let streaks = analyticsManager.computeStreaks(for: sampleMessages)
        XCTAssertGreaterThanOrEqual(streaks.currentStreak, 0, "Current streak should be non-negative")
        
        let groupChatEngagement = analyticsManager.computeGroupChatEngagement(for: sampleMessages)
        XCTAssertGreaterThanOrEqual(groupChatEngagement.totalGroupChats, 0, "Total group chats should be non-negative")
        
        let topContact = analyticsManager.getTopContact(for: sampleMessages)
        if let contact = topContact {
            XCTAssertFalse(contact.name.isEmpty, "Top contact name should not be empty")
            XCTAssertGreaterThan(contact.count, 0, "Top contact count should be positive")
        }
        
        let conversations = analyticsManager.getRecentConversations(from: sampleMessages)
        XCTAssertFalse(conversations.isEmpty, "Recent conversations should not be empty")
    }
    
    private func createSampleMessages() -> [Message] {
        let calendar = Calendar.current
        let now = Date()
        
        var messages: [Message] = []
        
        for i in 0..<100 {
            let messageDate = calendar.date(byAdding: .hour, value: -i, to: now) ?? now
            let isFromMe = i % 3 == 0
            let sender = isFromMe ? "Me" : (i % 2 == 0 ? "Alice" : "Bob")
            let chatId = i < 30 ? "group_chat_1" : (i < 60 ? "one_on_one_alice" : "one_on_one_bob")
            
            let emojiTexts = ["Hello! 😊", "Great job! 👏🎉", "Thanks 🙏", "Awesome! 🔥", "See you later! 👋"]
            let regularTexts = ["Hello there", "How are you?", "Thanks for the help", "Looking forward to it", "Talk soon"]
            
            let text = i % 5 == 0 ? emojiTexts[i % emojiTexts.count] : regularTexts[i % regularTexts.count]
            
            let message = Message(
                guid: "msg_\(i)",
                text: text,
                date: messageDate,
                sender: sender,
                isFromMe: isFromMe,
                chatId: chatId,
                chatDisplayName: chatId.contains("group") ? "Test Group Chat" : nil,
                chatGroupId: chatId.contains("group") ? "group_id_1" : nil
            )
            
            messages.append(message)
        }
        
        for i in 100..<130 {
            let messageDate = calendar.date(byAdding: .hour, value: -(i-100), to: now) ?? now
            let message = Message(
                guid: "group_msg_\(i)",
                text: "Group message \(i)",
                date: messageDate,
                sender: ["Charlie", "Diana", "Eve"][i % 3],
                isFromMe: false,
                chatId: "group_chat_2",
                chatDisplayName: "Another Group Chat",
                chatGroupId: "group_id_2"
            )
            messages.append(message)
        }
        
        return messages
    }
}