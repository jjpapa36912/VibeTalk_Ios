import SwiftUI

import SwiftUI

struct CreateChatRoomView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFriends: Set<Int> = []
    @State private var isCreatingRoom = false
    let friends: [FriendResponse]
    let onRoomCreated: (ChatRoomResponse) -> Void

    var body: some View {
        VStack {
            if !selectedFriends.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(friends.filter { selectedFriends.contains($0.id) }) { friend in
                            VStack {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                }
            }

            List(friends) { friend in
                HStack {
                    Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
                    Spacer()
                    Button(action: {
                        if selectedFriends.contains(friend.id) {
                            selectedFriends.remove(friend.id)
                        } else if selectedFriends.count < 7 { // ✅ 총 8명 제한
                            selectedFriends.insert(friend.id)
                        }
                    }) {
                        Image(systemName: selectedFriends.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedFriends.contains(friend.id) ? .blue : .gray)
                    }
                }
            }

            Spacer()

            Button(action: {
                guard !isCreatingRoom else { return }
                isCreatingRoom = true
                print("📡 그룹 채팅방 생성 요청: \(selectedFriends)")

                ChatService.shared.createChatRoom(
                    memberIds: Array(selectedFriends),
                    roomName: "새 그룹"
                ) { result in
                    DispatchQueue.main.async {
                        isCreatingRoom = false
                        switch result {
                        case .success(let room):
                            print("🎉 방 생성 성공: \(room)")
                            onRoomCreated(room)   // ✅ MainView에서 목록 갱신하도록 보냄
                        case .failure(let error):
                            print("❌ 방 생성 실패: \(error.localizedDescription)")
                        }
                    }
                }
            })  {
                Text("방 생성하기")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedFriends.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .disabled(selectedFriends.isEmpty || isCreatingRoom)
        }
        .navigationTitle("그룹 채팅")
    }
}

//struct CreateChatRoomView: View {
//    @EnvironmentObject var appState: AppState
//    @State private var selectedFriends: Set<Int> = []
//    @State private var isCreatingRoom = false
//    let friends: [FriendResponse]
//    let currentUserId: Int
//    let onRoomCreated: (ChatRoomResponse) -> Void   // ✅ 콜백 추가
//    
//    var body: some View {
//        VStack {
//            if !selectedFriends.isEmpty {
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack(spacing: 12) {
//                        ForEach(friends.filter { selectedFriends.contains($0.id) }) { friend in
//                            VStack {
//                                Image(systemName: "person.circle.fill")
//                                    .resizable()
//                                    .frame(width: 50, height: 50)
//                                    .clipShape(Circle())
//                                Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
//                                    .font(.caption)
//                                    .lineLimit(1)
//                            }
//                        }
//                    }
//                    .padding()
//                }
//            }
//            
//            List(friends) { friend in
//                HStack {
//                    Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
//                    Spacer()
//                    Button(action: {
//                        if selectedFriends.contains(friend.id) {
//                            selectedFriends.remove(friend.id)
//                        } else if selectedFriends.count < 8 {
//                            selectedFriends.insert(friend.id)
//                        }
//                        print("✅ 선택된 친구: \(selectedFriends)")
//                    }) {
//                        Image(systemName: selectedFriends.contains(friend.id) ? "checkmark.circle.fill" : "circle")
//                            .foregroundColor(selectedFriends.contains(friend.id) ? .blue : .gray)
//                    }
//                }
//            }
//            
//            Spacer()
//            
//            Button(action: {
//                print("📌 방 생성 버튼 클릭됨")
//                guard !isCreatingRoom else { return }
//                isCreatingRoom = true
//                
//                let userIds = Array(selectedFriends) + [currentUserId]
//                print("📤 방 생성 요청: \(userIds)")
//                
//                ChatService.shared.createChatRoom(
//                    userIds: userIds,
//                    creatorId: currentUserId,
//                    roomName: "새 그룹"
//                ) { result in
//                    DispatchQueue.main.async {
//                        isCreatingRoom = false
//                        switch result {
//                        case .success(let room):
//                            print("✅ 방 생성 성공: \(room)")
//                            onRoomCreated(room)
//                        case .failure(let error):
//                            print("❌ 방 생성 실패: \(error.localizedDescription)")
//                        }
//                    }
//                }
//            }) {
//                Text("방 생성하기")
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(selectedFriends.isEmpty ? Color.gray : Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                    .padding(.horizontal)
//            }
//            .disabled(selectedFriends.isEmpty || isCreatingRoom)
//        }
//        .navigationTitle("그룹 채팅")
//    }
//}
