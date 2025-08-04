//
//  MessageImportService.swift
//  chatstats
//
//  Created by Christopher Gallello on 7/18/25.
//

import Foundation
import SwiftData
import SQLite3
import Contacts

@MainActor
class MessageImportService: ObservableObject {
    @Published var isImporting = false
    @Published var importProgress: Double = 0.0
    @Published var importStatus = ""
    @Published var totalMessagesFound: Int = 0
    @Published var messagesProcessed: Int = 0
    
    private var importTask: Task<Void, Never>?
    private var isCancelled = false
    
    private var modelContext: ModelContext?
    private let contactResolver = ContactResolver()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func updateModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    
    private func formatIdentifierNicely(_ identifier: String) -> String {
        if identifier.contains("@") {
            // It's an email, extract the name part
            let emailParts = identifier.split(separator: "@")
            let namePart = String(emailParts[0])
            // Replace dots and underscores with spaces and capitalize
            let formattedName = namePart.replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return formattedName
        } else if identifier.hasPrefix("+1") && identifier.count == 12 {
            // It's a US phone number, format it nicely
            let phone = String(identifier.dropFirst(2))
            return "(\(phone.prefix(3))) \(phone.dropFirst(3).prefix(3))-\(phone.dropFirst(6))"
        } else if identifier.hasPrefix("+") {
            // International number, format it nicely
            let countryCode = String(identifier.prefix(3))
            let number = String(identifier.dropFirst(3))
            if number.count >= 10 {
                let areaCode = String(number.prefix(3))
                let prefix = String(number.dropFirst(3).prefix(3))
                let line = String(number.dropFirst(6).prefix(4))
                return "+\(countryCode) (\(areaCode)) \(prefix)-\(line)"
            } else {
                return identifier
            }
        } else {
            return identifier
        }
    }
    
    func importMessages() async {
        // Cancel any existing import task
        cancelImport()
        
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importStatus = "Requesting file access..."
            isCancelled = false
        }
        
        // Create new import task
        importTask = Task {
            await performImport()
        }
        
