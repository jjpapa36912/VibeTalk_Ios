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
                print("➡️ onReceive WS id=\(newResult.id) src=\(newResult.source) senderId=\(String(describing: newResult.senderId)) roomId=\(String(describing: newResult.roomId))")

                handleIncomingEmotionResult(with: newResult)  // 여기서 uiMessages를 in-place 업데이트
            }
            // ③ STOMP 서버 메시지/이력 → 화면 소스(uiMessages)에 머지
        
            .onReceive(stompManager.$latestMessage.compactMap { $0 }) { s in
                if let idx = uiMessages.firstIndex(where: { $0.id == s.id }) {
                    let existing = uiMessages[idx]
                    if existing.source == "style" && s.source != "style" {
                        return  // ✅ 스타일 확정된 버블은 원문으로 되돌리지 않음
                    }
                    uiMessages[idx] = s
                } else {
                    uiMessages.append(s)
                }
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
            content: e.transformed_text?.isEmpty == false ? e.transformed_text! : e.client_text, // ✅
            sentAt: e.sentAt,
            emotion: e.emotion,
            fontName: e.fontName,
            emoji: e.emoji,
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
                sendStyleTransform(text: tempText, clientMessageId: tempId)


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



    // ⬇️ 이 블록 전체를 교체
    private var inputSection: some View {
        HStack {
            TextField("메시지 입력", text: $inputMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isInputFocused)
            
            Button("보내기", action: {
                // 0) 공백 방지
                let text = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    return
                }
                
                // 1) 임시 버블(draft) 생성
                let draft = EmotionResult.draft(
                    text: text,
                    currentUserId: currentUserId
                ) // 이름은 "Me"로 자동

                
                // 2) 화면에 즉시 표시 (내 말풍선)
                uiMessages.append(
                    ChatMessageModel(
                        id: draft.id,
                        senderId: currentUserId,
                        senderName: "Me",
                        content: draft.client_text,
                        sentAt: draft.sentAt,
                        emotion: "neutral",
                        fontName: emotionStyles["neutral"]?.fontName,
                        emoji: emotionStyles["neutral"]?.emoji,
                        source: "client"
                    )
                )
                
                // 3) 서버 저장
                stompManager.sendMessage(draft)
                sendStyleTransform(text: draft.client_text, clientMessageId: draft.id)

                
                // 4) 입력창 정리
                inputMessage = ""
                isInputFocused = false
            })
        }
        .padding()
    }


    private func upsertIncoming(_ m: EmotionResult) {
        // 1) clientMessageId로 매치 → 있으면 덮어쓰기
        if let i = messages.firstIndex(where: { $0.id == m.id }) {
            messages[i] = m
            return
        }

        // 2) 혹시 내 메시지라면(임시 버블을 못 찾았더라도) append 금지
        if let sid = m.senderId, sid == currentUserId {
            return
        }

        // 3) 그 외에는 새로 추가
        messages.append(m)
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
        sentFinalIds.removeAll()   // ✅ 재입장 시 초기화

       
        fetchChatRoomMembers(roomId: room.id)

        stompManager.fetchRecentMessages(roomId: room.id) { msgs in
                print("📥 fetchRecentMessages 완료. 개수=\(msgs.count)")
                DispatchQueue.main.async {
                    let enriched = msgs.map { enrichEmotionFields($0) }
                    self.uiMessages = enriched
                }
            }

        stompManager.connect(roomId: room.id, userId: currentUserId)
        markRoomAsRead(roomId: room.id)
        wsManager.connect(userId: currentUserId, roomId: room.id)
    }
    
    
    

    

    
    
    private func enrichEmotionFields(_ m: ChatMessageModel) -> ChatMessageModel {
        var mm = m
        let key = (m.emotion ?? "neutral").lowercased()
        if mm.fontName == nil { mm.fontName = emotionStyles[key]?.fontName ?? "YOnepickTTF-Regular" }
        if mm.emoji == nil    { mm.emoji    = emotionStyles[key]?.emoji    ?? "🙂" }
        return mm
    }

        private func onDisappearActions() {
            stompManager.disconnectStomp()
            wsManager.disconnect()
        }

    // 파일: ChatRoomView.swift
    private func handleIncomingEmotionResult(with r: EmotionResult) {
        // 0) 필터: 내 메시지/현재 방만 처리
        if let sid = r.senderId, sid != currentUserId { return }
        if let rid = r.roomId, rid != room.id { return }

        var fixed = r

        // 기본 이모지 보강
        if fixed.emoji == nil {
            fixed.emoji = emotionStyles[fixed.emotion.lowercased()]?.emoji ?? "🙂"
        }

        // 1) id로 우선 매칭
        var targetIndex = uiMessages.firstIndex(where: { $0.id == fixed.id })

        // 2) pendingId로 매칭 (녹음/전송 직후 임시 버블 → 서버 id 덮어쓰기)
        if targetIndex == nil, let pid = pendingMessageId,
           let idx = uiMessages.firstIndex(where: { $0.id == pid }) {
            let base = uiMessages[idx]
            uiMessages[idx] = ChatMessageModel(
                id: fixed.id.isEmpty ? base.id : fixed.id,
                senderId: base.senderId,
                senderName: base.senderName,
                content: base.content,
                sentAt: base.sentAt,
                emotion: base.emotion,
                fontName: base.fontName,
                emoji: base.emoji,
                source: base.source
            )
            targetIndex = idx
        }

        // 3) 폴백 매칭
        // 3-1) STYLE 패킷: 같은 원문(client_text)인 내 마지막 버블
        if targetIndex == nil && fixed.source == "style" {
            targetIndex = uiMessages.lastIndex(where: {
                $0.senderId == currentUserId &&
                $0.content == fixed.client_text
            })
        }
        // 3-2) OPENAI 패킷: 같은 원문(client_text)인 내 마지막 버블
        if targetIndex == nil && fixed.source == "openai" {
            targetIndex = uiMessages.lastIndex(where: {
                $0.senderId == currentUserId &&
                $0.content == fixed.client_text
            })
        }

        // 매칭 실패 시 스킵 (중복 추가 방지)
        guard let i = targetIndex else { return }
        print("🧪 before overwrite idx=\(String(describing: targetIndex))")

        // 4) in-place 덮어쓰기
        if fixed.source == "style" {
            // 스타일 변환: 변환문으로 content 교체, 감정/폰트/이모지는 유지
            if let tx = fixed.transformed_text, !tx.isEmpty {
                uiMessages[i] = uiMessages[i].withUpdated(
                    content: tx,                              // ✅ 변환문 반영
                    emotion: uiMessages[i].emotion,          // 감정 유지
                    fontName: uiMessages[i].fontName,        // 폰트 유지
                    emoji: uiMessages[i].emoji,              // 이모지 유지
                    source: "style"
                )
                print("✅ overwritten(style) idx=\(i) id=\(uiMessages[i].id) src=style")
            } else {
                // transformed_text가 비어 있으면 안전하게 패스
                print("⚠️ style packet without transformed_text → skip")
                print("⚠️ style packet without transformed_text → skip")

                return
            }
        } else {
            // 기존 로직: openai/hubert 등은 client_text와 감정 정보를 반영
            uiMessages[i] = uiMessages[i].withUpdated(
                content: fixed.client_text,
                emotion: fixed.emotion,
                fontName: fixed.fontName ?? uiMessages[i].fontName,
                emoji: fixed.emoji ?? uiMessages[i].emoji,
                source: fixed.source
            )
            print("✅ overwritten idx=\(i) id=\(uiMessages[i].id) emotion=\(fixed.emotion) src=\(fixed.source)")
        }

        // 매칭 완료 후 pending 해제
        pendingMessageId = nil

        // 5) 최종 업서트 전송 (중복 방지)
        //    - openai 결과는 기존처럼 STOMP로 동기화
        if fixed.source == "openai" {
            let mergedId = uiMessages[i].id  // STOMP/DB 병합 키
            if sentFinalIds.contains(mergedId) == false {
                sentFinalIds.insert(mergedId)
                let finalToSend = EmotionResult(
                    id: mergedId,                          // 버블 id
                    client_text: uiMessages[i].content,    // 덮어쓴 최신 content
                    pitch: 0, volume: 0,
                    emotion: uiMessages[i].emotion ?? fixed.emotion,
                    confidence: fixed.confidence,
                    source: "openai",
                    fontName: uiMessages[i].fontName ?? fixed.fontName,
                    emoji: uiMessages[i].emoji ?? fixed.emoji,
                    senderId: currentUserId,
                    senderName: "Current User",
                    sentAt: fixed.sentAt,
                    roomId: r.roomId
                )
                stompManager.sendMessage(finalToSend)
            }
            print("📨 stomp sent? \(fixed.source == "openai")")
        }

        // (선택) style 최종본도 서버와 싱크하고 싶다면 아래를 활성화
        
        if fixed.source == "style" {
            let mergedId = uiMessages[i].id
            if sentFinalIds.contains(mergedId) == false {
                sentFinalIds.insert(mergedId)
                let finalToSend = EmotionResult(
                    id: mergedId,
                    client_text: uiMessages[i].content,     // 변환된 문장
                    pitch: 0, volume: 0,
                    emotion: uiMessages[i].emotion ?? "neutral",
                    confidence: fixed.confidence,
                    source: "style",
                    fontName: uiMessages[i].fontName,
                    emoji: uiMessages[i].emoji,
                    senderId: currentUserId,
                    senderName: "Current User",
                    sentAt: fixed.sentAt,
                    roomId: r.roomId
                )
                stompManager.sendMessage(finalToSend)
            }
        }
        
    }

