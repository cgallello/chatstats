//
//  MessagesChartView.swift
//  chatstats
//
//  Created by Christopher Gallello on 7/18/25.
//

import SwiftUI
import Charts
import SwiftData

struct DailyMessageData: Identifiable {
    let id = UUID()
    let date: Date
    let sent: Int
    let received: Int
}

struct MessagesChartView: View {
    let messages: [Message]
    
    private var dailyData: [DailyMessageData] {
        // Create a calendar for date operations
        let calendar = Calendar.current
        
        // Group messages by day
        let groupedByDay = Dictionary(grouping: messages) { message in
            calendar.startOfDay(for: message.date)
        }
        
        // Convert to daily aggregated data
        var dailyData: [DailyMessageData] = []
        
        for (date, dayMessages) in groupedByDay {
            let sentCount = dayMessages.filter { $0.isFromMe }.count
            let receivedCount = dayMessages.filter { !$0.isFromMe }.count
            
            dailyData.append(DailyMessageData(
                date: date,
                sent: sentCount,
                received: receivedCount
            ))
        }
        
        // Sort by date
        return dailyData.sorted { $0.date < $1.date }
    }
    

    

    

    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Messages Over Time")
                .font(.headline)
                .fontWeight(.medium)
            
            if dailyData.isEmpty {
                let noDataText = Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                noDataText
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            } else {
                Chart {
                    ForEach(dailyData) { dayData in
                        // Sent messages points only
                        PointMark(
                            x: .value("Date", dayData.date),
                            y: .value("Messages", dayData.sent)
                        )
                        .foregroundStyle(.blue)
                        .symbol(Circle())
                        .symbolSize(50)
                    }
                    
                    ForEach(dailyData) { dayData in
                        // Received messages points only
                        PointMark(
                            x: .value("Date", dayData.date),
                            y: .value("Messages", dayData.received)
                        )
                        .foregroundStyle(.green)
                        .symbol(Triangle())
                        .symbolSize(50)
                    }
                }
                .chartXScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 8)) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .top, alignment: .leading) {
                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 10, height: 10)
                            Text("Sent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Triangle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                            Text("Received")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .chartYAxisLabel("Messages")
                .chartXAxisLabel("Date")
                .frame(height: 200)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
}

// Custom triangle symbol for the chart
struct Triangle: ChartSymbolShape {
    var perceptualUnitRect: CGRect {
        CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    
    func symbolSize(at value: Any, in environment: EnvironmentValues) -> CGSize {
        CGSize(width: 8, height: 8)
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    let sampleMessages = [
        Message(guid: "1", text: "Hello", date: Date().addingTimeInterval(-86400 * 5), sender: "Alice", isFromMe: false, chatId: "chat1"),
        Message(guid: "2", text: "Hi there", date: Date().addingTimeInterval(-86400 * 5), sender: "Me", isFromMe: true, chatId: "chat1"),
        Message(guid: "3", text: "How are you?", date: Date().addingTimeInterval(-86400 * 3), sender: "Bob", isFromMe: false, chatId: "chat2"),
        Message(guid: "4", text: "I'm good!", date: Date().addingTimeInterval(-86400 * 3), sender: "Me", isFromMe: true, chatId: "chat2"),
        Message(guid: "5", text: "Great!", date: Date().addingTimeInterval(-86400 * 1), sender: "Alice", isFromMe: false, chatId: "chat1"),
    ]
    
    MessagesChartView(messages: sampleMessages)
        .padding()
} 