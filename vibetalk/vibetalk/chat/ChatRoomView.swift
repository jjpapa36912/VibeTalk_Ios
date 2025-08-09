import SwiftUI
import CoreText


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
//    @State private var messages: [EmotionResult] = []
    @FocusState private var isInputFocused: Bool  // 🔍 포커스 상태 추적
    @State private var lastMessageId: UUID?  // 🔴 추가됨
    @State private var pendingMessageId: String?
    @State private var pendingMessages: [EmotionResult] = []   // 임시(로컬) 메시지 전용
    @State private var uiMessages: [ChatMessageModel] = []   // 화면에 그릴 ‘단일’ 소스
    @State private var sentFinalIds: Set<String> = []  // 이미 서버에 보낸 client_id들







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
                handleIncomingEmotionResult(with: newResult)  // 여기서 uiMessages를 in-place 업데이트
            }
            // ③ STOMP 서버 메시지/이력 → 화면 소스(uiMessages)에 머지
        
            .onReceive(stompManager.$messages) { serverMsgs in
                var out = uiMessages
                for s in serverMsgs.map(enrichEmotionFields) {
                    if let idx = out.firstIndex(where: { $0.id == s.id }) {
                        // 같은 id면 그대로 덮어쓰기
                        out[idx] = s
                    } else if let idxByMine = out.firstIndex(where: {
                        // 내 임시 버블과 동일 텍스트(또는 pendingMessageId 매칭)인 경우 서버 id로 치환
                        $0.senderId == currentUserId &&
                        $0.content.trimmingCharacters(in: .whitespacesAndNewlines) ==
                        s.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    }) {
                        out[idxByMine] = s   // 👈 서버 메시지로 대체 (id도 서버 id로 바뀜)
                    } else {
                        out.append(s)        // 정말 새로운 메시지면 추가
                    }
                }
                uiMessages = out
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
    private func adaptToChatMessage(_ e: EmotionResult) -> ChatMessageModel {
        return ChatMessageModel(
            id: e.id,
            senderId: currentUserId,
            senderName: "Me",
            content: e.client_text,     // ❗️순수 텍스트만
            sentAt: e.sentAt, emotion: e.emotion,
            fontName: e.fontName,
            emoji: e.emoji,             // 이모지는 필드로만
            source: e.source
        )
    }

    // 서버 + 임시를 하나로 묶어 렌더
    private var combinedMessages: [ChatMessageModel] {
        stompManager.messages + pendingMessages.map(adaptToChatMessage)
    }

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(uiMessages) { msg in
                        ChatBubbleView(
                            message: msg,
                            isCurrentUser: msg.senderId == currentUserId
                        )
                        .id(msg.id)
                    }
                }
                .padding(.horizontal)
            }
            // 개수 변화(append 때만) 스크롤. in-place update는 count 변화 없음 → 스크롤 안 튐
            .onChange(of: uiMessages.count) { _ in
                if let last = uiMessages.last {
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

                // 임시 버블 추가 + 텍스트/ID 받기
                let (tempId, tempText) = stopRecordingAndSend()
                guard !tempId.isEmpty else { return }

                // 서버에 clientMessageId 함께 전송
                sendWithFastAPI(text: tempText, clientMessageId: tempId)

                inputMessage = ""
            } else {
                recorder.startRecording()
            }
        }) {
            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(recorder.isRecording ? .red : .blue)
        }
        .onReceive(recorder.$recognizedText) { text in
            if recorder.isRecording { self.inputMessage = text }
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


                    pendingMessages.append(result)
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
        for family in UIFont.familyNames {
            for name in UIFont.fontNames(forFamilyName: family) {
                print("📌 \(name)")
            }
        }
        fetchChatRoomMembers(roomId: room.id)

        stompManager.fetchRecentMessages(roomId: room.id) { msgs in
                print("📥 fetchRecentMessages 완료. 개수=\(msgs.count)")
                DispatchQueue.main.async {
                    let enriched = msgs.map { enrichEmotionFields($0) }
                    self.stompManager.messages = enriched   // (필요 시 유지)
                    self.uiMessages = enriched              // ✅ 화면 소스 채우기
                }
            }

        stompManager.connect(roomId: room.id, userId: currentUserId)
        markRoomAsRead(roomId: room.id)
        wsManager.connect()  // 감정 WS는 결과만 받아서 최종 전송 트리거 용도로만 사용
    }
    
    
    

    

    
    
    private func enrichEmotionFields(_ m: ChatMessageModel) -> ChatMessageModel {
        var mm = m
        let key = (m.emotion ?? "neutral").lowercased()
        if mm.fontName == nil { mm.fontName = emotionStyles[key]?.fontName ?? "YOnepick-Regular" }
        if mm.emoji == nil    { mm.emoji    = emotionStyles[key]?.emoji    ?? "🙂" }
        return mm
    }

        private func onDisappearActions() {
            stompManager.disconnect()
            wsManager.disconnect()
        }

    private func handleIncomingEmotionResult(with r: EmotionResult) {
        // 0) HuBERT는 화면 갱신만/표시 안 함
        guard r.source != "hubert" else { return }

        // 1) 스타일 보강
        var fixed = r
        if fixed.emoji == nil { fixed.emoji = emotionStyles[r.emotion]?.emoji }

        // 2) 같은 id로 제자리 갱신 (remove/append 금지)
        if let idx = uiMessages.firstIndex(where: { $0.id == fixed.id }) {
            uiMessages[idx] = uiMessages[idx].withUpdated(
                content: fixed.client_text,
                emotion: fixed.emotion,
                fontName: fixed.fontName ?? uiMessages[idx].fontName,
                emoji: fixed.emoji ?? uiMessages[idx].emoji,
                source: "openai"
            )
        } else if let idx = uiMessages.firstIndex(where: {
            $0.senderId == currentUserId &&
            $0.content.trimmingCharacters(in: .whitespacesAndNewlines)
            == fixed.client_text.trimmingCharacters(in: .whitespacesAndNewlines)
        }) {
            uiMessages[idx] = uiMessages[idx].withUpdated(
                content: fixed.client_text,
                emotion: fixed.emotion,
                fontName: fixed.fontName ?? uiMessages[idx].fontName,
                emoji: fixed.emoji ?? uiMessages[idx].emoji,
                source: "openai"
            )
        } else {
            // 보호용: 못 찾으면 append
            uiMessages.append(ChatMessageModel(
                id: fixed.id,
                senderId: currentUserId,
                senderName: "Me",
                content: fixed.client_text,
                sentAt: fixed.sentAt, emotion: fixed.emotion,
                fontName: fixed.fontName,
                emoji: fixed.emoji,
                source: "openai"
            ))
        }

        // 3) ✅ 최종만 서버로 저장 (한 번만)
        if fixed.source == "openai", !sentFinalIds.contains(fixed.id) {
            sentFinalIds.insert(fixed.id)

            // 서버 저장용 DTO 구성 (서버가 기대하는 필드만)
            let finalToSend = EmotionResult(
                id: fixed.id,                 // client_id 유지(브로드캐스트 합치기용)
                client_text: fixed.client_text,
                pitch: 0,
                volume: 0,
                emotion: fixed.emotion,
                confidence: fixed.confidence,
                source: "openai",
                fontName: fixed.fontName,
                emoji: fixed.emoji,
                senderId: currentUserId,
                senderName: "Current User",
                sentAt: fixed.sentAt
            )

            print("💾 [SAVE] 서버로 최종 메시지 전송(id=\(fixed.id))")
            stompManager.sendMessage(finalToSend)
        }
    }

