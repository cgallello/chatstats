//
//  Message.swift
//  chatstats
//
//  Created by Christopher Gallello on 7/18/25.
//

import Foundation
import SwiftData

@Model
final class Message {
    var guid: String
    var text: String
    var date: Date
    var sender: String
    var isFromMe: Bool
    var chatId: String
    var chatDisplayName: String?
    var chatGroupId: String?
    
    init(guid: String, text: String, date: Date, sender: String, isFromMe: Bool, chatId: String, chatDisplayName: String? = nil, chatGroupId: String? = nil) {
        self.guid = guid
        self.text = text
        self.date = date
        self.sender = sender
        self.isFromMe = isFromMe
        self.chatId = chatId
        self.chatDisplayName = chatDisplayName
        self.chatGroupId = chatGroupId
    }
} 