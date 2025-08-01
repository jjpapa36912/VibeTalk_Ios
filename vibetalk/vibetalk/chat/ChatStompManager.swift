import Foundation
import StompClientLib

class ChatStompManager: ObservableObject {
    private var socketClient = StompClientLib()
    @Published var messages: [ChatMessageModel] = []
    var currentRoomId: Int = 0
    var currentUserId: Int = 0
    
    func connect(roomId: Int, userId: Int) {
        self.currentRoomId = roomId
        self.currentUserId = userId

        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ JWT 토큰 없음")
            return
        }

        #if DEBUG
        let url = NSURL(string: "ws://172.30.1.73:8080/ws/websocket")!  // Mac 로컬 IP
        #else
        let url = NSURL(string: "wss://13.124.208.108/ws/websocket")!  // 배포 서버
        #endif
        let request = NSURLRequest(url: url as URL)

        // ✅ Authorization 헤더 추가
        socketClient.openSocketWithURLRequest(
            request: request,
            delegate: self,
            connectionHeaders: ["Authorization": "Bearer \(token)"]
        )
    }

    
    func disconnect() {
        socketClient.disconnect()
    }
    
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
    
    func stompClientDidConnect(client: StompClientLib!) {
        print("✅ STOMP 연결됨")
        client.subscribe(destination: "/topic/room.\(currentRoomId)")
    }
    
    func stompClientDidDisconnect(client: StompClientLib!) {
        print("❌ STOMP 연결 해제")
    }
    
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
    
    func stompClientJSONBody(
        client: StompClientLib!,
        didReceiveMessageWithJSONBody jsonBody: String?,
        withHeader header: [String : String]?,
        withDestination destination: String
    ) {
        print("📩 String 메시지 수신: \(jsonBody ?? "")")
    }
    
    func serverDidSendError(client: StompClientLib!,
                            withErrorMessage description: String,
                            detailedErrorMessage message: String?) {
        print("🚨 서버 에러: \(description) \(message ?? "")")
        socketClient.disconnect()
    }
    
    func serverDidSendPing() {
        print("🏓 Ping")
    }
    
    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        print("🧾 Receipt: \(receiptId)")
    }
}
