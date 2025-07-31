//
//  CreateChatRoomView.swift
//  vibetalk
//
//  Created by 김동준 on 7/31/25.
//

import Foundation
import SwiftUI

struct CreateChatRoomView: View {
    @State private var selectedFriends: Set<Int> = []  // ✅ 선택된 친구 id 저장
    let friends: [FriendResponse]
    
    var body: some View {
        VStack {
            // ✅ 상단 선택된 프로필 보여주기
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(friends.filter { selectedFriends.contains($0.id) }) { friend in
                        VStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                            Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // ✅ 친구 리스트
            List(friends) { friend in
                HStack {
                    Image(systemName: "person.circle")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    
                    Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        if selectedFriends.contains(friend.id) {
                            selectedFriends.remove(friend.id)
                        } else if selectedFriends.count < 8 { // 최대 8명
                            selectedFriends.insert(friend.id)
                        }
                    }) {
                        Image(systemName: selectedFriends.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedFriends.contains(friend.id) ? .blue : .gray)
                            .font(.title2)
                    }
                }
            }
        }
        .navigationTitle("그룹 채팅")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("완료") {
                    // ✅ 채팅방 생성 API 호출 또는 로직
                    print("선택된 친구:", selectedFriends)
                }
                .disabled(selectedFriends.isEmpty)
            }
        }
    }
}
