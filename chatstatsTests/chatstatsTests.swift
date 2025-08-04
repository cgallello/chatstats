//
//  chatstatsTests.swift
//  chatstatsTests
//
//  Created by Christopher Gallello on 7/18/25.
//

import Testing
@testable import chatstats
import Foundation

struct chatstatsTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    // MARK: - Self Response Analytics Tests
    
    @Test func testSelfResponseCalculation() async throws {
        // Create test messages with known response times
        let messages = [
            // Alice messages me at 10:00 AM
            Message(guid: "1", text: "Hey there!", date: Date(timeIntervalSince1970: 1000), sender: "Alice", isFromMe: false, chatId: "chat1", chatDisplayName: nil, chatGroupId: nil),
            // I respond at 10:05 AM (5 minute response)
            Message(guid: "2", text: "Hi Alice!", date: Date(timeIntervalSince1970: 1300), sender: "Me", isFromMe: true, chatId: "chat1", chatDisplayName: nil, chatGroupId: nil),
            
            // Alice messages me again at 11:00 AM
            Message(guid: "3", text: "How are you?", date: Date(timeIntervalSince1970: 4600), sender: "Alice", isFromMe: false, chatId: "chat1", chatDisplayName: nil, chatGroupId: nil),
            // I respond at 11:10 AM (10 minute response)
            Message(guid: "4", text: "I'm good!", date: Date(timeIntervalSince1970: 5200), sender: "Me", isFromMe: true, chatId: "chat1", chatDisplayName: nil, chatGroupId: nil)
        ]
        
        let responseStats = SelfResponseAnalytics.calculateSelfResponseTimes(for: messages)
        
        // Should have response data for Alice
        #expect(responseStats["Alice"] != nil)
        
        if let aliceStats = responseStats["Alice"] {
            // Average should be 7.5 minutes (450 seconds)
            #expect(abs(aliceStats.averageSeconds - 450.0) < 1.0)
            // Should have 2 responses
            #expect(aliceStats.totalResponses == 2)
            // Fastest should be 5 minutes (300 seconds)
            #expect(abs(aliceStats.fastestResponse - 300.0) < 1.0)
            // Slowest should be 10 minutes (600 seconds)
            #expect(abs(aliceStats.slowestResponse - 600.0) < 1.0)
        }
    }
    
    @Test func testBidirectionalResponseTimes() async throws {
        let messages = [
            // I message Bob at 9:00 AM
            Message(guid: "1", text: "Morning Bob!", date: Date(timeIntervalSince1970: 1000), sender: "Me", isFromMe: true, chatId: "chat2", chatDisplayName: nil, chatGroupId: nil),
            // Bob responds at 9:02 AM (2 minute response)
            Message(guid: "2", text: "Morning!", date: Date(timeIntervalSince1970: 1120), sender: "Bob", isFromMe: false, chatId: "chat2", chatDisplayName: nil, chatGroupId: nil),
            
            // Bob messages me at 10:00 AM
            Message(guid: "3", text: "What's up?", date: Date(timeIntervalSince1970: 4600), sender: "Bob", isFromMe: false, chatId: "chat2", chatDisplayName: nil, chatGroupId: nil),
            // I respond at 10:15 AM (15 minute response)
            Message(guid: "4", text: "Not much", date: Date(timeIntervalSince1970: 5500), sender: "Me", isFromMe: true, chatId: "chat2", chatDisplayName: nil, chatGroupId: nil)
        ]
        
        let bidirectionalStats = SelfResponseAnalytics.calculateBidirectionalResponseTimes(for: messages)
        
        // Should have bidirectional data for Bob
        #expect(bidirectionalStats.count == 1)
        #expect(bidirectionalStats[0].contactName == "Bob")
        
        let bobStats = bidirectionalStats[0]
        
        // Should have both directions of response times
        #expect(bobStats.theirResponseToYou != nil)
        #expect(bobStats.yourResponseToThem != nil)
        
        if let theirResponse = bobStats.theirResponseToYou {
            // Bob's response time should be 2 minutes (120 seconds)
            #expect(abs(theirResponse.averageSeconds - 120.0) < 1.0)
        }
        
        if let yourResponse = bobStats.yourResponseToThem {
            // My response time should be 15 minutes (900 seconds)
            #expect(abs(yourResponse.averageSeconds - 900.0) < 1.0)
        }
        
        // Response ratio should show I'm slower (900/120 = 7.5)
        if let ratio = bobStats.responseRatio {
            #expect(abs(ratio - 7.5) < 0.1)
        }
        
        // Should indicate they're faster
        #expect(bobStats.whoIsFaster == "They're faster")
    }
    
    @Test func testNoResponseData() async throws {
        // Test with messages that don't form response pairs
        let messages = [
            Message(guid: "1", text: "Hello", date: Date(timeIntervalSince1970: 1000), sender: "Me", isFromMe: true, chatId: "chat3", chatDisplayName: nil, chatGroupId: nil),
            Message(guid: "2", text: "Hi there", date: Date(timeIntervalSince1970: 2000), sender: "Me", isFromMe: true, chatId: "chat3", chatDisplayName: nil, chatGroupId: nil)
        ]
        
        let responseStats = SelfResponseAnalytics.calculateSelfResponseTimes(for: messages)
        #expect(responseStats.isEmpty)
        
        let bidirectionalStats = SelfResponseAnalytics.calculateBidirectionalResponseTimes(for: messages)
        #expect(bidirectionalStats.isEmpty)
    }
    
    @Test func testGroupChatFiltering() async throws {
        // Test that group chats (3+ participants) are excluded
        let messages = [
            Message(guid: "1", text: "Hey everyone", date: Date(timeIntervalSince1970: 1000), sender: "Alice", isFromMe: false, chatId: "groupchat1", chatDisplayName: nil, chatGroupId: nil),
            Message(guid: "2", text: "Hello", date: Date(timeIntervalSince1970: 1300), sender: "Bob", isFromMe: false, chatId: "groupchat1", chatDisplayName: nil, chatGroupId: nil),
            Message(guid: "3", text: "Hi all", date: Date(timeIntervalSince1970: 1600), sender: "Me", isFromMe: true, chatId: "groupchat1", chatDisplayName: nil, chatGroupId: nil)
        ]
        
        let responseStats = SelfResponseAnalytics.calculateSelfResponseTimes(for: messages)
        #expect(responseStats.isEmpty)
        
        let bidirectionalStats = SelfResponseAnalytics.calculateBidirectionalResponseTimes(for: messages)
        #expect(bidirectionalStats.isEmpty)
    }
    
    @Test func testLongResponseTimeFiltering() async throws {
        // Test that very long response times (>72 hours) are excluded
        let messages = [
            Message(guid: "1", text: "Hey", date: Date(timeIntervalSince1970: 1000), sender: "Charlie", isFromMe: false, chatId: "chat4", chatDisplayName: nil, chatGroupId: nil),
            // Respond after 80 hours (should be excluded)
            Message(guid: "2", text: "Hi", date: Date(timeIntervalSince1970: 1000 + (80 * 3600)), sender: "Me", isFromMe: true, chatId: "chat4", chatDisplayName: nil, chatGroupId: nil)
        ]
        
        let responseStats = SelfResponseAnalytics.calculateSelfResponseTimes(for: messages)
        #expect(responseStats.isEmpty)
    }
    
    @Test func testResponseTimeFormatting() async throws {
        // Test various response time formatting scenarios
        #expect(SelfResponseAnalytics.formatResponseTime(30) == "30s")
        #expect(SelfResponseAnalytics.formatResponseTime(90) == "1m 30s")
        #expect(SelfResponseAnalytics.formatResponseTime(3660) == "1h 1m")
        #expect(SelfResponseAnalytics.formatResponseTime(7325) == "2h 2m")
    }
    
    @Test func testResponseSpeedCategories() async throws {
        // Test response speed categorization
        let lightning = SelfResponseAnalytics.getResponseSpeedCategory(30) // 30 seconds
        #expect(lightning.category == "Lightning ⚡")
        #expect(lightning.color == "green")
        
        let veryFast = SelfResponseAnalytics.getResponseSpeedCategory(120) // 2 minutes
        #expect(veryFast.category == "Very Fast 🚀")
        #expect(veryFast.color == "green")
        
        let fast = SelfResponseAnalytics.getResponseSpeedCategory(600) // 10 minutes
        #expect(fast.category == "Fast 🏃")
        #expect(fast.color == "blue")
        
        let moderate = SelfResponseAnalytics.getResponseSpeedCategory(1800) // 30 minutes
        #expect(moderate.category == "Moderate 🚶")
        #expect(moderate.color == "orange")
        
        let slow = SelfResponseAnalytics.getResponseSpeedCategory(7200) // 2 hours
        #expect(slow.category == "Slow 🐌")
        #expect(slow.color == "red")
        
        let verySlow = SelfResponseAnalytics.getResponseSpeedCategory(18000) // 5 hours
        #expect(verySlow.category == "Very Slow 🐢")
        #expect(verySlow.color == "red")
    }
    

}
