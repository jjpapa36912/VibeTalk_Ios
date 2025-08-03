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
}


import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessageModel
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .frame(maxWidth: 250, alignment: .trailing)
                    
                    Text(formatTime(message.sentAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(message.content)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(15)
                        .frame(maxWidth: 250, alignment: .leading)
                    
                    Text(formatTime(message.sentAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .padding(isCurrentUser ? .leading : .trailing, 40)
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ sentAt: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: sentAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return displayFormatter.string(from: date)
        }
        return ""
    }
}
