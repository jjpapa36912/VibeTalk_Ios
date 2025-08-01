import Foundation
import StompClientLib

class UnreadBadgeViewModel: ObservableObject {
    private var socketClient = StompClientLib()
    @Published var totalUnreadCount: Int = 0
    private var currentUserId: Int = 0
    
    func connectForUnread(userId: Int) {
        self.currentUserId = userId
        
        #if DEBUG
        let url = NSURL(string: "ws://localhost:8080/ws/websocket")! // 로컬 디버그용
        #else
        let url = NSURL(string: "ws://13.124.208.108:8080/ws/websocket")! // 실제 서버 주소
        #endif
        socketClient.openSocketWithURLRequest(
            request: NSURLRequest(url: url as URL),
            delegate: self
        )
    }
    
    func disconnect() {
        socketClient.disconnect()
    }
}

extension UnreadBadgeViewModel: StompClientLibDelegate {
    
    func stompClientDidConnect(client: StompClientLib!) {
        print("✅ STOMP 연결됨 (Unread)")
        
        // ✅ 총 안 읽은 메시지 구독
        socketClient.subscribe(destination: "/topic/unread/total/\(currentUserId)")
    }
    
    func stompClientDidDisconnect(client: StompClientLib!) {
        print("❌ STOMP 연결 해제")
    }
    
    func stompClientError(client: StompClientLib!, didReceiveErrorMessage description: String) {
        print("⚠️ STOMP 에러: \(description)")
    }
    
    /// ✅ JSON Body 메시지 수신
    func stompClient(
        client: StompClientLib!,
        didReceiveMessageWithJSONBody jsonBody: AnyObject?,
        akaStringBody stringBody: String?,
        withHeader header: [String : String]?,
        withDestination destination: String
    ) {
        if let count = jsonBody as? Int {
            DispatchQueue.main.async {
                self.totalUnreadCount = count
            }
        } else if let dict = jsonBody as? [String: Any],
                  let count = dict["count"] as? Int {
            DispatchQueue.main.async {
                self.totalUnreadCount = count
            }
        }
    }
    
    /// ✅ String Body 메시지 수신 (옵션)
    func stompClientJSONBody(
        client: StompClientLib!,
        didReceiveMessageWithJSONBody jsonBody: String?,
        withHeader header: [String : String]?,
        withDestination destination: String
    ) {
        print("📩 문자열 메시지 수신 (Unread): \(jsonBody ?? "")")
        if let jsonBody = jsonBody,
           let data = jsonBody.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let count = dict["count"] as? Int {
            DispatchQueue.main.async {
                self.totalUnreadCount = count
            }
        }
    }
    
    func serverDidSendError(client: StompClientLib!,
                            withErrorMessage description: String,
                            detailedErrorMessage message: String?) {
        print("🚨 서버 에러 (Unread): \(description) \(message ?? "")")
    }
    
    func serverDidSendPing() {
        print("🏓 Ping (Unread)")
    }
    
    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        print("🧾 Receipt (Unread): \(receiptId)")
    }
}
