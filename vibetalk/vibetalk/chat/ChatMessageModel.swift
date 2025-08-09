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
        let key = (message.emotion ?? "neutral").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // 우선순위: message.fontName → emotionStyles → 폴백
        let styleFontName = (message.fontName?.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? emotionStyles[key]?.fontName
            ?? "YOnepick-Regular"
        let emoji = message.emoji ?? emotionStyles[key]?.emoji ?? "🙂"
        
        HStack {
            if isCurrentUser { Spacer() }
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text("\(emoji) \(message.content)")
                    .font(.custom(styleFontName, size: 17)) // 마지막에 단 한 번만 적용
                    .foregroundColor(.white)
                    .padding(10)
                    .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.6))
                    .cornerRadius(12)
            }
            if !isCurrentUser { Spacer() }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}
