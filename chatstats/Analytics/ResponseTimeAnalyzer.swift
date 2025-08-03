//
//  ResponseTimeAnalyzer.swift
//  chatstats
//
//  Created by Claude on 8/3/25.
//

import Foundation

class ResponseTimeAnalyzer {
    
    func computeResponseTimes(for messages: [Message]) -> [String: ResponseTimeStats] {
        var responseTimes: [String: [TimeInterval]] = [:]
        
        let topContacts = getTopContactsYouMessaged(from: messages, limit: 20)
        let conversationGroups = Dictionary(grouping: messages) { $0.chatId }
        
        for (chatId, conversationMessages) in conversationGroups {
            let uniqueSenders = Set(conversationMessages.map { $0.sender })
            if uniqueSenders.count >= 3 {
                continue
            }
            
            let sortedMessages = conversationMessages.sorted { $0.date < $1.date }
            
            for i in 0..<(sortedMessages.count - 1) {
                let currentMessage = sortedMessages[i]
                let nextMessage = sortedMessages[i + 1]
                
                if currentMessage.isFromMe && !nextMessage.isFromMe {
                    guard topContacts.contains(nextMessage.sender) else { continue }
                    
                    let responseTime = nextMessage.date.timeIntervalSince(currentMessage.date)
                    
                    if responseTime > 0 && responseTime < 86400 {
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
                let sortedTimes = times.sorted()
                let average = times.reduce(0, +) / Double(times.count)
                let median = sortedTimes[sortedTimes.count / 2]
                let p95Index = Int(Double(sortedTimes.count) * 0.95)
                let p95 = sortedTimes[min(p95Index, sortedTimes.count - 1)]
                let fastest = sortedTimes.first ?? 0
                let slowest = sortedTimes.last ?? 0
                
                responseStats[sender] = ResponseTimeStats(
                    averageSeconds: average,
                    medianSeconds: median,
                    p95Seconds: p95,
                    fastestSeconds: fastest,
                    slowestSeconds: slowest,
                    totalResponses: times.count
                )
            }
        }
        
        return responseStats
    }
    
    func getFastestResponder(from responseStats: [String: ResponseTimeStats]) -> (name: String, time: String)? {
        guard let fastest = responseStats.min(by: { $0.value.averageSeconds < $1.value.averageSeconds }) else { return nil }
        return (name: fastest.key, time: formatResponseTime(fastest.value.averageSeconds))
    }
    
    func getSlowestResponder(from responseStats: [String: ResponseTimeStats]) -> (name: String, time: String)? {
        guard let slowest = responseStats.max(by: { $0.value.averageSeconds < $1.value.averageSeconds }) else { return nil }
        return (name: slowest.key, time: formatResponseTime(slowest.value.averageSeconds))
    }
    
    private func getTopContactsYouMessaged(from messages: [Message], limit: Int = 20) -> Set<String> {
        let myMessages = messages.filter { $0.isFromMe }
        let chatGroups = Dictionary(grouping: myMessages) { $0.chatId }
        
        let oneOnOneChats = chatGroups.filter { chatId, chatMessages in
            let allMessagesInChat = messages.filter { $0.chatId == chatId }
            let uniqueSenders = Set(allMessagesInChat.map { $0.sender })
            return uniqueSenders.count <= 2 && chatId != "unknown_chat"
        }
        
        var senderMessageCounts: [String: Int] = [:]
        
        for (_, chatMessages) in oneOnOneChats {
            for message in chatMessages {
                let allMessagesInChat = messages.filter { $0.chatId == message.chatId }
                let otherPerson = allMessagesInChat.first { !$0.isFromMe }?.sender
                
                if let otherPerson = otherPerson, otherPerson != "Unknown" {
                    senderMessageCounts[otherPerson, default: 0] += 1
                }
            }
        }
        
        let topContacts = senderMessageCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
        
        return Set(topContacts)
    }
    
    private func formatResponseTime(_ timeInterval: TimeInterval) -> String {
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
}