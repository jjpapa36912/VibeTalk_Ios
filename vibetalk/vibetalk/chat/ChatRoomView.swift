import SwiftUI
import CoreText


//struct ChatMember: Codable, Identifiable {
//    let id: Int
//    let name: String
//    let statusMessage: String?
//    let profileImageUrl: String?
//    enum CodingKeys: String, CodingKey {
//            case id
//            case name
//            case statusMessage
//            case profileImageUrl = "profileImageUrl" // ✅ 서버 JSON과 일치시킴
//        }
//}


struct DecodableEmotionResult: Codable {
    let client_text: String
    let pitch: Float
    let volume: Float
    let emotion: String
    let confidence: Float
    let source: String
    // ✅ 추가 (옵션)
    let transformed_text: String?
    let transformedText: String?
    let style_name: String?
    let styleName: String?
}


struct AnalyzeResponse: Codable {
    let status: String
    let hubert_emotion: String?
}


struct ChatMember: Codable, Identifiable {
    let id: Int
    let name: String
    let statusMessage: String?
    let profileImageUrl: String?
}

struct ChatRoomView: View {
    @EnvironmentObject var appState: AppState
    let room: ChatRoomResponse
    let currentUserId: Int

    @StateObject private var stompManager = ChatStompManager()
    @State private var inputMessage: String = ""
    @State private var members: [ChatMember] = []
    @FocusState private var isInputFocused: Bool

    @State private var uiMessages: [ChatMessageModel] = []
    @State private var isSending: Bool = false

    private var roomMode: ChatRoomMode { room.roomMode }

    var body: some View {
        VStack(spacing: 0) {
            // 상단 멤버 스크롤
            memberScrollView
            Divider()

            // 모드 안내 배너
            modeBanner

            // 메시지 목록
            messageScrollView

            // 입력창
            inputSection
        }
        .onTapGesture { isInputFocused = false }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("채팅목록") { appState.path.removeLast(appState.path.count) }
            }
        }
        .navigationTitle(room.roomName)
        .onAppear(perform: onAppearActions)
        .onDisappear(perform: onDisappearActions)
        .onReceive(stompManager.$latestMessage.compactMap { $0 }) { s in
            if let idx = uiMessages.firstIndex(where: { $0.id == s.id }) {
                uiMessages[idx] = s
            } else {
                uiMessages.append(s)
            }
        }
    }

    // MARK: UI Blocks

    private var memberScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(members) { m in
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .resizable().frame(width: 40, height: 40).clipShape(Circle())
                        Text(m.name).font(.caption).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal).padding(.top, 8)
        }
    }

    private var modeBanner: some View {
        HStack {
            Image(systemName: "megaphone.fill")
            Text(roomMode.noticeText)
                .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(uiMessages) { msg in
                        ChatBubbleView(message: msg, isCurrentUser: msg.senderId == currentUserId)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: uiMessages.count) { _ in
                if let last = uiMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var inputSection: some View {
        HStack(spacing: 8) {
            TextField("메시지 입력", text: $inputMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isInputFocused)
                .disabled(isSending)

            Button {
                Task { await sendFlow() }
            } label: {
                if isSending {
                    ProgressView().progressViewStyle(.circular)
                } else {
                    Text("보내기")
                }
            }
            .disabled(isSending || inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    // MARK: Actions

    private func onAppearActions() {
        fetchChatRoomMembers(roomId: room.id)
        stompManager.fetchRecentMessages(roomId: room.id) { msgs in
            DispatchQueue.main.async { self.uiMessages = msgs }
        }
        stompManager.connect(roomId: room.id, userId: currentUserId)
        markRoomAsRead(roomId: room.id)
    }

    private func onDisappearActions() {
        stompManager.disconnectStomp()
    }

    @MainActor
    private func sendFlow() async {
        // 중복 전송 방지 & 공백 방지
        let raw = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, !raw.isEmpty else { return }

        isSending = true
        defer {
            // 어떤 경로로 끝나든 UI 상태 정리
            inputMessage = ""
            isSending = false
            isInputFocused = false
        }

        // 1) 임시 버블(원문)
        let tempId = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())

        uiMessages.append(
            ChatMessageModel(
                id: tempId,
                senderId: currentUserId,
                senderName: "Me",
                content: raw,
                sentAt: now,
                source: "client"
            )
        )

        // 2) 톤 변환 호출 (async로 래핑)
        let convertResult = await convertToneAsync(sentence: raw, mode: roomMode)

        switch convertResult {
        case .success(let res):
            // 3) 변환문으로 UI 덮어쓰기
            if let idx = uiMessages.firstIndex(where: { $0.id == tempId }) {
                uiMessages[idx] = uiMessages[idx].withUpdated(content: res.output, source: "style")
            }
            // 4) 변환문 STOMP 전송
            stompManager.sendTextMessage(clientMessageId: tempId, content: res.output, sentAt: now)

        case .failure(let err):
            print("❌ Tone convert 실패: \(err.localizedDescription)")
            // 실패 시 원문 그대로 전송 (또는 여기서 취소하고 임시 버블만 유지도 가능)
            stompManager.sendTextMessage(clientMessageId: tempId, content: raw, sentAt: now)
        }
    }

    /// completion 기반 ToneService를 async로 감싼 로컬 헬퍼
    /// completion 기반 ToneService를 async/await로 감싼 로컬 헬퍼
    private func convertToneAsync(
        sentence: String,
        mode: ChatRoomMode
    ) async -> Result<ConvertResponseBody, ToneServiceError> {
        await withCheckedContinuation { cont in
            ToneService.convert(sentence: sentence, mode: mode) { result in
                cont.resume(returning: result)
            }
        }
    }



    private func markRoomAsRead(roomId: Int) {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/read"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req).resume()
    }

    private func fetchChatRoomMembers(roomId: Int) {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/members") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: req) { data, resp, _ in
            guard let data = data,
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode)
            else { return }
            if let decoded = try? JSONDecoder().decode([ChatMember].self, from: data) {
                DispatchQueue.main.async { self.members = decoded }
            }
        }.resume()
    }
}
