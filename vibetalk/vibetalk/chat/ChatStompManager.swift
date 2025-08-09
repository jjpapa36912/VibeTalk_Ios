import Foundation
import StompClientLib
import Starscream

class ChatStompManager: ObservableObject {
    private var socketClient = StompClientLib()
    @Published var messages: [ChatMessageModel] = []
    
    private(set) var currentRoomId: Int = 0
    private(set) var currentUserId: Int = 0
    
    func fetchRecentMessages(roomId: Int, completion: @escaping ([ChatMessageModel]) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ fetchRecentMessages: JWT 없음"); completion([]); return
        }

        func request(_ urlString: String, label: String, then next: (() -> Void)? = nil) {
            guard let url = URL(string: urlString) else { print("❌ URL 실패: \(urlString)"); next?(); return }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            print("🔎 [HTTP] GET(\(label)) \(url.absoluteString)")
            URLSession.shared.dataTask(with: req) { data, resp, error in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if let error = error { print("❌ 네트워크 에러(\(label)): \(error)"); next?(); return }
                print("📡 상태코드(\(label)): \(code)")

                guard let data = data else { print("⚠️ 본문 없음(\(label))"); next?(); return }
                print("📦 바이트(\(label)): \(data.count)")

                if code == 401 || code == 403 {
                    let raw = String(data: data, encoding: .utf8) ?? "<no body>"
                    print("🚫 권한 거부(\(label)) RAW: \(raw)")
                    next?(); return
                }

                do {
                    let decoded = try JSONDecoder().decode([ChatMessageResponse].self, from: data)
                    let models = decoded.map(ChatMessageModel.init(from:)).reversed()
                    DispatchQueue.main.async { completion(Array(models)) }
                } catch {
                    let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                    print("❌ 디코딩 실패(\(label)): \(error)\n🔎 RAW preview: \(preview)")
                    next?()
                }
            }.resume()
        }

        // 1차: 서버가 기대하는 경로(컨트롤러 그대로)
        let primary = "\(AppConfig.baseURLSpringBoot)/api/chat/chatroom/\(roomId)/messages?limit=50"
        // 2차: 혹시 rooms 경로를 쓰고 있다면 폴백
        let fallback = "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/messages?limit=50"

