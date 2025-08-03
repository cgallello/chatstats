//
//  GroupChatAnalyzer.swift
//  chatstats
//
//  Created by Claude on 8/3/25.
//

import Foundation

class GroupChatAnalyzer {
    
    func computeGroupChatEngagement(for messages: [Message]) -> GroupChatEngagement {
        let groupChatStats = getTopGroupChats(from: messages)
        let totalGroupChats = groupChatStats.count
        
        let averageParticipation = groupChatStats.isEmpty ? 0.0 :
            groupChatStats.map(\.myPercentage).reduce(0, +) / Double(groupChatStats.count)
        
        return GroupChatEngagement(
            topGroupChats: groupChatStats,
            averageParticipation: averageParticipation,
            totalGroupChats: totalGroupChats
        )
    }
    
    func getTopGroupChats(from messages: [Message], limit: Int = 10) -> [GroupChatStats] {
        let chatGroups = Dictionary(grouping: messages) { $0.chatId }
        var groupChats: [GroupChatStats] = []
        
        for (chatId, chatMessages) in chatGroups {
            if chatId == "unknown_chat" {
                continue
            }
            
            let uniqueSenders = Set(chatMessages.map { $0.sender })
            
            if uniqueSenders.count >= 3 {
                let messageCounts = Dictionary(grouping: chatMessages) { $0.sender }
                    .mapValues { $0.count }
                
                let totalMessages = chatMessages.count
                let myMessageCount = chatMessages.filter { $0.isFromMe }.count
                let myPercentage = totalMessages > 0 ? (Double(myMessageCount) / Double(totalMessages)) * 100 : 0
                
                let topMessengerEntry = messageCounts
                    .filter { $0.key != "Me" && $0.key != "Unknown" }
                    .max { $0.value < $1.value }
                
                let topMessenger = topMessengerEntry?.key ?? "Unknown"
                let topMessengerCount = topMessengerEntry?.value ?? 0
                let topMessengerPercentage = totalMessages > 0 ? (Double(topMessengerCount) / Double(totalMessages)) * 100 : 0
                
                let participants = Array(uniqueSenders.filter { $0 != "Unknown" })
                let chatDisplayName = chatMessages.first?.chatDisplayName
                let chatGroupId = chatMessages.first?.chatGroupId
                
                let otherParticipants = participants.filter { $0 != "Me" }
                let groupChatName = if let displayName = chatDisplayName, !displayName.isEmpty {
                    displayName
                } else if otherParticipants.count <= 2 {
                    otherParticipants.joined(separator: ", ")
                } else {
                    "\(otherParticipants.prefix(2).joined(separator: ", ")) + \(otherParticipants.count - 2) more"
                }
                
                let engagementScore = computeEngagementScore(
                    myPercentage: myPercentage,
                    totalMessages: totalMessages,
                    participantCount: participants.count
                )
                
                let groupChatStats = GroupChatStats(
                    name: groupChatName,
                    displayName: chatDisplayName,
                    groupId: chatGroupId,
                    totalMessages: totalMessages,
                    myMessageCount: myMessageCount,
                    myPercentage: myPercentage,
                    topMessenger: topMessenger,
                    topMessengerCount: topMessengerCount,
                    topMessengerPercentage: topMessengerPercentage,
                    participants: participants,
                    engagementScore: engagementScore
                )
                
                groupChats.append(groupChatStats)
            }
        }
        
        return Array(groupChats.sorted { $0.totalMessages > $1.totalMessages }.prefix(limit))
    }
    
    func getGroupChatParticipationAnalysis(for messages: [Message]) -> GroupChatParticipationAnalysis {
        let groupChats = getTopGroupChats(from: messages)
        
        let totalGroupChats = groupChats.count
        let averageParticipantCount = groupChats.isEmpty ? 0.0 :
            groupChats.map { Double($0.participants.count) }.reduce(0, +) / Double(groupChats.count)
        
        let myAverageParticipation = groupChats.isEmpty ? 0.0 :
            groupChats.map(\.myPercentage).reduce(0, +) / Double(groupChats.count)
        
        let mostActiveGroupChat = groupChats.max(by: { $0.totalMessages < $1.totalMessages })
        let highestParticipationGroupChat = groupChats.max(by: { $0.myPercentage < $1.myPercentage })
        
        return GroupChatParticipationAnalysis(
            totalGroupChats: totalGroupChats,
            averageParticipantCount: averageParticipantCount,
            myAverageParticipation: myAverageParticipation,
            mostActiveGroupChat: mostActiveGroupChat,
            highestParticipationGroupChat: highestParticipationGroupChat
        )
    }
    
    private func computeEngagementScore(myPercentage: Double, totalMessages: Int, participantCount: Int) -> Double {
        let expectedParticipation = 100.0 / Double(participantCount)
        let participationRatio = myPercentage / expectedParticipation
        let activityWeight = min(Double(totalMessages) / 100.0, 1.0)
        
        return participationRatio * activityWeight * 100
    }
}

struct GroupChatParticipationAnalysis {
    let totalGroupChats: Int
    let averageParticipantCount: Double
    let myAverageParticipation: Double
    let mostActiveGroupChat: GroupChatStats?
    let highestParticipationGroupChat: GroupChatStats?
}