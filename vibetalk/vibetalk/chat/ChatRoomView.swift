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





import SwiftUI
import SwiftUI

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
            .onChange(of: wsManager.latestEmotionResult?.id) { _ in handleIncomingEmotionResult() }
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
                        ForEach(messages, id: \ .id) { msg in
                            emotionMessageView(for: msg)
                                    .id(msg.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
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
                    let newMessage = EmotionResult(
                        client_text: inputMessage,
                        pitch: 0,
                        volume: 0,
                        emotion: "neutral",
                        confidence: 0.5,
                        source: "manual",
                        fontName: nil
                    )
                    messages.append(newMessage)
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
        let text = msg.source == "openai"
            ? "\(style.emoji) \(msg.client_text)"
            : msg.client_text

        Text(text)
            .font(style.font)  // 🎯 감정 기반 커스텀 폰트 적용
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
            fetchChatRoomMembers(roomId: room.id)

            stompManager.fetchRecentMessages(roomId: room.id) { msgs in
                DispatchQueue.main.async {
                    self.messages = msgs.map {
                        EmotionResult(
                            client_text: $0.content,
                            pitch: 0,
                            volume: 0,
                            emotion: "neutral",
                            confidence: 0.5,
                            source: "hubert",
                            fontName: nil
                        )
                    }
                }
            }

            stompManager.connect(roomId: room.id, userId: currentUserId)
            markRoomAsRead(roomId: room.id)
            wsManager.connect()
        }

        private func onDisappearActions() {
            stompManager.disconnect()
            wsManager.disconnect()
        }

        private func handleIncomingEmotionResult() {
            guard let newResult = wsManager.latestEmotionResult else { return }

            if let index = messages.firstIndex(where: { $0.client_text == newResult.client_text }) {
                messages[index] = newResult
            } else {
                messages.append(newResult)
            }

            if newResult.source == "openai" {
                let style = emotionStyles[newResult.emotion] ?? emotionStyles["neutral"]!
                let finalMessage = "\(style.emoji) \(newResult.client_text)"
                stompManager.sendMessage(finalMessage)
            }

            self.inputMessage = ""
        }

//    var body: some View {
//        VStack {
//            // 참가자 목록
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 12) {
//                    ForEach(members) { member in
//                        memberProfileView(for: member)
//                    }
//                }
//                .padding(.horizontal)
//                .padding(.top, 8)
//            }
//
//            Divider()
//
//            // 메시지 목록
//            ScrollViewReader { proxy in
//                ScrollView {
//                    LazyVStack(spacing: 10) {
//                        ForEach(messages) { msg in
//                            let style = emotionStyles[msg.emotion] ?? emotionStyles["neutral"]!
//
//                            Text(msg.source == "openai"
//                                 ? "\(emotionStyles[msg.emotion]?.emoji ?? "🙂") \(msg.client_text)"
//                                 : msg.client_text)
//                                .padding()
//                                .font(style.font)
//                                .background(msg.source == "hubert" ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
//                                .cornerRadius(8)
//                                .id(msg.id)
//                        }
//                    }
//                    .padding(.horizontal)
//                }
//                .onChange(of: messages.count) { _ in
//                    if let lastMessage = messages.last {
//                        withAnimation {
//                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
//                        }
//                    }
//                }
//            }
//
//            // 마이크 버튼
//            Button(action: {
//                if recorder.isRecording {
//                    recorder.stopRecording()
//                    
//                    sendWithFastAPI()
//                } else {
//                    recorder.startRecording()
//                }
//            }) {
//                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
//                    .font(.system(size: 30))
//                    .foregroundColor(recorder.isRecording ? .red : .blue)
//            }
//            .onReceive(recorder.$recognizedText) { text in
//                if recorder.isRecording {
//                    self.inputMessage = text
//                }
//            }
//
//            // 메시지 입력창
//            HStack {
//                TextField("메시지 입력", text: $inputMessage)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .focused($isInputFocused) // 🔑 포커스 연결
//
//                Button("보내기") {
//                    let newMessage = EmotionResult(
//                           client_text: inputMessage,
//                           pitch: 0,
//                           volume: 0,
//                           emotion: "neutral",
//                           confidence: 0.5,
//                           source: "manual"
//                       )
//                       
//                       messages.append(newMessage) // ✅ 바로 UI에 반영됨
//                       stompSendTextMessage()
//                       inputMessage = "" // ✅ 입력창 초기화
//                    isInputFocused = false  // ✅ 키보드 내리기
//
////                    messages.append($inputMessage)
//                }
//            }
//            .padding()
//        }
//        .onTapGesture {
//                    isInputFocused = false  // ✅ 바깥 탭 시 키보드 숨기기
//                }
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button("채팅목록") {
//                    appState.path.removeLast(appState.path.count)
//                }
//            }
//        }
//        .navigationTitle(room.roomName)
//        .onAppear {
//            fetchChatRoomMembers(roomId: room.id)
//
//            stompManager.fetchRecentMessages(roomId: room.id) { msgs in
//                DispatchQueue.main.async {
//                    self.messages = msgs.map {
//                        EmotionResult(
//                            client_text: $0.content,
//                            pitch: 0,
//                            volume: 0,
//                            emotion: "neutral",
//                            confidence: 0.5,
//                            source: "hubert"
//                        )
//                    }
//                }
//            }
//            
//            stompManager.connect(roomId: room.id, userId: currentUserId)
//            markRoomAsRead(roomId: room.id)
//            wsManager.connect()
//        }
//        .onDisappear {
//            stompManager.disconnect()
//            wsManager.disconnect()
//        }
//        // OpenAI 결과로 기존 Hubert 메시지 업데이트
//        .onChange(of: wsManager.latestEmotionResult?.id) { _ in
//            guard let newResult = wsManager.latestEmotionResult else { return }
//            if let index = messages.firstIndex(where: { $0.client_text == newResult.client_text }) {
//                messages[index] = newResult
//            } else {
//                messages.append(newResult)
//            }
//            
//            // ✅ OpenAI 최종 결과일 때만 STOMP 전송 → DB 저장
//            if newResult.source == "openai" {
//                let style = emotionStyles[newResult.emotion] ?? emotionStyles["neutral"]!
//                let pitchInfo = "Pitch: \(Int(newResult.pitch)) Hz | Volume: \(String(format: "%.2f", newResult.volume))"
//                let finalMessage = "\(style.emoji) \(newResult.client_text)"//\n\(pitchInfo)"
//                stompManager.sendMessage(finalMessage)
//            }
//            self.inputMessage = ""
//
//            
//        }
//                
//    }

    private func stompSendTextMessage() {
        if !inputMessage.isEmpty {
            stompManager.sendMessage(inputMessage)
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
            stompManager.sendMessage(inputMessage)
            inputMessage = ""
            return
        }

        let url = URL(string: "\(AppConfig.baseURLFastApi)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(inputMessage)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(currentUserId)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"room_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(room.id)\r\n".data(using: .utf8)!)

        let audioData = try! Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let hubertResult = try? JSONDecoder().decode(EmotionResult.self, from: data) {
                DispatchQueue.main.async {
                    // Hubert 메시지를 먼저 append
                    self.messages.append(EmotionResult(
                        client_text: hubertResult.client_text,
                        pitch: hubertResult.pitch,
                        volume: hubertResult.volume,
                        emotion: hubertResult.emotion,
                        confidence: hubertResult.confidence,
                        source: "hubert",
                        fontName: nil
                    ))
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
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/members"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, _, error in
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
