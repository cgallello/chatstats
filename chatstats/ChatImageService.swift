import Foundation
import SwiftUI
import SQLite3

class ChatImageService: ObservableObject {
    private var imageCache: [String: NSImage] = [:]
    
    func getChatImage(for groupId: String?) -> NSImage? {
        guard let groupId = groupId, !groupId.isEmpty else {
            return nil
        }
        
        // Check cache first
        if let cachedImage = imageCache[groupId] {
            return cachedImage
        }
        
        // Try to load from iMessage database
        if let image = loadChatImageFromDatabase(groupId: groupId) {
            imageCache[groupId] = image
            return image
        }
        
        return nil
    }
    
    private func loadChatImageFromDatabase(groupId: String) -> NSImage? {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let dbPath = homeDirectory.appendingPathComponent("Library/Messages/chat.db")
        
        guard FileManager.default.fileExists(atPath: dbPath.path) else {
            return nil
        }
        
        var db: OpaquePointer?
        guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else {
            return nil
        }
        
        defer {
            sqlite3_close(db)
        }
        
        // Try to get chat image from attachment table
        let query = """
            SELECT a.filename, a.mime_type
            FROM attachment a
            JOIN message_attachment_join maj ON a.ROWID = maj.attachment_id
            JOIN message m ON maj.message_id = m.ROWID
            JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE c.group_id = ? AND a.mime_type LIKE 'image/%'
            ORDER BY m.date DESC
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // Bind the group ID parameter
        sqlite3_bind_text(statement, 1, (groupId as NSString).utf8String, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let filename = sqlite3_column_text(statement, 0)
            if let filename = filename {
                let imagePath = String(cString: filename)
                if let image = NSImage(contentsOfFile: imagePath) {
                    return image
                }
            }
        }
        
        return nil
    }
    
    func clearCache() {
        imageCache.removeAll()
    }
} 