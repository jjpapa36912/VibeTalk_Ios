import SwiftUI
import Foundation

// 서버에서 가져오는 채팅방 목록 모델
struct ChatRoomListItem: Identifiable, Codable, Hashable {
    let id: Int
    let roomName: String
    let lastMessage: String?
    let lastMessageTime: String?
    let unreadCount: Int?
    let participants: [ChatParticipant]
}

struct ChatParticipant: Codable, Hashable {
    let id: Int
    let name: String
}

// 기존 ChatRoomResponse와 동일하게 맞춤
struct ChatRoomResponse: Identifiable, Codable , Hashable{
    let id: Int
    let roomName: String
}

// MARK: - ChatRoomListView

struct ChatRoomListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatRoomListViewModel()
    let currentUserId: Int
    
    var body: some View {
        NavigationStack(path: $appState.path) {
            VStack {
                List(viewModel.chatRooms) { room in
                    NavigationLink(value: room) {
                        roomRow(room)
                    }
                }
                .navigationDestination(for: ChatRoomListItem.self) { room in
                    ChatRoomView(
                        room: ChatRoomResponse(id: room.id, roomName: room.roomName),
                        currentUserId: currentUserId
                    )
                    .environmentObject(appState)
                }
                
                // ✅ 친구 선택 화면으로 이동하는 버튼 추가
                Button(action: {
                    print("📌 새 그룹 채팅 만들기 클릭")
                    appState.path.append("createRoom")   // 경로로 이동
                }) {
                    Label("새 그룹 채팅 만들기", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.headline)
                        .padding()
                }
            }
            // ✅ String 타입 destination 정의
            .navigationDestination(for: String.self) { value in
                if value == "createRoom" {
                    CreateChatRoomView(
                        friends: viewModel.friends,  // 여기에 friends 데이터를 로딩해야 함
                        currentUserId: currentUserId
                    )
                    .environmentObject(appState)
                }
            }
            .navigationTitle("채팅방")
            .onAppear {
                viewModel.fetchChatRooms()
                viewModel.fetchFriends()   // ✅ 추가

            }
        }
    }
    
    private func roomRow(_ room: ChatRoomListItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(room.roomName)
                        .font(.headline)
                    Spacer()
                    if let time = room.lastMessageTime {
                        Text(formatTime(time))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Text("참여자: \(room.participants.map { $0.name }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.gray)
                if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let unread = room.unreadCount, unread > 0 {
                Text("\(unread)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let output = DateFormatter()
            output.dateFormat = "HH:mm"
            return output.string(from: date)
        }
        return ""
    }
}
