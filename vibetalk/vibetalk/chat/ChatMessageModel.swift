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

struct ChatBubbleView: View {
    let message: ChatMessageModel
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer() // 오른쪽 정렬
                Text(message.message)
                    .padding()
                    .background(Color.blue.opacity(0.8)) // 하늘색 말풍선
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .frame(maxWidth: 250, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.senderName) // 상대방 이름
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(message.message)
                        .padding()
                        .background(Color.gray.opacity(0.2)) // 추천 색상
                        .foregroundColor(.black)
                        .cornerRadius(15)
                        .frame(maxWidth: 250, alignment: .leading)
                }
                Spacer()
            }
        }
        .padding(isCurrentUser ? .leading : .trailing, 40)
        .padding(.vertical, 2)
    }
}
