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

struct ChatRoomView: View {
    @EnvironmentObject var appState: AppState
    let room: ChatRoomResponse
    let currentUserId: Int
    
    @StateObject private var stompManager = ChatStompManager()
    @State private var inputMessage = ""
    @State private var members: [ChatMember] = []
    @StateObject private var recorder = SpeechRecorder()
    @State private var emotionResult: EmotionResult?


    var body: some View {
            VStack {
                // ✅ 참가자 목록
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(members) { member in
                            memberProfileView(for: member)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                Divider()
                
                // ✅ 메시지 목록
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(stompManager.messages) { msg in
                            ChatBubbleView(message: msg, isCurrentUser: msg.senderId == currentUserId)
                        }
                    }
                    .padding(.horizontal)
                }

                // 🎙 마이크 버튼
                Button(action: {
                    if recorder.isRecording {
                        recorder.stopRecording()
                        // 녹음 종료 후 FastAPI 서버로 전송
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
                    // 🎤 녹음 중일 때 실시간으로 텍스트 박스에 표시
                    if recorder.isRecording {
                        self.inputMessage = text
                    }
                }

                // ✅ 메시지 입력창
                HStack {
                    TextField("메시지 입력", text: $inputMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("보내기") {
                        // 텍스트만 보낼 경우
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
            .navigationTitle(room.roomName)
            .onAppear {
                print("🟢 ChatRoomView onAppear → roomId: \(room.id)")
                fetchChatRoomMembers(roomId: room.id)
                stompManager.fetchChatHistory(roomId: room.id)
                stompManager.connect(roomId: room.id, userId: currentUserId)
                markRoomAsRead(roomId: room.id)
            }

            .onDisappear {
                stompManager.disconnect()
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
               let result = try? JSONDecoder().decode(EmotionResult.self, from: data) {
                DispatchQueue.main.async {
                    self.emotionResult = result
                    
                    // ✅ 감정 스타일 + Pitch/Volume 정보 포함
                    let style = emotionStyles[result.emotion] ?? emotionStyles["neutral"]!
                    let pitchInfo = "Pitch: \(Int(result.pitch)) Hz | Volume: \(String(format: "%.2f", result.volume))"
                    let finalMessage = "\(style.emoji) \(result.client_text)\n\(pitchInfo)"

                    // ✅ 서버 STOMP 전송 → DB 저장됨
                    self.stompManager.sendMessage(finalMessage)
                    self.inputMessage = ""
                }
            } else {
                DispatchQueue.main.async {
                    stompManager.sendMessage(self.inputMessage)
                    self.inputMessage = ""
                }
            }
        }.resume()
    }

    // ✅ 읽음 처리
    private func markRoomAsRead(roomId: Int) {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/read"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request).resume()
    }
    private func uploadToServer() {
        guard let audioURL = recorder.recordedFileURL else { return }
        let url = URL(string: "\(AppConfig.baseURLFastApi)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(recorder.recognizedText)\r\n".data(using: .utf8)!)

        let audioData = try! Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let result = try? JSONDecoder().decode(EmotionResult.self, from: data) {
                DispatchQueue.main.async {
                    self.emotionResult = result
                    print("✅ 서버 응답:", result)
                }
            }
        }.resume()
    }
    // ✅ 참가자 불러오기
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
