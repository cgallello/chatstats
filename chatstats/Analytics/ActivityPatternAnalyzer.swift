//
//  ActivityPatternAnalyzer.swift
//  chatstats
//
//  Created by Claude on 8/3/25.
//

import Foundation

class ActivityPatternAnalyzer {
    
    func computeActivityPatterns(for messages: [Message]) -> ActivityPatterns {
        let myMessages = messages.filter { $0.isFromMe }
        
        let hourlyDistribution = computeHourlyDistribution(from: myMessages)
        let dayOfWeekStats = computeDayOfWeekStats(from: myMessages)
        let nightOwlScore = computeNightOwlScore(from: hourlyDistribution)
        let earlyBirdScore = computeEarlyBirdScore(from: hourlyDistribution)
        let mostActiveHour = findMostActiveHour(from: hourlyDistribution)
        
        return ActivityPatterns(
            nightOwlScore: nightOwlScore,
            earlyBirdScore: earlyBirdScore,
            mostActiveHour: mostActiveHour,
            dayOfWeekStats: dayOfWeekStats,
            hourlyDistribution: hourlyDistribution
        )
    }
    
    func getDayOfWeekHotspots(for messages: [Message]) -> [(day: String, count: Int, percentage: Double)] {
        let myMessages = messages.filter { $0.isFromMe }
        let dayStats = computeDayOfWeekStats(from: myMessages)
        let totalMessages = myMessages.count
        
        return dayStats
            .sorted { $0.value > $1.value }
            .map { day, count in
                let percentage = totalMessages > 0 ? (Double(count) / Double(totalMessages)) * 100 : 0
                return (day: day, count: count, percentage: percentage)
            }
    }
    
    func getActivityScore(for messages: [Message], during timeRange: HourRange) -> Double {
        let myMessages = messages.filter { $0.isFromMe }
        let hourlyDistribution = computeHourlyDistribution(from: myMessages)
        let totalMessages = myMessages.count
        
        var rangeMessages = 0
        for hour in timeRange.startHour...timeRange.endHour {
            rangeMessages += hourlyDistribution[hour] ?? 0
        }
        
        return totalMessages > 0 ? (Double(rangeMessages) / Double(totalMessages)) * 100 : 0
    }
    
    private func computeHourlyDistribution(from messages: [Message]) -> [Int: Int] {
        var distribution: [Int: Int] = [:]
        
        for message in messages {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: message.date)
            distribution[hour, default: 0] += 1
        }
        
        return distribution
    }
    
    private func computeDayOfWeekStats(from messages: [Message]) -> [String: Int] {
        var dayStats: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        
        for message in messages {
            let dayName = dateFormatter.string(from: message.date)
            dayStats[dayName, default: 0] += 1
        }
        
        return dayStats
    }
    
    private func computeNightOwlScore(from hourlyDistribution: [Int: Int]) -> Double {
        let nightHours = [22, 23, 0, 1, 2, 3]
        let nightMessages = nightHours.compactMap { hourlyDistribution[$0] }.reduce(0, +)
        let totalMessages = hourlyDistribution.values.reduce(0, +)
        
        return totalMessages > 0 ? (Double(nightMessages) / Double(totalMessages)) * 100 : 0
    }
    
    private func computeEarlyBirdScore(from hourlyDistribution: [Int: Int]) -> Double {
        let earlyHours = [5, 6, 7, 8]
        let earlyMessages = earlyHours.compactMap { hourlyDistribution[$0] }.reduce(0, +)
        let totalMessages = hourlyDistribution.values.reduce(0, +)
        
        return totalMessages > 0 ? (Double(earlyMessages) / Double(totalMessages)) * 100 : 0
    }
    
    private func findMostActiveHour(from hourlyDistribution: [Int: Int]) -> Int {
        return hourlyDistribution.max(by: { $0.value < $1.value })?.key ?? 12
    }
}

struct HourRange {
    let startHour: Int
    let endHour: Int
    
    static let morning = HourRange(startHour: 6, endHour: 11)
    static let afternoon = HourRange(startHour: 12, endHour: 17)
    static let evening = HourRange(startHour: 18, endHour: 21)
    static let night = HourRange(startHour: 22, endHour: 5)
}