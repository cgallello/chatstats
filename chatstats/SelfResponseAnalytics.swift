//
//  SelfResponseAnalytics.swift
//  chatstats
//
//  Created by Claude on 8/4/25.
//

import Foundation

// MARK: - Response Time Models

struct ResponseTimeStats {
    let contactName: String
    let averageSeconds: TimeInterval
    let medianSeconds: TimeInterval
    let p95Seconds: TimeInterval
    let totalResponses: Int
    let fastestResponse: TimeInterval
    let slowestResponse: TimeInterval
}

struct BidirectionalResponseTimes {
    let contactName: String
    let theirResponseToYou: ResponseTimeStats?
    let yourResponseToThem: ResponseTimeStats?
    
    var hasData: Bool {
        return theirResponseToYou != nil || yourResponseToThem != nil
    }
    
    var responseRatio: Double? {
        guard let their = theirResponseToYou?.averageSeconds,
              let yours = yourResponseToThem?.averageSeconds else { return nil }
        return yours / their // > 1.0 means you're slower, < 1.0 means you're faster
    }
    
    var whoIsFaster: String? {
        guard let ratio = responseRatio else { return nil }
        if abs(ratio - 1.0) < 0.1 { // Within 10% difference
            return "Similar speed"
        } else if ratio < 1.0 {
            return "You're faster"
        } else {
            return "They're faster"
        }
    }
}

// MARK: - Self Response Analytics Engine

class SelfResponseAnalytics {
    
    // MARK: - Main Self-Response Calculation
    
    static func calculateSelfResponseTimes(for messages: [Message]) -> [String: ResponseTimeStats] {
        var responseTimes: [String: [TimeInterval]] = [:]
        
        // Get top contacts that you message with
        let topContacts = getTopMutualContacts(from: messages, limit: 20)
        
        // Group messages by chatId to handle conversations
        let conversationGroups = Dictionary(grouping: messages) { $0.chatId }
        
        for (_, conversationMessages) in conversationGroups {
            // Skip group chats (chats with 3+ participants)
            let uniqueSenders = Set(conversationMessages.map { $0.sender })
            if uniqueSenders.count >= 3 {
                continue
            }
            
            // Sort messages by date
            let sortedMessages = conversationMessages.sorted { $0.date < $1.date }
            
            for i in 0..<(sortedMessages.count - 1) {
                let currentMessage = sortedMessages[i]
                let nextMessage = sortedMessages[i + 1]
                
                // Check if current message is from contact and next is from me (user)
                if !currentMessage.isFromMe && nextMessage.isFromMe {
                    // Only calculate for top contacts
                    guard topContacts.contains(currentMessage.sender) else { continue }
                    
                    let responseTime = nextMessage.date.timeIntervalSince(currentMessage.date)
                    
                    // Handle edge cases: exclude very long gaps (>72 hours)
                    let maxResponseTime: TimeInterval = 72 * 3600 // 72 hours in seconds
                    if responseTime > 0 && responseTime < maxResponseTime {
                        if responseTimes[currentMessage.sender] == nil {
                            responseTimes[currentMessage.sender] = []
                        }
                        responseTimes[currentMessage.sender]?.append(responseTime)
                    }
                }
            }
        }
        
        // Calculate comprehensive statistics
        var responseStats: [String: ResponseTimeStats] = [:]
        for (sender, times) in responseTimes {
            if !times.isEmpty && sender != "Me" && sender != "Unknown" {
                let stats = calculateResponseStats(for: sender, responseTimes: times)
                responseStats[sender] = stats
            }
        }
        
        return responseStats
    }
    
    // MARK: - Bidirectional Response Analysis
    
    static func calculateBidirectionalResponseTimes(for messages: [Message]) -> [BidirectionalResponseTimes] {
        let selfResponseTimes = calculateSelfResponseTimes(for: messages)
        let contactResponseTimes = calculateContactResponseTimes(for: messages)
        
        // Get all unique contacts from both directions
        let allContacts = Set(selfResponseTimes.keys).union(Set(contactResponseTimes.keys))
        
        var bidirectionalStats: [BidirectionalResponseTimes] = []
        
        for contact in allContacts {
            let bidirectional = BidirectionalResponseTimes(
                contactName: contact,
                theirResponseToYou: contactResponseTimes[contact],
                yourResponseToThem: selfResponseTimes[contact]
            )
            
            if bidirectional.hasData {
                bidirectionalStats.append(bidirectional)
            }
        }
        
        // Sort by who has the most complete data
        return bidirectionalStats.sorted { (lhs, rhs) in
            let lhsScore = (lhs.theirResponseToYou != nil ? 1 : 0) + (lhs.yourResponseToThem != nil ? 1 : 0)
            let rhsScore = (rhs.theirResponseToYou != nil ? 1 : 0) + (rhs.yourResponseToThem != nil ? 1 : 0)
            
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            
            // If equal, sort by fastest average response (either direction)
            let lhsFastest = [lhs.theirResponseToYou?.averageSeconds, lhs.yourResponseToThem?.averageSeconds]
                .compactMap { $0 }.min() ?? Double.infinity
            let rhsFastest = [rhs.theirResponseToYou?.averageSeconds, rhs.yourResponseToThem?.averageSeconds]
                .compactMap { $0 }.min() ?? Double.infinity
            
            return lhsFastest < rhsFastest
        }
    }
    
    // MARK: - Contact Response Times (for comparison)
    
