//
//  EmojiAnalyzer.swift
//  chatstats
//
//  Created by Claude on 8/3/25.
//

import Foundation

class EmojiAnalyzer {
    
    func computeEmojiUsage(for messages: [Message]) -> [EmojiUsage] {
        let myMessages = messages.filter { $0.isFromMe }
        
        var emojiCounts: [String: Int] = [:]
        var totalEmojis = 0
        
        for message in myMessages {
            let emojis = extractEmojis(from: message.text)
            for emoji in emojis {
                emojiCounts[emoji, default: 0] += 1
                totalEmojis += 1
            }
        }
        
        let topEmojis = emojiCounts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { emoji, count in
                let percentage = totalEmojis > 0 ? (Double(count) / Double(totalEmojis)) * 100 : 0
                return EmojiUsage(emoji: emoji, count: count, percentage: percentage)
            }
        
        return Array(topEmojis)
    }
    
    func getTopEmojis(for messages: [Message], limit: Int = 5) -> [EmojiUsage] {
        let allUsage = computeEmojiUsage(for: messages)
        return Array(allUsage.prefix(limit))
    }
    
    func getEmojiDiversity(for messages: [Message]) -> (uniqueEmojis: Int, totalEmojis: Int, diversityScore: Double) {
        let myMessages = messages.filter { $0.isFromMe }
        
        var uniqueEmojis: Set<String> = []
        var totalEmojis = 0
        
        for message in myMessages {
            let emojis = extractEmojis(from: message.text)
            for emoji in emojis {
                uniqueEmojis.insert(emoji)
                totalEmojis += 1
            }
        }
        
        let diversityScore = totalEmojis > 0 ? Double(uniqueEmojis.count) / Double(totalEmojis) : 0
        return (uniqueEmojis: uniqueEmojis.count, totalEmojis: totalEmojis, diversityScore: diversityScore)
    }
    
    private func extractEmojis(from text: String) -> [String] {
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
                    if !isNumeric(currentEmoji) {
                        let individualEmojis = splitEmojiSequence(currentEmoji)
                        emojis.append(contentsOf: individualEmojis)
                    }
                    currentEmoji = ""
                }
            }
        }
        
        if !currentEmoji.isEmpty && !isNumeric(currentEmoji) {
            let individualEmojis = splitEmojiSequence(currentEmoji)
            emojis.append(contentsOf: individualEmojis)
        }
        
        return emojis
    }
    
    private func splitEmojiSequence(_ emojiSequence: String) -> [String] {
        var individualEmojis: [String] = []
        
        emojiSequence.enumerateSubstrings(in: emojiSequence.startIndex..<emojiSequence.endIndex,
                                         options: [.byComposedCharacterSequences, .localized]) { substring, _, _, _ in
            if let emoji = substring, !emoji.isEmpty {
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
}