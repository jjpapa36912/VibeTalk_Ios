import SwiftUI
import SwiftUI

// MARK: - ChatRoomView
struct ChatRoomView: View {
    @EnvironmentObject var appState: AppState
    let room: ChatRoomResponse?
    let currentUserId: Int
    
    @StateObject private var stompManager = ChatStompManager()
    @State private var inputMessage = ""

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(stompManager.messages, id: \.id) { msg in
                        ChatBubbleView(message: msg, isCurrentUser: msg.senderId == currentUserId)
                    }
                }
                .padding(.horizontal)
            }
            HStack {
                TextField("메시지 입력", text: $inputMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("보내기") {
                    stompManager.sendMessage(inputMessage)
                    inputMessage = ""
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("채팅목록") {
                    // ✅ Root로 돌아가기
                    appState.path.removeLast(appState.path.count)
                }
            }
        }
        .navigationTitle(room?.roomName ?? "채팅방")
        .onAppear {
            if let roomId = room?.id {
                stompManager.connect(roomId: roomId, userId: currentUserId)
                markRoomAsRead(roomId: roomId)
            }
        }
        .onDisappear {
            stompManager.disconnect()
        }
    }
    
    private func markRoomAsRead(roomId: Int) {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/chat/rooms/\(roomId)/read"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request).resume()
    }
}
