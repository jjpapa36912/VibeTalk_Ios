import SwiftUI
import Foundation

// 서버에서 가져오는 채팅방 목록 모델
struct ChatRoomListItem: Identifiable, Codable, Hashable {

    let id: Int
    let roomName: String
    let createdBy: String?
    let createdAt: String?
    //    let id: Int
//    let roomName: String
//    let createdBy: String?
//    let createdAt: String?
//    
//    // 미래 확장을 위해 추가 (현재 응답에 없으므로 자동 무시됨)
//    let lastMessage: String?
//    let lastMessageTime: String?
//    let unreadCount: Int?
//    let participants: [ChatParticipant]?
}

struct ChatParticipant: Codable, Hashable {
    let id: Int
    let name: String
}

// 기존 ChatRoomResponse와 동일하게 맞춤
struct ChatRoomResponse: Identifiable, Codable, Hashable {
    let id: Int
    let roomName: String
}

// MARK: - ChatRoomListView

struct ChatRoomListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatRoomListViewModel()
    @State private var isShowingCreateRoom = false   // ✅ Sheet 제어
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
                .navigationDestination(for: ChatRoomResponse.self) { room in
                    ChatRoomView(
                        room: room,
                        currentUserId: currentUserId
                    )
                    .environmentObject(appState)
                }
                
                Button(action: {
                    print("📌 새 그룹 채팅 만들기 클릭")
                    isShowingCreateRoom = true
                }) {
                    Label("새 그룹 채팅 만들기", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.headline)
                        .padding()
                }
            }
            .navigationTitle("채팅방")
            .onAppear {
                viewModel.fetchChatRooms()
                viewModel.fetchFriends()
            }
            // ✅ Modal Sheet 추가
            .sheet(isPresented: $isShowingCreateRoom) {
                CreateChatRoomView(
                    friends: viewModel.friends,
//                    currentUserId: currentUserId,
                    onRoomCreated: { room in
                        isShowingCreateRoom = false
                        viewModel.fetchChatRooms()       // ✅ 목록 즉시 갱신

                        appState.path.append(room)
                        
                    }
                )
                .environmentObject(appState)
            }
        }
    }
    
    private func roomRow(_ room: ChatRoomListItem) -> some View {
        HStack(spacing: 12) {
            // 기본 아이콘
            Image(systemName: "person.3.fill")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(room.roomName)
                    .font(.headline)
                
                if let createdBy = room.createdBy {
                    Text("방장: \(createdBy)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let createdAt = room.createdAt {
                    Text("생성일: \(formatTime(createdAt))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
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