        await importTask?.value
    }
    
    func cancelImport() {
        isCancelled = true
        importTask?.cancel()
        importTask = nil
    }
    
    private func performImport() async {
        // Request full disk access
        let granted = await requestFullDiskAccess()
        if !granted {
            await MainActor.run {
                importStatus = "Full disk access denied. Please:\n1. Open System Preferences > Security & Privacy > Privacy\n2. Select 'Full Disk Access' from the left sidebar\n3. Click the lock icon and enter your password\n4. Click '+' and add this app\n5. Make sure the checkbox is checked"
                isImporting = false
            }
            return
        }
        
        if isCancelled { return }
        
        await MainActor.run {
            importStatus = "Locating iMessage database..."
        }
        
        // Find the iMessage database
        guard let dbPath = findIMessageDatabase() else {
            await MainActor.run {
                importStatus = "Could not locate iMessage database. Please ensure you have granted Full Disk Access to this app in System Preferences > Security & Privacy > Privacy > Full Disk Access"
                isImporting = false
            }
            return
        }
        
        if isCancelled { return }
        
        await MainActor.run {
            importStatus = "Preparing to import messages..."
            importProgress = 0.05
        }
        
        // Import messages from the database on background thread
        let success = await Task.detached(priority: .userInitiated) {
            await self.importFromDatabase(path: dbPath)
        }.value
        
        await MainActor.run {
            if isCancelled {
                importStatus = "Import cancelled by user."
            } else if success {
                importStatus = "Import completed successfully!"
                importProgress = 1.0
            } else {
                importStatus = "Import failed. Please try again."
            }
            isImporting = false
        }
    }
    
    private func requestFullDiskAccess() async -> Bool {
        // For full disk access, the user needs to manually grant it in System Preferences
        // This function checks if we can access the Messages directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        
        // Check multiple possible Messages directory locations
        let possibleMessagesDirs: [URL] = [
            homeDirectory.appendingPathComponent("Library/Messages"),
            homeDirectory.appendingPathComponent("Library/Containers/com.apple.iChat/Data/Library/Messages"),
            homeDirectory.appendingPathComponent("Library/Application Support/Messages")
        ]
        
        for messagesPath in possibleMessagesDirs {
            // Try to access the directory to potentially trigger permission request
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: messagesPath.path)
                return true
            } catch {
                // Silently continue to next path
            }
        }
        
        return false
    }
    
    private func findIMessageDatabase() -> String? {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        
        // Check multiple possible locations for the iMessage database
        let possiblePaths: [URL] = [
            homeDirectory.appendingPathComponent("Library/Messages/chat.db"),
            homeDirectory.appendingPathComponent("Library/Containers/com.apple.iChat/Data/Library/Messages/chat.db"),
            homeDirectory.appendingPathComponent("Library/Application Support/Messages/chat.db"),
            URL(fileURLWithPath: "/var/db/Messages/chat.db"),
            URL(fileURLWithPath: "/private/var/db/Messages/chat.db")
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path.path
            }
        }
        
        return nil
    }
    
    private func importFromDatabase(path: String) async -> Bool {
        return await importMessagesFromDatabase(path: path)
    }
    
    private func importMessagesFromDatabase(path: String) async -> Bool {
        var db: OpaquePointer?
        
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            return false
        }
        
        guard let db = db else {
            return false
        }
        
        defer {
            sqlite3_close(db)
        }
        
        guard let modelContext = modelContext else {
            return false
        }
        
        // Clear existing messages first
        do {
            try modelContext.delete(model: Message.self)
            try modelContext.save()
        } catch {
            return false
        }
        
        // First, get total count for progress tracking
        let totalCount = await getTotalMessageCount(db: db)
        await MainActor.run {
            totalMessagesFound = totalCount
            messagesProcessed = 0
            importStatus = "Found \(totalCount) messages to import..."
        }
        
        // Import messages in batches using streaming approach
        return await importMessagesStreaming(db: db, batchSize: 1000)
    }
    
    private func getTotalMessageCount(db: OpaquePointer) async -> Int {
        let countQuery = """
            SELECT COUNT(*)
            FROM message m
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE m.text IS NOT NULL AND m.text != ''
        """
        
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, countQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        }
        
        return count
    }
    
    private func importMessagesStreaming(db: OpaquePointer, batchSize: Int = 1000) async -> Bool {
        guard let modelContext = modelContext else {
            return false
        }
        
        var offset = 0
        var totalProcessed = 0
        
        while !isCancelled {
            // Load batch of messages
            let batch = await loadMessageBatch(db: db, offset: offset, limit: batchSize)
            
            if batch.isEmpty {
                break // No more messages
            }
            
            // Process batch in memory-efficient way
            for message in batch {
                if isCancelled {
                    return false
                }
                
                modelContext.insert(message)
                totalProcessed += 1
                
                // Update progress every 100 messages for better performance
                if totalProcessed % 100 == 0 {
                    await MainActor.run {
                        messagesProcessed = totalProcessed
                        importProgress = Double(totalProcessed) / Double(totalMessagesFound)
                        importStatus = "Importing messages... (\(totalProcessed)/\(totalMessagesFound))"
                    }
                }
            }
            
            // Save batch to reduce memory usage
            do {
                try modelContext.save()
            } catch {
                print("Error saving batch: \(error)")
                return false
            }
            
            offset += batchSize
            
            // Yield control to prevent blocking the main thread
            await Task.yield()
        }
        
        // Final save and progress update
        do {
            try modelContext.save()
            await MainActor.run {
                messagesProcessed = totalProcessed
                importProgress = 1.0
                importStatus = "Successfully imported \(totalProcessed) messages!"
            }
            return true
        } catch {
            return false
        }
    }
    
    private func loadMessageBatch(db: OpaquePointer, offset: Int, limit: Int) async -> [Message] {
        let query = """
            SELECT 
                m.guid,
                m.text,
                m.date,
                m.is_from_me,
                m.handle_id,
                c.chat_identifier,
                c.display_name,
                c.group_id
            FROM message m
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE m.text IS NOT NULL AND m.text != ''
            ORDER BY m.date DESC
            LIMIT \(limit) OFFSET \(offset)
        """
        
        var statement: OpaquePointer?
        var messages: [Message] = []
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return messages
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if isCancelled {
                break
            }
            
            guard let guidCStr = sqlite3_column_text(statement, 0),
                  let textCStr = sqlite3_column_text(statement, 1) else {
                continue
            }
            
            let guid = String(cString: guidCStr)
            let text = String(cString: textCStr)
            let date = sqlite3_column_int64(statement, 2)
            let isFromMe = sqlite3_column_int(statement, 3) == 1
            let handleId = sqlite3_column_int(statement, 4)
            
            // Get chat information
            let chatIdentifier = sqlite3_column_text(statement, 5)
            let displayName = sqlite3_column_text(statement, 6)
            let groupId = sqlite3_column_text(statement, 7)
            
            let chatId = chatIdentifier != nil ? String(cString: chatIdentifier!) : "unknown_chat"
            let chatDisplayName = displayName != nil ? String(cString: displayName!) : nil
            let chatGroupId = groupId != nil ? String(cString: groupId!) : nil
            
            // Get sender information using ContactResolver
            let sender = await getSenderInfo(db: db, handleId: handleId, isFromMe: isFromMe)
            
            let message = Message(
                guid: guid,
                text: text,
                date: Date(timeIntervalSinceReferenceDate: TimeInterval(date / 1_000_000_000)),
                sender: sender,
                isFromMe: isFromMe,
                chatId: chatId,
                chatDisplayName: chatDisplayName,
                chatGroupId: chatGroupId
            )
            
            messages.append(message)
        }
        
        return messages
    }
    
    private func getSenderInfo(db: OpaquePointer, handleId: Int32, isFromMe: Bool) async -> String {
        // Handle special case where handleId is 0 (often your own messages or system messages)
        if handleId == 0 {
            return isFromMe ? "Me" : "Unknown"
        }
        
        // Query the handle table to get the phone number/email
        let handleQuery = "SELECT id FROM handle WHERE ROWID = ?"
        var handleStatement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, handleQuery, -1, &handleStatement, nil) == SQLITE_OK else {
            return "Unknown"
        }
        
        defer {
            sqlite3_finalize(handleStatement)
        }
        
        sqlite3_bind_int(handleStatement, 1, handleId)
        
        if sqlite3_step(handleStatement) == SQLITE_ROW {
            if let idText = sqlite3_column_text(handleStatement, 0) {
                let id = String(cString: idText)
                // Try to resolve contact name using ContactResolver
                if let resolvedName = contactResolver.name(for: id) {
                    return resolvedName
                }
                // If no contact found, format the phone number/email nicely
                return formatIdentifierNicely(id)
            }
        }
        
        return "Unknown"
    }
} 