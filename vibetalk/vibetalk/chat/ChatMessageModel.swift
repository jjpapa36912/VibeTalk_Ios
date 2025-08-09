//
//  ChatMessageModel.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//

import Foundation
import SwiftUI

//struct ChatMessageModel: Identifiable, Codable {
//    let id: UUID = UUID()
//    let senderId: Int
//    let senderName: String
//    let message: String
//}
struct ChatMessageResponse: Codable, Identifiable {
    let id: Int
    let senderId: Int
    let senderName: String
    let content: String
    let sentAt: String
    let emotion: String?     // ✅ 추가
    let fontName: String?    // ✅ 추가
    let emoji: String?       // ✅ 추가
}



struct ChatBubbleView: View {
    let message: ChatMessageModel
    let isCurrentUser: Bool

    var body: some View {
        let key = message.emotion ?? "neutral"
        let style = emotionStyles[key] ?? emotionStyles["neutral"]!

        HStack {
            if isCurrentUser { Spacer() }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text("\(message.emoji ?? "") \(message.content)")
                    .font(Font.custom(message.fontName ?? style.fontName, size: 17))
                    .foregroundColor(isCurrentUser ? .white : .white) // 필요 시 style.textColor
                    .padding()
                    .background(
                        (isCurrentUser ? Color.blue.opacity(0.85)
                                       : style.color ?? Color.gray.opacity(0.4))
                    )
                    .cornerRadius(15)
                    .frame(maxWidth: 250, alignment: isCurrentUser ? .trailing : .leading)

                Text(formatTime(message.sentAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if !isCurrentUser { Spacer() }
        }
        .padding(isCurrentUser ? .leading : .trailing, 40)
        .padding(.vertical, 2)
    }

    private func formatTime(_ sentAt: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: sentAt) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        }
        return ""
    }
}