    private static func calculateContactResponseTimes(for messages: [Message]) -> [String: ResponseTimeStats] {
        var responseTimes: [String: [TimeInterval]] = [:]
        
        let topContacts = getTopMutualContacts(from: messages, limit: 20)
        let conversationGroups = Dictionary(grouping: messages) { $0.chatId }
        
        for (_, conversationMessages) in conversationGroups {
            let uniqueSenders = Set(conversationMessages.map { $0.sender })
            if uniqueSenders.count >= 3 { continue }
            
            let sortedMessages = conversationMessages.sorted { $0.date < $1.date }
            
            for i in 0..<(sortedMessages.count - 1) {
                let currentMessage = sortedMessages[i]
                let nextMessage = sortedMessages[i + 1]
                
                // Contact responding to user
                if currentMessage.isFromMe && !nextMessage.isFromMe {
                    guard topContacts.contains(nextMessage.sender) else { continue }
                    
                    let responseTime = nextMessage.date.timeIntervalSince(currentMessage.date)
                    let maxResponseTime: TimeInterval = 72 * 3600
                    
                    if responseTime > 0 && responseTime < maxResponseTime {
                        if responseTimes[nextMessage.sender] == nil {
                            responseTimes[nextMessage.sender] = []
                        }
                        responseTimes[nextMessage.sender]?.append(responseTime)
                    }
                }
            }
        }
        
        var responseStats: [String: ResponseTimeStats] = [:]
        for (sender, times) in responseTimes {
            if !times.isEmpty && sender != "Me" && sender != "Unknown" {
                responseStats[sender] = calculateResponseStats(for: sender, responseTimes: times)
            }
        }
        
        return responseStats
    }
    
    // MARK: - Statistical Calculations
    
    private static func calculateResponseStats(for contactName: String, responseTimes: [TimeInterval]) -> ResponseTimeStats {
        guard !responseTimes.isEmpty else {
            return ResponseTimeStats(
                contactName: contactName,
                averageSeconds: 0,
                medianSeconds: 0,
                p95Seconds: 0,
                totalResponses: 0,
                fastestResponse: 0,
                slowestResponse: 0
            )
        }
        
        let sortedTimes = responseTimes.sorted()
        
        // Calculate average
        let average = responseTimes.reduce(0, +) / Double(responseTimes.count)
        
        // Calculate median
        let median: TimeInterval
        if sortedTimes.count % 2 == 0 {
            let mid = sortedTimes.count / 2
            median = (sortedTimes[mid - 1] + sortedTimes[mid]) / 2
        } else {
            median = sortedTimes[sortedTimes.count / 2]
        }
        
        // Calculate P95 (95th percentile)
        let p95Index = Int(Double(sortedTimes.count) * 0.95)
        let p95 = sortedTimes[min(p95Index, sortedTimes.count - 1)]
        
        // Get fastest and slowest
        let fastest = sortedTimes.first ?? 0
        let slowest = sortedTimes.last ?? 0
        
        return ResponseTimeStats(
            contactName: contactName,
            averageSeconds: average,
            medianSeconds: median,
            p95Seconds: p95,
            totalResponses: responseTimes.count,
            fastestResponse: fastest,
            slowestResponse: slowest
        )
    }
    
    // MARK: - Helper Functions
    
    private static func getTopMutualContacts(from messages: [Message], limit: Int) -> Set<String> {
        // Get contacts where there's mutual messaging (both directions)
        let messageGroups = Dictionary(grouping: messages) { $0.chatId }
        
        var mutualContacts: [String: Int] = [:]
        
        for (_, chatMessages) in messageGroups {
            // Skip group chats
            let uniqueSenders = Set(chatMessages.map { $0.sender })
            if uniqueSenders.count >= 3 { continue }
            
            // Check if there are messages in both directions
            let hasMyMessages = chatMessages.contains { $0.isFromMe }
            let hasTheirMessages = chatMessages.contains { !$0.isFromMe }
            
            if hasMyMessages && hasTheirMessages {
                // Find the contact (not "Me")
                if let contact = uniqueSenders.first(where: { $0 != "Me" && $0 != "Unknown" }) {
                    mutualContacts[contact, default: 0] += chatMessages.count
                }
            }
        }
        
        // Get top contacts by message volume
        let topContacts = mutualContacts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
        
        return Set(topContacts)
    }
    
    // MARK: - Utility Functions
    
    static func formatResponseTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    static func getResponseSpeedCategory(_ timeInterval: TimeInterval) -> (category: String, color: String) {
        let minutes = timeInterval / 60
        
        switch minutes {
        case 0..<1:
            return ("Lightning ⚡", "green")
        case 1..<5:
            return ("Very Fast 🚀", "green")
        case 5..<15:
            return ("Fast 🏃", "blue")
        case 15..<60:
            return ("Moderate 🚶", "orange")
        case 60..<240:
            return ("Slow 🐌", "red")
        default:
            return ("Very Slow 🐢", "red")
        }
    }
    
    static func getTopSelfResponders(from responseStats: [String: ResponseTimeStats], limit: Int = 5) -> [ResponseTimeStats] {
        return Array(responseStats.values
            .sorted { $0.averageSeconds < $1.averageSeconds }
            .prefix(limit))
    }
    
    static func getSlowestSelfResponders(from responseStats: [String: ResponseTimeStats], limit: Int = 5) -> [ResponseTimeStats] {
        return Array(responseStats.values
            .sorted { $0.averageSeconds > $1.averageSeconds }
            .prefix(limit))
    }
}