        request(primary, label: "primary") {
            request(fallback, label: "fallback") {
                DispatchQueue.main.async { completion([]) }
            }
        }
    }


    func fetchOlderMessages(roomId: Int, before: String, completion: @escaping ([ChatMessageModel]) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ fetchOlderMessages: JWT 없음")
            completion([]); return
        }

        var comps = URLComponents(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/messages/old")!
        comps.queryItems = [
            URLQueryItem(name: "before", value: before),
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = comps.url else { print("❌ URL 생성 실패"); completion([]); return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("🔎 [HTTP] GET \(url.absoluteString)")
        URLSession.shared.dataTask(with: request) { data, resp, error in
            if let error = error {
                print("❌ 네트워크 에러: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            if let http = resp as? HTTPURLResponse {
                print("📡 상태코드: \(http.statusCode)")
            }
            guard let data = data else {
                print("❌ 응답 데이터 없음")
                DispatchQueue.main.async { completion([]) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode([ChatMessageResponse].self, from: data)
                let models = decoded.map(ChatMessageModel.init(from:))
                DispatchQueue.main.async { completion(models) }
            } catch {
                print("❌ 디코딩 실패: \(error)")
                if let raw = String(data: data, encoding: .utf8) { print("📦 RAW: \(raw)") }
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }


    func fetchChatHistory(roomId: Int) {
            // ✅ 서버에서 과거 메시지 가져오기
            guard let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
            guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/chatroom/\(roomId)/messages") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, _, error in
                guard let data = data, error == nil else { return }
                do {
                    let decoded = try JSONDecoder().decode([ChatMessageModel].self, from: data)
                    DispatchQueue.main.async {
                        self.messages = decoded
                    }
                } catch {
                    print("❌ 메시지 디코딩 실패: \(error)")
                }
            }.resume()
        }
    
    func connect(roomId: Int, userId: Int) {
        self.currentRoomId = roomId
        self.currentUserId = userId

        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ [iOS] JWT 토큰 없음")
            return
        }

        let urlString = "\(AppConfig.webSocketURL)?token=\(token)"
        print("🔌 [iOS] WebSocket 연결 URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ [iOS] URL 생성 실패")
            return
        }

        let request = NSMutableURLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("🛠️ [iOS] WebSocket Authorization 헤더 추가 완료")

        socketClient.openSocketWithURLRequest(
            request: request as NSURLRequest,
            delegate: self
        )

        print("🚀 [iOS] WebSocket 연결 시도")
    }

    func disconnect() {
        socketClient.disconnect()
        print("❌ [iOS] WebSocket 연결 종료")
    }

//    func sendMessage(_ message: String) {
//        let json: [String: Any] = [
//            "chatRoomId": currentRoomId,
//            "senderId": currentUserId,
//            "content": message
//        ]
//        print("📤 [iOS] 메시지 전송: \(json)")
//        socketClient.sendJSONForDict(
//            dict: json as NSDictionary,
//            toDestination: "/app/chat.sendMessage/\(currentRoomId)"
//        )
//    }
    func sendMessage(_ result: EmotionResult) {
        let resolvedFontName = result.fontName ?? emotionStyles[result.emotion]?.fontName ?? "YOnepick-Regular"
        let resolvedEmoji = result.emoji ?? emotionStyles[result.emotion]?.emoji ?? "🙂"

        let json: [String: Any] = [
            "chatRoomId": currentRoomId,
            "senderId": currentUserId,
            "content": result.client_text,
            "emotion": result.emotion,
            "fontName": resolvedFontName,
            "emoji": resolvedEmoji  // ✅ 이모지 추가!
        ]
        
        print("📤 [STOMP] 메시지 전송: \(json)")

        socketClient.sendJSONForDict(
            dict: json as NSDictionary,
            toDestination: "/app/chat.sendMessage/\(currentRoomId)"
        )

        DispatchQueue.main.async {
            self.messages.append(ChatMessageModel(
                id: String(Int.random(in: 100000...999999)),   // ✅ String 변환
                senderId: self.currentUserId,
                senderName: "나",
                content: result.client_text,
                sentAt: ISO8601DateFormatter().string(from: Date()),
                emotion: result.emotion,
                fontName: resolvedFontName,
                emoji: resolvedEmoji  // ✅ 메시지 목록에도 반영
            ))
        }
    }



}

extension ChatStompManager: StompClientLibDelegate {
    func stompClientDidConnect(client: StompClientLib!) {
        print("✅ [iOS] STOMP 연결 성공")

        // CONNECT 프레임 수동 전송 ❌ → 라이브러리가 자동 처리함

        // STOMP 서버가 CONNECTED 응답을 보낸 후 구독
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            client.subscribe(destination: "/topic/room.\(self.currentRoomId)")
            print("📩 [iOS] 채팅방 구독 시작: /topic/room.\(self.currentRoomId)")
        }
    }

//    func stompClientDidConnect(client: StompClientLib!) {
//        print("✅ [iOS] STOMP 연결 성공")
//        
//        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
//        
//        // 🔑 CONNECT 프레임 작성
//        let connectFrame = """
//        CONNECT
//        accept-version:1.2
//        host:localhost
//        Authorization:Bearer \(token)
//
//        \u{0000}
//        """
//        
//        // ✅ WebSocket에 직접 전송
//        if let socket = client.value(forKey: "socket") as? WebSocket {
//            socket.write(string: connectFrame)
//            print("🔑 [iOS] STOMP CONNECT 프레임 전송 완료")
//        }
//    }




    func stompClientDidDisconnect(client: StompClientLib!) {
        print("❌ [iOS] STOMP 연결 해제")
    }

    func stompClientError(client: StompClientLib!, didReceiveErrorMessage description: String) {
        print("⚠️ [iOS] STOMP 클라이언트 에러: \(description)")
    }

    func serverDidSendError(client: StompClientLib!,
                            withErrorMessage description: String,
                            detailedErrorMessage message: String?) {
        print("🚨 [iOS] 서버 에러: \(description) | 세부: \(message ?? "없음")")
    }

    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        print("🧾 [iOS] Receipt ID: \(receiptId)")
    }

    func serverDidSendPing() {
        print("🏓 [iOS] 서버 Ping")
    }

    func stompClient(
            client: StompClientLib!,
            didReceiveMessageWithJSONBody jsonBody: AnyObject?,
            akaStringBody stringBody: String?,
            withHeader header: [String : String]?,
            withDestination destination: String
        ) {
            print("📩 [iOS] 메시지 수신: \(stringBody ?? "")")
            
            if let data = stringBody?.data(using: .utf8) {
                do {
                    let newMessage = try JSONDecoder().decode(ChatMessageModel.self, from: data)
                    DispatchQueue.main.async {
                        self.messages.append(newMessage)
                        print("✅ [iOS] 실시간 메시지 리스트에 추가됨")
                    }
                } catch {
                    print("❌ [iOS] 메시지 디코딩 실패: \(error)")
                }
            }
        }
}
