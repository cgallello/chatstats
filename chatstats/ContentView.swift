//
//  ContentView.swift
//  chatstats
//
//  Created by Christopher Gallello on 7/18/25.
//

import SwiftUI
import SwiftData
import Charts

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [Message]
    @StateObject private var importService: MessageImportService
    @State private var lastRefreshTime = Date()
    
    init() {
        // Create a temporary context for initialization, will be updated in onAppear
        let tempContext = ModelContext(try! ModelContainer(for: Message.self, Contact.self))
        self._importService = StateObject(wrappedValue: MessageImportService(modelContext: tempContext))
    }
    
    var body: some View {
        VStack {
            if messages.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "message.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("No Messages Imported")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Tap the button below to import your iMessage data")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        Task {
                            await importService.importMessages()
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Messages")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(importService.isImporting)
                    
                    // Show status message (including errors) even when not importing
                    if !importService.importStatus.isEmpty {
                        VStack(spacing: 10) {
                            if importService.isImporting {
                                ProgressView(value: importService.importProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .frame(width: 200)
                            }
                            
                            Text(importService.importStatus)
                                .font(.caption)
                                .foregroundColor(importService.importStatus.contains("denied") || importService.importStatus.contains("failed") ? .red : .secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Title
                        HStack {
                            Text("Messages (\(messages.count))")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await importService.importMessages()
                                    lastRefreshTime = Date() // Trigger UI update
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh Messages")
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(importService.isImporting)
                            
                            Button(action: {
                                Task {
                                    await clearCache()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear Cache")
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(importService.isImporting)
                        }
                        .padding(.horizontal)
                        
                        // Chart Section
                        MessagesChartView(messages: messages)
                            .padding(.horizontal)
                        
                        // Statistics Section
                        VStack(spacing: 16) {
                            if let topContact = getTopContact() {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Most Active Conversation")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        HStack {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.blue)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(topContact.name)
                                                    .font(.title2)
                                                    .fontWeight(.medium)
                                                Text("\(topContact.count) messages")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // Response Time Metrics
                            HStack(spacing: 16) {
                                // Fastest Responder
                                if let fastestResponder = getFastestResponder() {
                                    VStack(alignment: .leading) {
                                        Text("Fastest Responder")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        HStack {
                                            Image(systemName: "bolt.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.green)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(fastestResponder.name)
                                                    .font(.title2)
                                                    .fontWeight(.medium)
                                                Text("Avg: \(fastestResponder.time)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                
                                // Slowest Responder
                                if let slowestResponder = getSlowestResponder() {
                                    VStack(alignment: .leading) {
                                        Text("Slowest Responder")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        HStack {
                                            Image(systemName: "tortoise.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.orange)
                                        
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(slowestResponder.name)
                                                    .font(.title2)
                                                    .fontWeight(.medium)
                                                Text("Avg: \(slowestResponder.time)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Top Group Chats Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Top 10 Group Chats")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                let topGroupChats = getTopGroupChats()
                                if topGroupChats.isEmpty {
                                    Text("No group chats found")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(Array(topGroupChats.enumerated()), id: \.offset) { index, groupChat in
                                            GroupChatRow(groupChat: groupChat, rank: index + 1)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(12)
                            
                            // Top Emojis Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Top 5 Emojis")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                let topEmojis = getTopEmojis()
                                if topEmojis.isEmpty {
                                    Text("No emojis found in your messages")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(Array(topEmojis.enumerated()), id: \.offset) { index, emoji in
                                            EmojiRow(emoji: emoji, rank: index + 1)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Conversations Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Conversations")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(getRecentConversations(), id: \.chatId) { conversation in
                                ConversationRow(conversation: conversation)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Messages Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Messages (Most Recent First)")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(getSortedMessages(), id: \.guid) { message in
                                MessageRow(message: message)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Add some bottom padding for better scrolling
                        Spacer(minLength: 20)
                    }
                }
            }
        }
        .onAppear {
            // Update the import service with the correct model context
            importService.updateModelContext(modelContext)
        }
    }
    
    private func getTopContact() -> (name: String, count: Int)? {
        // Group messages by chatId to get 1:1 conversations only
        let chatGroups = Dictionary(grouping: messages) { $0.chatId }
        
        // Filter to only 1:1 conversations (2 or fewer participants)
        let oneOnOneChats = chatGroups.filter { chatId, chatMessages in
            let uniqueSenders = Set(chatMessages.map { $0.sender })
            return uniqueSenders.count <= 2 && chatId != "unknown_chat"
        }
        
        // Count messages by sender across all 1:1 conversations
        var senderMessageCounts: [String: Int] = [:]
        
        for (_, chatMessages) in oneOnOneChats {
            for message in chatMessages {
                // Only count messages from others (not from the user)
                if !message.isFromMe && message.sender != "Unknown" {
                    senderMessageCounts[message.sender, default: 0] += 1
                }
            }
        }
        
        // Find the contact with the most messages
        let topContact = senderMessageCounts.max { $0.value < $1.value }
        
        if let contact = topContact {
            return (name: contact.key, count: contact.value)
        }
        return nil
    }
    
    private func getTopContacts(limit: Int = 20) -> Set<String> {
        // Group messages by sender and count them
        let groupedMessages = Dictionary(grouping: messages) { message in
            message.sender
        }
        
        // Filter out "Me" and "Unknown", then sort by message count
        let topContacts = groupedMessages
            .filter { $0.key != "Me" && $0.key != "Unknown" }
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { $0.key }
        
        return Set(topContacts)
    }
    
    private func getContactsInAddressBook() -> Set<String> {
        // Get all unique senders from messages
        let allSenders = Set(messages.map { $0.sender })
        
        // Filter to only include senders that are in the address book
        // (ContactResolver returns nil for people not in contacts, so we only want resolved names)
        let addressBookContacts = allSenders.filter { sender in
            sender != "Me" && sender != "Unknown" && !sender.contains("@") && !sender.contains("(")
        }
        
        return addressBookContacts
    }
    
    private func getTopContactsYouMessaged(limit: Int = 20) -> Set<String> {
        // Get all messages you sent
        let myMessages = messages.filter { $0.isFromMe }
        
        // Group by chatId to get conversations
        let chatGroups = Dictionary(grouping: myMessages) { $0.chatId }
        
        // Filter to only 1:1 conversations (2 or fewer participants)
        let oneOnOneChats = chatGroups.filter { chatId, chatMessages in
            let allMessagesInChat = messages.filter { $0.chatId == chatId }
            let uniqueSenders = Set(allMessagesInChat.map { $0.sender })
            return uniqueSenders.count <= 2 && chatId != "unknown_chat"
        }
        
        // Count messages by sender across all 1:1 conversations
        var senderMessageCounts: [String: Int] = [:]
        
        for (_, chatMessages) in oneOnOneChats {
            for message in chatMessages {
                // Find the other person in this conversation
                let allMessagesInChat = messages.filter { $0.chatId == message.chatId }
                let otherPerson = allMessagesInChat.first { !$0.isFromMe }?.sender
                
                if let otherPerson = otherPerson, otherPerson != "Unknown" {
                    senderMessageCounts[otherPerson, default: 0] += 1
                }
            }
        }
        
        // Get top 20 people you've messaged most
        let topContacts = senderMessageCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
        
        return Set(topContacts)
    }
    
    private func getResponseTimeData() -> [String: TimeInterval] {
        var responseTimes: [String: [TimeInterval]] = [:]
        
        // Get top 20 people you've sent messages to
        let topContacts = getTopContactsYouMessaged(limit: 20)
        
        // Group messages by chatId
        let conversationGroups = Dictionary(grouping: messages) { $0.chatId }
        
        for (chatId, conversationMessages) in conversationGroups {
            // Skip group chats (chats with 3+ participants)
            let uniqueSenders = Set(conversationMessages.map { $0.sender })
            if uniqueSenders.count >= 3 {
                continue // Skip this conversation
            }
            
            // Sort messages by date
            let sortedMessages = conversationMessages.sorted { $0.date < $1.date }
            
            for i in 0..<(sortedMessages.count - 1) {
                let currentMessage = sortedMessages[i]
                let nextMessage = sortedMessages[i + 1]
                
                // Check if current message is from me and next is from someone else
                if currentMessage.isFromMe && !nextMessage.isFromMe {
                    // Only calculate response times for top 20 contacts
                    guard topContacts.contains(nextMessage.sender) else { continue }
                    
                    let responseTime = nextMessage.date.timeIntervalSince(currentMessage.date)
                    
                    // Only consider reasonable response times (within 24 hours)
                    if responseTime > 0 && responseTime < 86400 { // 24 hours in seconds
                        if responseTimes[nextMessage.sender] == nil {
                            responseTimes[nextMessage.sender] = []
                        }
                        responseTimes[nextMessage.sender]?.append(responseTime)
                    }
                }
            }
        }
        
        // Calculate average response times
        var averageResponseTimes: [String: TimeInterval] = [:]
        for (sender, times) in responseTimes {
            if !times.isEmpty && sender != "Me" && sender != "Unknown" {
                averageResponseTimes[sender] = times.reduce(0, +) / Double(times.count)
            }
        }
        
        return averageResponseTimes
    }
    
    private func getResponseTimes() -> [String: TimeInterval] {
        return getResponseTimeData()
    }
    
    private func getFastestResponder() -> (name: String, time: String)? {
        let responseTimes = getResponseTimes()
        guard let fastest = responseTimes.min(by: { $0.value < $1.value }) else { return nil }
        return (name: fastest.key, time: formatResponseTime(fastest.value))
    }
    
    private func getSlowestResponder() -> (name: String, time: String)? {
        let responseTimes = getResponseTimes()
        guard let slowest = responseTimes.max(by: { $0.value < $1.value }) else { return nil }
        return (name: slowest.key, time: formatResponseTime(slowest.value))
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
    
    private func getRecentConversations() -> [Conversation] {
        // Group messages by sender to create conversations
        let groupedMessages = Dictionary(grouping: messages) { message in
            message.sender
        }
        
        // Create conversation objects and sort by most recent message
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
            .sorted { $0.lastMessageDate > $1.lastMessageDate } // Sort by most recent first
        
        return conversations
    }
    
    private func getSortedMessages() -> [Message] {
        // Return all messages sorted by timestamp, most recent first
        return messages.sorted { $0.date > $1.date }
    }
    
    private func getTopEmojis() -> [EmojiUsage] {
        // Get all messages from the user
        let myMessages = messages.filter { $0.isFromMe }
        
        // Extract emojis from all messages and track which messages contain each emoji
        var emojiCounts: [String: Int] = [:]
        var emojiMessages: [String: [String]] = [:]
        var messageToEmojis: [String: [String]] = [:]
        
        for message in myMessages {
            let emojis = extractEmojis(from: message.text)
            messageToEmojis[message.text] = emojis
            for emoji in emojis {
                emojiCounts[emoji, default: 0] += 1
                emojiMessages[emoji, default: []].append(message.text)
            }
        }
        
        // Sort by count and take top 5
        let topEmojis = emojiCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { EmojiUsage(emoji: $0.key, count: $0.value) }
        
        // Debug: Show only group chat analysis
        let chatGroups = Dictionary(grouping: messages) { $0.chatId }
        let groupChats = chatGroups.filter { chatId, chatMessages in
            let uniqueSenders = Set(chatMessages.map { $0.sender })
            return uniqueSenders.count >= 3
        }
        
        return Array(topEmojis)
    }
    
    private func extractEmojis(from text: String) -> [String] {
        // Skip system messages and reactions
        if text.hasPrefix("Reacted") || text.hasPrefix("Loved") || text.hasPrefix("Emphasized") {
            return []
        }
        
        var emojis: [String] = []
        var currentEmoji = ""
        
        for scalar in text.unicodeScalars {
            if scalar.properties.isEmoji {
                currentEmoji += String(scalar)
            } else {
                if !currentEmoji.isEmpty {
                    // Only add if it's not purely numeric
                    if !isNumeric(currentEmoji) {
                        // Split the emoji sequence into individual emojis
                        let individualEmojis = splitEmojiSequence(currentEmoji)
                        emojis.append(contentsOf: individualEmojis)
                    }
                    currentEmoji = ""
                }
            }
        }
        
        // Handle the last emoji
        if !currentEmoji.isEmpty && !isNumeric(currentEmoji) {
            let individualEmojis = splitEmojiSequence(currentEmoji)
            emojis.append(contentsOf: individualEmojis)
        }
        
        return emojis
    }
    
    private func splitEmojiSequence(_ emojiSequence: String) -> [String] {
        var individualEmojis: [String] = []
        
        // Use enumerateSubstrings to properly split emoji characters
        emojiSequence.enumerateSubstrings(in: emojiSequence.startIndex..<emojiSequence.endIndex,
                                         options: [.byComposedCharacterSequences, .localized]) { substring, _, _, _ in
            if let emoji = substring, !emoji.isEmpty {
                // Filter out non-emoji characters like ￼ (object replacement character)
                if emoji.unicodeScalars.contains(where: { $0.properties.isEmoji }) {
                    individualEmojis.append(emoji)
                }
            }
        }
        
        return individualEmojis
    }
    
    private func isNumeric(_ string: String) -> Bool {
        return !string.isEmpty && string.allSatisfy { $0.isNumber }
    }
    
    private func getTopGroupChats() -> [GroupChat] {
        // Group messages by chat ID - simple and straightforward
        let chatGroups = Dictionary(grouping: messages) { $0.chatId }
        
        var groupChats: [GroupChat] = []
        
        for (chatId, chatMessages) in chatGroups {
            // Skip unknown_chat as it's not a real group chat
            if chatId == "unknown_chat" {
                continue
            }
            
            // Count unique senders in this chat
            let uniqueSenders = Set(chatMessages.map { $0.sender })
            
            // Only consider it a group chat if there are 3+ total participants
            if uniqueSenders.count >= 3 {
                // Count messages by sender
                let messageCounts = Dictionary(grouping: chatMessages) { $0.sender }
                    .mapValues { $0.count }
                
                let totalMessages = chatMessages.count
                let myMessageCount = chatMessages.filter { $0.isFromMe }.count
                let myPercentage = totalMessages > 0 ? (Double(myMessageCount) / Double(totalMessages)) * 100 : 0
                
                // Find top messenger (excluding "Me")
                let topMessengerEntry = messageCounts
                    .filter { $0.key != "Me" && $0.key != "Unknown" }
                    .max { $0.value < $1.value }
                
                let topMessenger = topMessengerEntry?.key ?? "Unknown"
                let topMessengerCount = topMessengerEntry?.value ?? 0
                let topMessengerPercentage = totalMessages > 0 ? (Double(topMessengerCount) / Double(totalMessages)) * 100 : 0
                
                // Get all participants (excluding "Unknown")
                let participants = Array(uniqueSenders.filter { $0 != "Unknown" })
                
                // Get the chat display name and group ID from the first message in this chat
                let chatDisplayName = chatMessages.first?.chatDisplayName
                let chatGroupId = chatMessages.first?.chatGroupId
                
                // Create a group chat name - prefer display name if available
                let otherParticipants = participants.filter { $0 != "Me" }
                let groupChatName = if let displayName = chatDisplayName, !displayName.isEmpty {
                    displayName
                } else if otherParticipants.count <= 2 {
                    otherParticipants.joined(separator: ", ")
                } else {
                    "\(otherParticipants.prefix(2).joined(separator: ", ")) + \(otherParticipants.count - 2) more"
                }
                
                let groupChat = GroupChat(
                    name: groupChatName,
                    displayName: chatDisplayName,
                    groupId: chatGroupId,
                    totalMessages: totalMessages,
                    myMessageCount: myMessageCount,
                    myPercentage: myPercentage,
                    topMessenger: topMessenger,
                    topMessengerCount: topMessengerCount,
                    topMessengerPercentage: topMessengerPercentage,
                    participants: participants
                )
                
                groupChats.append(groupChat)
            }
        }
        
        // Sort by total message count and return top 10
        return Array(groupChats.sorted { $0.totalMessages > $1.totalMessages }.prefix(10))
    }
    
    private func clearCache() async {
        do {
            try modelContext.delete(model: Message.self)
            try modelContext.save()
            importService.importStatus = "Cache cleared successfully"
            print("[Cache] All messages cleared from database")
        } catch {
            importService.importStatus = "Failed to clear cache: \(error.localizedDescription)"
            print("[Cache] Error clearing messages: \(error)")
        }
    }
}

struct Conversation {
    let chatId: String
    let name: String
    let lastMessage: String
    let lastMessageDate: Date
    let messageCount: Int
}

    struct GroupChat {
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
    }
    
    struct EmojiUsage {
        let emoji: String
        let count: Int
    }

    struct GroupChatRow: View {
        let groupChat: GroupChat
        let rank: Int
        @StateObject private var imageService = ChatImageService()

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Rank badge
                    Text("\(rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    // Chat image or icon
                    Group {
                        if let image = imageService.getChatImage(for: groupChat.groupId) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: groupChat.displayName != nil ? "person.3.fill" : "person.2.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(groupChat.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text("\(groupChat.totalMessages) messages • \(groupChat.participants.count) participants")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            
            // Message distribution
            HStack(spacing: 16) {
                // Your percentage
                VStack(alignment: .leading, spacing: 2) {
                    Text("You")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    Text("\(String(format: "%.1f", groupChat.myPercentage))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Top messenger
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(groupChat.topMessenger)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .lineLimit(1)
                    Text("\(String(format: "%.1f", groupChat.topMessengerPercentage))%")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct EmojiRow: View {
    let emoji: EmojiUsage
    let rank: Int
    
    var body: some View {
        HStack {
            // Rank badge
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.purple)
                .clipShape(Circle())
            
            // Emoji
            Text(emoji.emoji)
                .font(.title2)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Used \(emoji.count) times")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // Simple histogram bar
                HStack(spacing: 2) {
                    ForEach(0..<min(emoji.count, 10), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: 4, height: 12)
                            .cornerRadius(2)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("\(conversation.messageCount) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(conversation.lastMessageDate, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(conversation.lastMessage)
                .font(.body)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }
}

struct MessageRow: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.sender)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(message.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.text)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                if message.isFromMe {
                    Text("Sent")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else {
                    Text("Received")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Message.self, Contact.self], inMemory: true)
}
