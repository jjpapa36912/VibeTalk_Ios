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


struct DecodableEmotionResult: Codable {
    let client_text: String
    let pitch: Float
    let volume: Float
    let emotion: String
    let confidence: Float
    let source: String
}

struct AnalyzeResponse: Codable {
    let status: String
    let hubert_emotion: String?
}


struct ChatRoomView: View {
    @EnvironmentObject var appState: AppState
    let room: ChatRoomResponse
    let currentUserId: Int
    
    @StateObject private var stompManager = ChatStompManager()
    @State private var inputMessage: String = ""
    @State private var members: [ChatMember] = []
    @StateObject private var recorder = SpeechRecorder()
    @StateObject private var wsManager = EmotionWebSocketManager()
    @State private var messages: [EmotionResult] = []
    @FocusState private var isInputFocused: Bool  // 🔍 포커스 상태 추적
    @State private var lastMessageId: UUID?  // 🔴 추가됨



    var body: some View {
            VStack {
                memberScrollView
                Divider()
                messageScrollView
                micButton
                inputSection
            }
            .onTapGesture { isInputFocused = false }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("채팅목록") {
                        appState.path.removeLast(appState.path.count)
                    }
                }
            }
            .navigationTitle(room.roomName)
            .onAppear(perform: onAppearActions)
            .onDisappear(perform: onDisappearActions)
            .onReceive(wsManager.$latestEmotionResult.compactMap { $0 }) { newResult in
                handleIncomingEmotionResult(with: newResult)
            }
        }

        private var memberScrollView: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(members) { member in
                        memberProfileView(for: member)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(stompManager.messages) { msg in
                        ChatBubbleView(
                            message: msg,
                            isCurrentUser: msg.senderId == currentUserId
                        )
                        .id(msg.id)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: stompManager.messages.count) { _ in
                if let last = stompManager.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    
    private func isCurrentUserMessage(_ model: ChatMessageModel, currentUserId: Int) -> Bool {
        // 1순위: senderId가 있으면 그걸로
        if model.senderId >= 0 { return model.senderId == currentUserId }
        // 2순위(보완): 수동 전송/보낸이 이름 기반
        return model.source == "manual" || model.senderName == "Current User"
    }

    // 행 그리기용 평탄화 데이터 (타입 추론 쉬움)
    private struct MessageRowData: Identifiable, Equatable {
        let id: String
        let message: ChatMessageModel
        let isMine: Bool
    }

    private struct MessageRow: View {
        let row: MessageRowData
        var body: some View {
            ChatBubbleView(
                message: row.message,       // ✅ 이제 타입이 딱 맞음
                isCurrentUser: row.isMine
            )
        }
    }




        private var micButton: some View {
            Button(action: {
                if recorder.isRecording {
                    recorder.stopRecording()
                    sendWithFastAPI()
                } else {
                    recorder.startRecording()
                }
            }) {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(recorder.isRecording ? .red : .blue)
            }
            .onReceive(recorder.$recognizedText) { text in
                if recorder.isRecording {
                    self.inputMessage = text
                }
            }
        }

        private var inputSection: some View {
            HStack {
                TextField("메시지 입력", text: $inputMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)

                Button("보내기") {
                    let emotion = "neutral" // ✅ 직접 emotion 정의

                    let result = EmotionResult(
                        id: UUID().uuidString,  // UUID로 고유 id 생성
                        client_text: inputMessage,
                        pitch: 0,
                        volume: 0,
                        emotion: "neutral",
                        confidence: 0.0,
                        source: "manual",
                        fontName: nil,
                        emoji: emotionStyles["neutral"]?.emoji,  // 이모지 추가
                        senderId: currentUserId,                 // ✅ 추가
                        senderName: "Current User",              // 현재 사용자 이름
                        sentAt: ISO8601DateFormatter().string(from: Date())  // 현재 시간
                    )


                    messages.append(result)
                    stompSendTextMessage()
                    inputMessage = ""
                    isInputFocused = false
                }

            }
            .padding()
        }

    @ViewBuilder
    func emotionMessageView(for msg: EmotionResult) -> some View {
        let style = emotionStyles[msg.emotion] ?? emotionStyles["neutral"]!
        
        // ✅ 서버에서 전달된 emoji 우선 사용
        let emoji = msg.emoji ?? ""
        let text = "\(emoji) \(msg.client_text)"

        Text(text)
            .font(style.font)
            .foregroundColor(style.color)
            .padding()
            .background(msg.source == "hubert" ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
            .cornerRadius(8)
    }



    func fontFrom(fontName: String?, size: CGFloat = 22) -> Font {
        guard let name = fontName else { return .body }
        return Font.custom(name, size: size)
    }
//        private func stompSendTextMessage() {
//            if !inputMessage.isEmpty {
//                stompManager.sendMessage(inputMessage)
//            }
//        }

    private func onAppearActions() {
        print("👣 onAppearActions 진입. roomId=\(room.id)")
        fetchChatRoomMembers(roomId: room.id)

        stompManager.fetchRecentMessages(roomId: room.id) { msgs in
            print("📥 fetchRecentMessages 완료. 개수=\(msgs.count)")
            DispatchQueue.main.async {
                self.stompManager.messages = msgs        // ✅ 한 곳만 세팅
                print("🧩 UI messages 세팅 완료. count=\(self.stompManager.messages.count)")
            }
        }

        stompManager.connect(roomId: room.id, userId: currentUserId)
        markRoomAsRead(roomId: room.id)
        wsManager.connect()  // 감정 WS는 결과만 받아서 최종 전송 트리거 용도로만 사용
    }


        private func onDisappearActions() {
            stompManager.disconnect()
            wsManager.disconnect()
        }

    private func handleIncomingEmotionResult(with newResult: EmotionResult) {
        print("📩 WebSocket 수신됨: \(newResult.client_text) (\(newResult.emotion))")

        let style = emotionStyles[newResult.emotion] ?? emotionStyles["neutral"]!

        // ✅ emoji가 비어있으면 스타일에서 가져오기
        var fixedResult = newResult
        if fixedResult.emoji == nil {
            fixedResult.emoji = style.emoji
        }

        // ✅ 기존 메시지 덮어쓰기 or 새 메시지 추가
        if let index = messages.firstIndex(where: {
            $0.client_text.trimmingCharacters(in: .whitespacesAndNewlines)
            == fixedResult.client_text.trimmingCharacters(in: .whitespacesAndNewlines)
        }) {
            print("🔁 기존 메시지 덮어쓰기 at index \(index)")
            messages[index] = fixedResult
        } else {
            print("➕ 새 메시지 추가")
            messages.append(fixedResult)
        }

        // ✅ OpenAI 메시지일 경우 전송
        if fixedResult.source == "openai" {
            let finalMessage = "\(fixedResult.emoji ?? "") \(fixedResult.client_text)"
            print("🧠 OpenAI 응답 전송: \(finalMessage)")
            stompManager.sendMessage(fixedResult)
        }

        self.inputMessage = ""
    }



    private func stompSendTextMessage() {
        if !inputMessage.isEmpty {
            let emotion = "neutral" // ✅ 먼저 정의

            let result = EmotionResult(
                id: UUID().uuidString,  // UUID로 고유 id 생성
                client_text: inputMessage,
                pitch: 0,
                volume: 0,
                emotion: "neutral",
                confidence: 0.0,
                source: "manual",
                fontName: nil,
                emoji: emotionStyles["neutral"]?.emoji,  // 이모지 추가
                senderId: currentUserId,                 // ✅ 추가
                senderName: "Current User",              // 현재 사용자 이름
                sentAt: ISO8601DateFormatter().string(from: Date())  // 현재 시간
            )


            stompManager.sendMessage(result)
            inputMessage = ""
        }
    }


    @ViewBuilder
    private func memberProfileView(for member: ChatMember) -> some View {
        VStack(spacing: 4) {
            if let imageURL = member.profileImageUrl,
               let url = URL(string: "\(AppConfig.baseURLSpringBoot)\(imageURL)") {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                    } else {
                        Image(systemName: "person.circle")
                            .resizable()
                    }
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

    private func sendWithFastAPI() {
        guard let audioURL = recorder.recordedFileURL else {
            print("⚠️ [FastAPI] 오디오 URL이 없음. 수동 텍스트 전송 시도")
            let emotion = "neutral" // ✅ 먼저 emotion 정의

            let result = EmotionResult(
                id: UUID().uuidString,  // UUID로 고유 id 생성
                client_text: inputMessage,
                pitch: 0,
                volume: 0,
                emotion: "neutral",
                confidence: 0.0,
                source: "manual",
                fontName: nil,
                emoji: emotionStyles["neutral"]?.emoji,  // 이모지 추가
                senderId: currentUserId,                 // ✅ 추가
                senderName: "Current User",              // 현재 사용자 이름
                sentAt: ISO8601DateFormatter().string(from: Date())  // 현재 시간
            )

            stompManager.sendMessage(result)
            inputMessage = ""
            return
        }

        let url = URL(string: "\(AppConfig.baseURLFastApi)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        print("🧱 [FastAPI] Multipart Body 구성 시작")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(inputMessage)\r\n".data(using: .utf8)!)
        print("📦 text 추가 완료: \(inputMessage)")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(currentUserId)\r\n".data(using: .utf8)!)
        print("👤 user_id 추가 완료: \(currentUserId)")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"room_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(room.id)\r\n".data(using: .utf8)!)
        print("💬 room_id 추가 완료: \(room.id)")
        
        

        let audioData = try! Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        print("🎧 audio 추가 완료. 크기: \(audioData.count) bytes")

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        print("📤 [FastAPI] 최종 Body 크기: \(body.count) bytes")
        print("🚀 [FastAPI] 분석 요청 전송 시작 → \(url)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [FastAPI] 요청 중 에러 발생: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [FastAPI] 응답 코드: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ [FastAPI] 응답 데이터 없음")
                return
            }

            // 1. 우선 status 기반 응답 처리
            if let result = try? JSONDecoder().decode(AnalyzeResponse.self, from: data) {
                if result.status == "processing" {
                    print("✅ [FastAPI] 분석 요청 접수됨. 결과는 WebSocket으로 수신 예정.")
                    return
                }
            }

            // 2. 예외적으로 과거 EmotionResult 포맷이 오는 경우 처리
            if let result = try? JSONDecoder().decode(EmotionResult.self, from: data) {
                print("✅ [FastAPI] EmotionResult 응답 수신: \(result)")

                // 🧠 이모지 매핑
                var enrichedResult = result
                enrichedResult.emoji = emotionStyles[result.emotion]?.emoji ?? "🙂"

                DispatchQueue.main.async {
                    self.messages.append(enrichedResult)
                    self.stompManager.sendMessage(enrichedResult)
                }
            }
                    else {
                print("❌ [FastAPI] 응답 디코딩 실패")
                if let raw = String(data: data, encoding: .utf8) {
                    print("📦 [FastAPI] 응답 본문: \(raw)")
                } else {
                    print("📦 [FastAPI] 응답 본문 디코딩 불가 (encoding 문제)")
                }
            }
        }.resume()
    }


    private func markRoomAsRead(roomId: Int) {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/read"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request).resume()
    }

    private func fetchChatRoomMembers(roomId: Int) {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }

        func request(_ urlString: String, label: String, then next: (() -> Void)? = nil) {
            guard let url = URL(string: urlString) else { next?(); return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            print("🔎 [HTTP] GET(\(label)) \(url.absoluteString)")
            URLSession.shared.dataTask(with: req) { data, resp, error in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if let error = error { print("❌ 멤버 에러(\(label)): \(error)"); next?(); return }
                print("📡 멤버 상태(\(label)): \(code)")
                guard let data = data else { next?(); return }

                if code == 401 || code == 403 {
                    let raw = String(data: data, encoding: .utf8) ?? "<no body>"
                    print("🚫 멤버 권한(\(label)) RAW: \(raw)")
                    next?(); return
                }

                if let decoded = try? JSONDecoder().decode([ChatMember].self, from: data) {
                    DispatchQueue.main.async { self.members = decoded }
                } else {
                    let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                    print("⚠️ 멤버 디코딩 실패(\(label)) preview: \(preview)")
                    next?()
                }
            }.resume()
        }

        let primary = "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/members"
        let fallback = "\(AppConfig.baseURLSpringBoot)/chat/rooms/\(roomId)/members"
        request(primary, label: "primary") {
            request(fallback, label: "fallback") { }
        }
    }

}
