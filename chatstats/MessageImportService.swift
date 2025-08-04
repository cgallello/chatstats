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
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importStatus = "Requesting file access..."
        }
        
        // Request full disk access
        let granted = await requestFullDiskAccess()
        if !granted {
            await MainActor.run {
                importStatus = "Full disk access denied. Please:\n1. Open System Preferences > Security & Privacy > Privacy\n2. Select 'Full Disk Access' from the left sidebar\n3. Click the lock icon and enter your password\n4. Click '+' and add this app\n5. Make sure the checkbox is checked"
                isImporting = false
            }
            return
        }
        
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
        
        await MainActor.run {
            importStatus = "Importing messages..."
            importProgress = 0.1
        }
        
        // Import messages from the database on background thread
        let success = await Task.detached(priority: .userInitiated) {
            await self.importFromDatabase(path: dbPath)
        }.value
        
        await MainActor.run {
            if success {
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
        
        // Debug: Check chat table schema
        let schemaQuery = "PRAGMA table_info(chat)"
        var schemaStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, schemaQuery, -1, &schemaStatement, nil) == SQLITE_OK {
            print("[DEBUG] Chat table schema:")
            while sqlite3_step(schemaStatement) == SQLITE_ROW {
                let columnName = String(cString: sqlite3_column_text(schemaStatement, 1))
                let columnType = String(cString: sqlite3_column_text(schemaStatement, 2))
                print("[DEBUG] Column: \(columnName) (\(columnType))")
            }
            sqlite3_finalize(schemaStatement)
        }
        
        // Debug: Check some chat display names
        let chatQuery = "SELECT chat_identifier, display_name FROM chat WHERE display_name IS NOT NULL LIMIT 10"
        var chatStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, chatQuery, -1, &chatStatement, nil) == SQLITE_OK {
            print("[DEBUG] Sample chat display names:")
            while sqlite3_step(chatStatement) == SQLITE_ROW {
                let chatId = sqlite3_column_text(chatStatement, 0)
                let displayName = sqlite3_column_text(chatStatement, 1)
                if let chatId = chatId, let displayName = displayName {
                    print("[DEBUG] Chat: \(String(cString: chatId)) -> \(String(cString: displayName))")
                }
            }
            sqlite3_finalize(chatStatement)
        }
        
        guard let modelContext = modelContext else {
            return false
        }
        
        let query = """
            SELECT 
                m.guid,
                m.text,
                m.date,
                m.is_from_me,
                m.handle_id,
                c.chat_identifier,
                c.display_name,
                c.chat_identifier,
                c.group_id
            FROM message m
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE m.text IS NOT NULL AND m.text != ''
            ORDER BY m.date DESC
            LIMIT 50000
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // Clear existing messages
        do {
            try modelContext.delete(model: Message.self)
        } catch {
            return false
        }
        
        var messageCount = 0
        var skippedCount = 0
        let totalMessages = 50000 // Match the SQL LIMIT for accurate progress tracking
        
        while sqlite3_step(statement) == SQLITE_ROW {
            messageCount += 1
            
            // Update progress every 1000 messages for better performance
            if messageCount % 1000 == 0 {
                let progress = 0.1 + (Double(messageCount) / Double(totalMessages)) * 0.8
                await MainActor.run {
                    importProgress = progress
                    importStatus = "Importing messages... (\(messageCount)/\(totalMessages))"
                }
            }
            
            guard let guidCStr = sqlite3_column_text(statement, 0) else { 
                skippedCount += 1
                continue 
            }
            let guid = String(cString: guidCStr)
            guard let textCStr = sqlite3_column_text(statement, 1) else { 
                skippedCount += 1
                continue 
            }
            let text = String(cString: textCStr)
            let date = sqlite3_column_int64(statement, 2)
            let isFromMe = sqlite3_column_int(statement, 3) == 1
            let handleId = sqlite3_column_int(statement, 4)
            
            // Get chat information
            let chatIdentifier = sqlite3_column_text(statement, 5)
            let displayName = sqlite3_column_text(statement, 6)
            let groupId = sqlite3_column_text(statement, 8)
            
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
                chatId: chatId, // Use actual chat ID instead of sender
                chatDisplayName: chatDisplayName, // Store the chat display name
                chatGroupId: chatGroupId // Store the group ID for image lookup
            )
            
            modelContext.insert(message)
        }
        
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
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