//    private func handleIncomingEmotionResult(with r: EmotionResult) {
//        // 0) 필터
//        if let sid = r.senderId, sid != currentUserId { return }
//        if let rid = r.roomId, rid != room.id { return }
//
//        var fixed = r
//        if fixed.emoji == nil {
//            fixed.emoji = emotionStyles[fixed.emotion.lowercased()]?.emoji ?? "🙂"
//        }
//
//        // 1) id로 찾기
//        var targetIndex = uiMessages.firstIndex(where: { $0.id == fixed.id })
//
//        // 2) pendingId로 찾기
//        if targetIndex == nil, let pid = pendingMessageId,
//           let idx = uiMessages.firstIndex(where: { $0.id == pid }) {
//            let base = uiMessages[idx]
//            uiMessages[idx] = ChatMessageModel(
//                id: fixed.id.isEmpty ? base.id : fixed.id,
//                senderId: base.senderId,
//                senderName: base.senderName,
//                content: base.content,
//                sentAt: base.sentAt,
//                emotion: base.emotion,
//                fontName: base.fontName,
//                emoji: base.emoji,
//                source: base.source
//            )
//            targetIndex = idx
//        }
//
//        // 🔥 3) 폴백: openai 패킷에 id가 없을 때(지금 상황) → "내가 방금 보낸 같은 텍스트" 버블로 매칭
//        if targetIndex == nil && fixed.source == "openai" {
//            targetIndex = uiMessages.lastIndex(where: {
//                $0.senderId == currentUserId &&
//                $0.content == fixed.client_text
//            })
//        }
//
//        guard let i = targetIndex else {
//            // 여전히 못 찾으면 그냥 스킵 (중복 방지)
//            return
//        }
//        print("🧪 before overwrite idx=\(String(describing: targetIndex))")
//
//        // 4) in-place 덮어쓰기
//        uiMessages[i] = uiMessages[i].withUpdated(
//            content: fixed.client_text,
//            emotion: fixed.emotion,
//            fontName: fixed.fontName ?? uiMessages[i].fontName,
//            emoji: fixed.emoji ?? uiMessages[i].emoji,
//            source: fixed.source
//        )
//        print("✅ overwritten idx=\(i) id=\(uiMessages[i].id) emotion=\(fixed.emotion) src=\(fixed.source)")
//
//        pendingMessageId = nil
//
//        // 5) 최종 업서트 전송 (중복 방지) — ⚠️ 여기의 id는 "버블의 id"로
//        if fixed.source == "openai" {
//            let mergedId = uiMessages[i].id  // ← 이 id가 STOMP/DB 병합 키
//            if sentFinalIds.contains(mergedId) == false {
//                sentFinalIds.insert(mergedId)
//
//                let finalToSend = EmotionResult(
//                    id: mergedId,                          // ✅ 버블 id
//                    client_text: fixed.client_text,
//                    pitch: 0, volume: 0,
//                    emotion: fixed.emotion,
//                    confidence: fixed.confidence,
//                    source: "openai",
//                    fontName: fixed.fontName,
//                    emoji: fixed.emoji,
//                    senderId: currentUserId,
//                    senderName: "Current User",
//                    sentAt: fixed.sentAt,
//                    roomId: r.roomId
//                )
//                stompManager.sendMessage(finalToSend)
//            }
//            print("📨 stomp sent? \(fixed.source == "openai")")
//
//        }
//    }
//




    @discardableResult
    func stopRecordingAndSend() -> (id: String, text: String) {
        let trimmed = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "") }

        let tempId = UUID().uuidString
        pendingMessageId = tempId

        let style = emotionStyles["neutral"]
       
        let provisional = ChatMessageModel(
            id: tempId,
            senderId: currentUserId,
            senderName: "Me",
            content: trimmed,
            sentAt: ISO8601DateFormatter().string(from: Date()),
            emotion: "neutral",
            fontName: style?.fontName,
            emoji: style?.emoji,
            source: "client"
        )


        // ⬇️ append → upsert 로 교체
        if let i = uiMessages.firstIndex(where: { $0.id == provisional.id }) {
            uiMessages[i] = provisional
        } else {
            uiMessages.append(provisional)
        }

        return (tempId, trimmed)
    }

       

    // ⬇️ 새 전송 함수
    private func stompSendTextMessage(clientMessageId: String, content: String, sentAt: String) {
        // 서버가 기대하는 필드명에 맞게 조정:
        // 예) SpringBoot DTO가 clientMessageId/content/senderId/sentAt 를 받는 경우
        let payload: [String: Any] = [
            "clientMessageId": clientMessageId, // 🔑 반드시 포함 (UI 병합 키)
            "content": content,
            "senderId": currentUserId,
            "roomId": room.id,                  // 서버에서 필요하면 포함
            "sentAt": sentAt
        ]
        // ChatStompManager에 JSON 전송 유틸이 있다면 그것 사용
        stompManager.sendJSON("/app/chat.send", payload: payload)
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
    private func sendStyleTransform(text: String, clientMessageId: String, style: String? = nil) {
        guard let url = URL(string: "\(AppConfig.baseURLFastApi)/transform") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("text", text)
        appendField("user_id", String(currentUserId))
        appendField("room_id", String(room.id))
        appendField("client_id", clientMessageId)
        if let s = style { appendField("style", s) }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let session = URLSession(configuration: .default)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [/transform] 요청 에러: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("📡 [/transform] 상태코드: \(http.statusCode)")
                if http.statusCode >= 300 {
                    let preview = String(data: data ?? Data(), encoding: .utf8) ?? "<no body>"
                    print("⚠️ 응답 바디: \(preview)")
                }
            }
        }.resume()
    }

    private func sendWithFastAPI(text: String, clientMessageId: String) {
        guard let url = URL(string: "\(AppConfig.baseURLFastApi)/analyze") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept") // ✅ 보강

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // 🔑 필드들
        appendField("text", text)
        appendField("user_id", String(currentUserId))
        appendField("room_id", String(room.id))
        appendField("client_id", clientMessageId)

        // 🎙️ 오디오(있으면 첨부) — 실제 확장자/타입 반영
        if let audioURL = recorder.recordedFileURL,
           let audioData = try? Data(contentsOf: audioURL) {

            let ext = audioURL.pathExtension.lowercased()
            let mime: String
            switch ext {
            case "wav": mime = "audio/wav"
            case "m4a": mime = "audio/m4a"
            case "caf": mime = "audio/x-caf"
            case "aac": mime = "audio/aac"
            case "mp3": mime = "audio/mpeg"
            default:    mime = "application/octet-stream"
            }

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.\(ext.isEmpty ? "wav" : ext)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        } else {
            // 서버가 audio를 필수(File(...))로 받는다면, 여기서 early return 하거나 사용자 알림
            print("⚠️ [FastAPI] audio 파일이 없어 업로드가 실패할 수 있습니다.")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // (선택) 타임아웃 설정
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [FastAPI] 요청 에러: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("📡 [FastAPI] 상태코드: \(http.statusCode)")
                if http.statusCode >= 300 {
                    let preview = String(data: data ?? Data(), encoding: .utf8) ?? "<no body>"
                    print("⚠️ [FastAPI] 응답 바디: \(preview)")
                }
            }
            // ✅ 응답은 "processing"이고, 최종 결과는 Emotion WS로만 옴
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
