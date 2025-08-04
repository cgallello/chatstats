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
    @StateObject private var analyticsManager = AnalyticsManager()
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
                            if let topContact = analyticsManager.getTopContact(for: messages) {
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
                                if let fastestResponder = analyticsManager.getFastestResponder(for: messages) {
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
                                if let slowestResponder = analyticsManager.getSlowestResponder(for: messages) {
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
                                
                                let topGroupChats = analyticsManager.getTopGroupChats(for: messages)
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
                                        ForEach(Array(topGroupChats.enumerated()), id: \.offset) { index, groupChatStats in
                                            GroupChatStatsRow(groupChatStats: groupChatStats, rank: index + 1)
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
                                
                                let topEmojis = analyticsManager.getTopEmojis(for: messages)
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
                            
                            ForEach(analyticsManager.getRecentConversations(from: messages), id: \.chatId) { conversation in
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
    
    
    private func getSortedMessages() -> [Message] {
        return messages.sorted { $0.date > $1.date }
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


struct GroupChatStatsRow: View {
        let groupChatStats: GroupChatStats
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
                        if let image = imageService.getChatImage(for: groupChatStats.groupId) {
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
                                
                                Image(systemName: groupChatStats.displayName != nil ? "person.3.fill" : "person.2.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(groupChatStats.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text("\(groupChatStats.totalMessages) messages • \(groupChatStats.participants.count) participants")
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
                    Text("\(String(format: "%.1f", groupChatStats.myPercentage))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Top messenger
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(groupChatStats.topMessenger)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .lineLimit(1)
                    Text("\(String(format: "%.1f", groupChatStats.topMessengerPercentage))%")
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
