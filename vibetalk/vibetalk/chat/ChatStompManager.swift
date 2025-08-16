import Foundation
import StompClientLib
import Starscream

final class ChatStompManager: ObservableObject {
    private var socketClient = StompClientLib()
    @Published var messages: [ChatMessageModel] = []
    @Published var latestMessage: ChatMessageModel? = nil

    private(set) var currentRoomId: Int = 0
    private(set) var currentUserId: Int = 0

    // 최근 이력 불러오기 (REST)
    func fetchRecentMessages(roomId: Int, completion: @escaping ([ChatMessageModel]) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else { completion([]); return }
        func request(_ urlString: String, label: String, then next: (() -> Void)? = nil) {
            guard let url = URL(string: urlString) else { next?(); return }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: req) { data, resp, error in
                if let _ = error { next?(); return }
                guard let data = data else { next?(); return }
                if let http = resp as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
                    next?(); return
                }
                do {
                    let decoded = try JSONDecoder().decode([ChatMessageResponse].self, from: data)
                    let models = decoded.map(ChatMessageModel.init(from:)).reversed()
                    DispatchQueue.main.async { completion(Array(models)) }
                } catch { next?() }
            }.resume()
        }
        let p = "\(AppConfig.baseURLSpringBoot)/api/chat/chatroom/\(roomId)/messages?limit=50"
        let f = "\(AppConfig.baseURLSpringBoot)/api/chat/rooms/\(roomId)/messages?limit=50"
        request(p, label: "primary") { request(f, label: "fallback") { DispatchQueue.main.async { completion([]) } } }
    }

    func connect(roomId: Int, userId: Int) {
        self.currentRoomId = roomId
        self.currentUserId = userId
        guard let token = UserDefaults.standard.string(forKey: "jwtToken"),
              let url = URL(string: "\(AppConfig.webSocketURL)?token=\(token)")
        else { return }

        let request = NSMutableURLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        socketClient.openSocketWithURLRequest(request: request as NSURLRequest, delegate: self)
    }

    func sendJSON(_ destination: String,
                  payload: [String: Any],
                  headers: [String:String] = ["content-type":"application/json"]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else { return }
        socketClient.sendMessage(message: json, toDestination: destination, withHeaders: headers, withReceipt: nil)
    }

    /// 톤 변환이 끝난 최종 텍스트를 서버로 전송
    func sendTextMessage(clientMessageId: String, content: String, sentAt: String) {
        let payload: [String: Any] = [
            "clientMessageId": clientMessageId,   // 병합 키
            "chatRoomId": currentRoomId,
            "senderId": currentUserId,
            "content": content,
            "sentAt": sentAt,
            "source": "client"
        ]
        sendJSON("/app/chat.sendMessage/\(currentRoomId)", payload: payload)
    }

    func disconnectStomp() {
        socketClient.disconnect()
    }
}

extension ChatStompManager: StompClientLibDelegate {
    func stompClientDidConnect(client: StompClientLib!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            client.subscribe(destination: "/topic/room.\(self.currentRoomId)")
        }
    }
    func stompClientDidDisconnect(client: StompClientLib!) {}
    func stompClientError(client: StompClientLib!, didReceiveErrorMessage description: String) {}
    func serverDidSendError(client: StompClientLib!, withErrorMessage description: String, detailedErrorMessage message: String?) {}
    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {}
    func serverDidSendPing() {}

    func stompClient(client: StompClientLib!,
                     didReceiveMessageWithJSONBody jsonBody: AnyObject?,
                     akaStringBody stringBody: String?,
                     withHeader header: [String : String]?,
                     withDestination destination: String) {
        guard let text = stringBody, let data = text.data(using: .utf8) else { return }
        if let newMessage = try? JSONDecoder().decode(ChatMessageModel.self, from: data) {
            DispatchQueue.main.async {
                self.messages.append(newMessage)
                self.latestMessage = newMessage
            }
        }
    }
}
