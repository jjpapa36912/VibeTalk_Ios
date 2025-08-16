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
struct ChatMessageResponse: Codable {
    let id: Int
    let clientMessageId: String?
    let senderId: Int
    let senderName: String
    let content: String
    let sentAt: String
    let source: String?
}

import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessageModel
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            Text(message.content)
                .padding(10)
                .background(isCurrentUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    HStack {
                        Spacer()
                        if message.source == "style" {
                            Image(systemName: "wand.and.stars").font(.caption2).padding(.trailing, 6)
                        }
                    }
                )
            if !isCurrentUser { Spacer() }
        }
    }
}
