import SwiftUI
struct ChatMember: Codable, Identifiable {
    let id: Int
    let name: String
    let statusMessage: String?
    let profileImageUrl: String?
    enum CodingKeys: String, CodingKey {
            case id
            case name
            case statusMessage
            case profileImageUrl = "profileImageUrl" // ✅ 서버 JSON과 일치시킴
        }
}





struct ChatRoomView: View {
    @EnvironmentObject var appState: AppState
    let room: ChatRoomResponse?
    let currentUserId: Int
    
    @StateObject private var stompManager = ChatStompManager()
    @State private var inputMessage = ""
    @State private var members: [ChatMember] = []

    var body: some View {
        VStack {
            // ✅ 참가자 목록 (상단)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(members) { member in
                        VStack(spacing: 4) {
                            if let url = member.profileImageUrl.flatMap({ URL(string: "\(AppConfig.baseURL)\($0)") }) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image { image.resizable() }
                                    else { Image(systemName: "person.circle").resizable() }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            }
                            Text(member.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            Divider()
            
            // ✅ 메시지 목록
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(stompManager.messages, id: \.id) { msg in
                        ChatBubbleView(message: msg, isCurrentUser: msg.senderId == currentUserId)
                    }
                }
                .padding(.horizontal)
            }
            
            // ✅ 메시지 입력창
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
                    appState.path.removeLast(appState.path.count)
                }
            }
        }
        .navigationTitle(room?.roomName ?? "채팅방")
        .onAppear {
            print("🟢 ChatRoomView onAppear → roomId: \(room?.id ?? -1)")

            if let roomId = room?.id {
                fetchChatRoomMembers(roomId: roomId)   // ✅ 참가자 정보 로딩
                stompManager.connect(roomId: roomId, userId: currentUserId)
                markRoomAsRead(roomId: roomId)
            }
        }
        .onDisappear {
            stompManager.disconnect()
        }
    }
    
    // ✅ 읽음 처리
    private func markRoomAsRead(roomId: Int) {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/chat/rooms/\(roomId)/read"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // ✅ 참가자 불러오기
    private func fetchChatRoomMembers(roomId: Int) {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/chat/rooms/\(roomId)/members"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 멤버 조회 실패:", error.localizedDescription)
                return
            }
            guard let data = data else { return }

            if let decoded = try? JSONDecoder().decode([ChatMember].self, from: data) {
                DispatchQueue.main.async {
                    print("✅ 멤버 불러오기 성공: \(decoded.count)명")
                    self.members = decoded
                }
            } else {
                print("⚠️ 멤버 디코딩 실패")
            }
        }.resume()
    }
}
