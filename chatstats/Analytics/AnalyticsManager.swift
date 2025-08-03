//
//  AnalyticsManager.swift
//  chatstats
//
//  Created by Claude on 8/3/25.
//

import Foundation

@MainActor
class AnalyticsManager: ObservableObject, AnalyticsService {
    
    private let responseTimeAnalyzer: ResponseTimeAnalyzer
    private let emojiAnalyzer: EmojiAnalyzer
    private let activityPatternAnalyzer: ActivityPatternAnalyzer
    private let streakAnalyzer: StreakAnalyzer
    private let groupChatAnalyzer: GroupChatAnalyzer
    
    init(
        responseTimeAnalyzer: ResponseTimeAnalyzer = ResponseTimeAnalyzer(),
        emojiAnalyzer: EmojiAnalyzer = EmojiAnalyzer(),
        activityPatternAnalyzer: ActivityPatternAnalyzer = ActivityPatternAnalyzer(),
        streakAnalyzer: StreakAnalyzer = StreakAnalyzer(),
        groupChatAnalyzer: GroupChatAnalyzer = GroupChatAnalyzer()
    ) {
        self.responseTimeAnalyzer = responseTimeAnalyzer
        self.emojiAnalyzer = emojiAnalyzer
        self.activityPatternAnalyzer = activityPatternAnalyzer
        self.streakAnalyzer = streakAnalyzer
        self.groupChatAnalyzer = groupChatAnalyzer
    }
    
    func computeResponseTimes(for messages: [Message]) -> [String: ResponseTimeStats] {
        return responseTimeAnalyzer.computeResponseTimes(for: messages)
    }
    
    func computeEmojiUsage(for messages: [Message]) -> [EmojiUsage] {
        return emojiAnalyzer.computeEmojiUsage(for: messages)
    }
    
    func computeActivityPatterns(for messages: [Message]) -> ActivityPatterns {
        return activityPatternAnalyzer.computeActivityPatterns(for: messages)
    }
    
    func computeStreaks(for messages: [Message]) -> StreakAnalysis {
        return streakAnalyzer.computeStreaks(for: messages)
    }
    
    func computeGroupChatEngagement(for messages: [Message]) -> GroupChatEngagement {
        return groupChatAnalyzer.computeGroupChatEngagement(for: messages)
    }
    
    func getFastestResponder(for messages: [Message]) -> (name: String, time: String)? {
        let responseStats = computeResponseTimes(for: messages)
        return responseTimeAnalyzer.getFastestResponder(from: responseStats)
    }
    
    func getSlowestResponder(for messages: [Message]) -> (name: String, time: String)? {
        let responseStats = computeResponseTimes(for: messages)
        return responseTimeAnalyzer.getSlowestResponder(from: responseStats)
    }
    
    func getTopEmojis(for messages: [Message], limit: Int = 5) -> [EmojiUsage] {
        return emojiAnalyzer.getTopEmojis(for: messages, limit: limit)
    }
    
    func getTopGroupChats(for messages: [Message], limit: Int = 10) -> [GroupChatStats] {
        return groupChatAnalyzer.getTopGroupChats(from: messages, limit: limit)
    }
    
    func getDayOfWeekHotspots(for messages: [Message]) -> [(day: String, count: Int, percentage: Double)] {
        return activityPatternAnalyzer.getDayOfWeekHotspots(for: messages)
    }
    
    func getStreakDetails(for messages: [Message]) -> (current: StreakPeriod?, longest: StreakPeriod?) {
        return streakAnalyzer.getStreakDetails(for: messages)
    }
    
    func getTopContact(for messages: [Message]) -> (name: String, count: Int)? {
        let chatGroups = Dictionary(grouping: messages) { $0.chatId }
        
        let oneOnOneChats = chatGroups.filter { chatId, chatMessages in
            let uniqueSenders = Set(chatMessages.map { $0.sender })
            return uniqueSenders.count <= 2 && chatId != "unknown_chat"
        }
        
        var senderMessageCounts: [String: Int] = [:]
        
        for (_, chatMessages) in oneOnOneChats {
            for message in chatMessages {
                if !message.isFromMe && message.sender != "Unknown" {
                    senderMessageCounts[message.sender, default: 0] += 1
                }
            }
        }
        
        let topContact = senderMessageCounts.max { $0.value < $1.value }
        
        if let contact = topContact {
            return (name: contact.key, count: contact.value)
        }
        return nil
    }
    
    func getRecentConversations(from messages: [Message]) -> [Conversation] {
        let groupedMessages = Dictionary(grouping: messages) { message in
            message.sender
        }
        
        let conversations = groupedMessages
            .filter { $0.key != "Me" && $0.key != "Unknown" }
            .map { (sender, messages) in
                let sortedMessages = messages.sorted { $0.date > $1.date }
                let lastMessage = sortedMessages.first!
                let messageCount = messages.count
                
                return Conversation(
                    chatId: sender,
                    name: sender,
                    lastMessage: lastMessage.text,
                    lastMessageDate: lastMessage.date,
                    messageCount: messageCount
                )
            }
            .sorted { $0.lastMessageDate > $1.lastMessageDate }
        
        return conversations
    }
}