//    private func handleIncomingEmotionResult(with newResult: EmotionResult) {
//        print("📩 WebSocket 수신됨: \(newResult.client_text) (\(newResult.emotion))")
//
//        let style = emotionStyles[newResult.emotion] ?? emotionStyles["neutral"]!
//
//        // ✅ emoji가 비어있으면 스타일에서 가져오기
//        var fixedResult = newResult
//        if fixedResult.emoji == nil {
//            fixedResult.emoji = style.emoji
//        }
//
//        // ✅ 기존 메시지 덮어쓰기 or 새 메시지 추가
//        if let index = messages.firstIndex(where: {
//            $0.client_text.trimmingCharacters(in: .whitespacesAndNewlines)
//            == fixedResult.client_text.trimmingCharacters(in: .whitespacesAndNewlines)
//        }) {
//            print("🔁 기존 메시지 덮어쓰기 at index \(index)")
//            messages[index] = fixedResult
//        } else {
//            print("➕ 새 메시지 추가")
//            messages.append(fixedResult)
//        }
//
//        // ✅ OpenAI 메시지일 경우 전송
//        if fixedResult.source == "openai" {
//            let finalMessage = "\(fixedResult.emoji ?? "") \(fixedResult.client_text)"
//            print("🧠 OpenAI 응답 전송: \(finalMessage)")
//            stompManager.sendMessage(fixedResult)
//        }
//
//        self.inputMessage = ""
//    }

    @discardableResult
    func stopRecordingAndSend() -> (id: String, text: String) {
        let trimmed = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "") }

        let tempId = UUID().uuidString
        pendingMessageId = tempId

        let style = emotionStyles["neutral"]
        let provisional = ChatMessageModel(
            id: tempId,                 // 🔑 최종까지 유지할 id
            senderId: currentUserId,
            senderName: "Me",
            content: trimmed,           // 이모지는 뷰에서 표시
            sentAt: ISO8601DateFormatter().string(from: Date()), emotion: "neutral",
            fontName: style?.fontName,
            emoji: style?.emoji,
            source: "client"
        )
        uiMessages.append(provisional)
        return (tempId, trimmed)
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

    private func sendWithFastAPI(text: String, clientMessageId: String) {
        let url = URL(string: "\(AppConfig.baseURLFastApi)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // 필드들
        appendField("text", text)
        appendField("user_id", String(currentUserId))
        appendField("room_id", String(room.id))
        appendField("client_id", clientMessageId)   // ✅ 핵심: 임시 버블 id 전달

        // 오디오(있으면 첨부)
        if let audioURL = recorder.recordedFileURL,
           let audioData = try? Data(contentsOf: audioURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [FastAPI] 요청 에러: \(error.localizedDescription)")
                return
            }
            if let code = (response as? HTTPURLResponse)?.statusCode {
                print("📡 [FastAPI] 상태코드: \(code)")
            }
            // 응답은 보통 "processing" → 결과는 Emotion WS로 옴
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
