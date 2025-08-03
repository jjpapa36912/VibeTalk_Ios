import Foundation
import Starscream

struct ChatMessageModel: Codable, Identifiable {
    let id: Int
    let senderId: Int
    let senderName: String
    let content: String
    let sentAt: String
}

class ChatWebSocketManager: ObservableObject {
    var socket: WebSocket?
    @Published var messages: [ChatMessageModel] = []
    
    var currentUserId: Int = 0   // ✅ 현재 유저 ID
    
    func connect(roomId: Int, currentUserId: Int) {
        self.currentUserId = currentUserId
        
        // ✅ 방 ID를 쿼리 파라미터로 포함
        
        let baseURL = "\(AppConfig.webSocketURL)/ws/websocket"

        guard let url = URL(string: "\(baseURL)?roomId=\(roomId)") else { return }
        var request = URLRequest(url: url)
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    func sendMessage(_ message: String) {
        let msg = ChatMessageModel(
            id: Int.random(in: 100000...999999), // 로컬에서 임시 ID 생성
            senderId: currentUserId,
            senderName: "나",
            content: message,
            sentAt: ISO8601DateFormatter().string(from: Date())
        )

        // ✅ WebSocket으로 메시지 전송
        if let jsonData = try? JSONEncoder().encode(msg),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
        }

        // ✅ 로컬에 즉시 추가
        DispatchQueue.main.async {
            self.messages.append(msg)
        }
    }

    
    func disconnect() {
        socket?.disconnect()
    }
}

extension ChatWebSocketManager: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(_):
            print("✅ WebSocket 연결됨")
        case .disconnected(let reason, let code):
            print("❌ 연결 해제: \(reason), 코드: \(code)")
        case .text(let text):
            if let data = text.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ChatMessageModel.self, from: data) {
                DispatchQueue.main.async {
                    self.messages.append(decoded)
                }
            }
        case .error(let error):
            print("⚠️ 에러 발생: \(String(describing: error))")
        default:
            break
        }
    }
}
