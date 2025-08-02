import Foundation
import StompClientLib
import Starscream

class ChatStompManager: ObservableObject {
    private var socketClient = StompClientLib()
    @Published var messages: [ChatMessageModel] = []
    
    private(set) var currentRoomId: Int = 0
    private(set) var currentUserId: Int = 0
    
    // ✅ STOMP 연결
    func connect(roomId: Int, userId: Int) {
        print("❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌ ")
        self.currentRoomId = roomId
        self.currentUserId = userId

        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ JWT 토큰 없음")
            return
        }

        #if DEBUG
        let urlString = "ws://192.0.0.2:8080/ws/websocket?token=\(token)"
        #else
        let urlString = "wss://13.124.208.108/ws/websocket?token=\(token)"
        #endif

        let url = NSURL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        let request = NSURLRequest(url: url as URL)

        socketClient.openSocketWithURLRequest(
            request: request,
            delegate: self
        )

        print("🔌 [ChatStompManager] WebSocket 연결 시도 → URL 파라미터에 JWT 추가")
    }





    // ✅ 연결 해제
    func disconnect() {
        socketClient.disconnect()
        print("❌ [ChatStompManager] 연결 종료")
    }
    
    // ✅ 메시지 전송
    func sendMessage(_ message: String) {
        let json: [String: Any] = [
            "senderId": currentUserId,
            "senderName": "나",
            "message": message
        ]
        socketClient.sendJSONForDict(
            dict: json as NSDictionary,
            toDestination: "/app/chat.sendMessage/\(currentRoomId)"
        )
        
        DispatchQueue.main.async {
            self.messages.append(ChatMessageModel(
                senderId: self.currentUserId,
                senderName: "나",
                message: message
            ))
        }
    }
}

extension ChatStompManager: StompClientLibDelegate {
    
    // ✅ WebSocket 연결 완료
    func stompClientDidConnect(client: StompClientLib!) {
        print("✅ STOMP 연결됨")

        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ JWT 토큰 없음")
            return
        }

        // 🔑 CONNECT 프레임을 수동으로 작성
        let connectFrame = """
        CONNECT
        accept-version:1.2
        host:localhost
        Authorization:Bearer \(token)

        \u{0000}
        """

        // WebSocket 레벨에서 직접 프레임 전송
        if let socket = client.value(forKey: "socket") as? WebSocket {
            socket.write(string: connectFrame)
            print("🔑 STOMP CONNECT 프레임 헤더 전송 완료")
        }

        // ✅ 방 구독
        client.subscribe(destination: "/topic/room.\(currentRoomId)")
    }


//    func stompClientDidConnect(client: StompClientLib!) {
//        print("✅ STOMP 연결 성공")
//
//        // ✅ 방 구독
//        client.subscribe(destination: "/topic/room.\(currentRoomId)")
//    }
    // ✅ 연결 종료
    func stompClientDidDisconnect(client: StompClientLib!) {
        print("❌ [ChatStompManager] STOMP 연결 해제")
    }
    
    // ✅ 메시지 수신 (JSON)
    func stompClient(
        client: StompClientLib!,
        didReceiveMessageWithJSONBody jsonBody: AnyObject?,
        akaStringBody stringBody: String?,
        withHeader header: [String : String]?,
        withDestination destination: String
    ) {
        print("📩 JSON 메시지 수신: \(String(describing: jsonBody))")
        if let dict = jsonBody as? [String: Any],
           let senderId = dict["senderId"] as? Int,
           let senderName = dict["senderName"] as? String,
           let message = dict["message"] as? String {
            DispatchQueue.main.async {
                self.messages.append(ChatMessageModel(
                    senderId: senderId,
                    senderName: senderName,
                    message: message
                ))
            }
        }
    }
    
    // ✅ 메시지 수신 (String)
    func stompClientJSONBody(
        client: StompClientLib!,
        didReceiveMessageWithJSONBody jsonBody: String?,
        withHeader header: [String : String]?,
        withDestination destination: String
    ) {
        print("📩 String 메시지 수신: \(jsonBody ?? "")")
    }
    
    // ✅ 서버 에러 수신
    func serverDidSendError(client: StompClientLib!,
                            withErrorMessage description: String,
                            detailedErrorMessage message: String?) {
        print("🚨 서버 에러: \(description) \(message ?? "")")
        socketClient.disconnect()
    }
    
    // ✅ Ping 응답
    func serverDidSendPing() {
        print("🏓 Ping")
    }
    
    // ✅ Receipt 처리
    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        print("🧾 Receipt: \(receiptId)")
    }
}
