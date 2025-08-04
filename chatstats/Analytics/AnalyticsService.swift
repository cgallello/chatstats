//
//  AnalyticsService.swift
//  chatstats
//
//  Created by Claude on 8/3/25.
//

import Foundation

protocol AnalyticsService {
    func computeResponseTimes(for messages: [Message]) -> [String: ResponseTimeStats]
    func computeEmojiUsage(for messages: [Message]) -> [EmojiUsage]
    func computeActivityPatterns(for messages: [Message]) -> ActivityPatterns
    func computeStreaks(for messages: [Message]) -> StreakAnalysis
    func computeGroupChatEngagement(for messages: [Message]) -> GroupChatEngagement
}

struct ResponseTimeStats {
    let averageSeconds: TimeInterval
    let medianSeconds: TimeInterval
    let p95Seconds: TimeInterval
    let fastestSeconds: TimeInterval
    let slowestSeconds: TimeInterval
    let totalResponses: Int
}

struct EmojiUsage {
    let emoji: String
    let count: Int
    let percentage: Double
}

struct ActivityPatterns {
    let nightOwlScore: Double
    let earlyBirdScore: Double
    let mostActiveHour: Int
    let dayOfWeekStats: [String: Int]
    let hourlyDistribution: [Int: Int]
}

struct StreakAnalysis {
    let currentStreak: Int
    let longestStreak: Int
    let averageMessagesPerDay: Double
    let activeDays: Int
    let totalDays: Int
}

struct GroupChatEngagement {
    let topGroupChats: [GroupChatStats]
    let averageParticipation: Double
    let totalGroupChats: Int
}

struct GroupChatStats {
    let name: String
    let displayName: String?
    let groupId: String?
    let totalMessages: Int
    let myMessageCount: Int
    let myPercentage: Double
    let topMessenger: String
    let topMessengerCount: Int
    let topMessengerPercentage: Double
    let participants: [String]
    let engagementScore: Double
}