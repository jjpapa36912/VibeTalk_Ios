import Foundation
import Starscream

// MARK: - ChatMessageModel

struct ChatMessageModel: Identifiable, Codable, Equatable {
    /// 서버/클라 호환을 위해 String id (clientMessageId 우선)
    let id: String
    let senderId: Int
    let senderName: String
    let content: String
    let sentAt: String
    var source: String? // "client" | "server" | "style" 등

    enum CodingKeys: String, CodingKey {
        case id, senderId, senderName, content, sentAt, source
    }

    // 서버가 id를 Int로 보낼 가능성 대비
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            self.id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            self.id = String(i)
        } else {
            self.id = UUID().uuidString
        }
        self.senderId = try c.decode(Int.self, forKey: .senderId)
        self.senderName = try c.decode(String.self, forKey: .senderName)
        self.content = try c.decode(String.self, forKey: .content)
        self.sentAt = try c.decode(String.self, forKey: .sentAt)
        self.source = try? c.decode(String.self, forKey: .source)
    }

    init(id: String, senderId: Int, senderName: String, content: String, sentAt: String, source: String? = nil) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.sentAt = sentAt
        self.source = source
    }

    func withUpdated(content: String? = nil, source: String? = nil) -> ChatMessageModel {
        ChatMessageModel(
            id: self.id,
            senderId: self.senderId,
            senderName: self.senderName,
            content: content ?? self.content,
            sentAt: self.sentAt,
            source: source ?? self.source
        )
    }
}
// 서버 DTO -> 뷰 모델 변환 (초기 이력 로딩 등에 사용)
extension ChatMessageModel {
    init(from r: ChatMessageResponse) {
        self.id = r.clientMessageId?.isEmpty == false ? r.clientMessageId! : String(r.id)
        self.senderId = r.senderId
        self.senderName = r.senderName
        self.content = r.content
        self.sentAt = r.sentAt
        self.source = r.source ?? "server"
    }
}

// MARK: - ChatWebSocketManager (Starscream)

final class ChatWebSocketManager: ObservableObject {
    private(set) var socket: WebSocket?
    @Published var messages: [ChatMessageModel] = []

    private(set) var currentUserId: Int = 0
    private(set) var currentRoomId: Int = 0

    func connect(roomId: Int, currentUserId: Int) {
        self.currentRoomId = roomId
        self.currentUserId = currentUserId

        // 서버 구현에 맞춰 URL 구성
        // 예: AppConfig.webSocketURL = "wss://.../ws/websocket"
        let baseURL = "\(AppConfig.webSocketURL)/ws/websocket"
        guard let url = URL(string: "\(baseURL)?roomId=\(roomId)") else {
            print("❌ WebSocket URL 생성 실패")
            return
        }

        var request = URLRequest(url: url)
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
    }

    /// 허버트/오픈AI 결과를 이용해 최종 "채팅 메시지"를 서버로 전송
    // ChatWebSocketManager.sendMessage(_:)
    func sendMessage(_ result: EmotionResult) {
        let resolvedFontName = result.fontName ?? "YOnepick-Regular"

        // ✅ 서버가 받는 페이로드에 clientMessageId + sentAt 포함
        let payload: [String: Any] = [
            "chatRoomId": currentRoomId,
            "senderId": currentUserId,
            "content": result.client_text,
            "clientMessageId": result.id,     // 🔑 중요
            "sentAt": result.sentAt,          // "2025-08-09T22:22:51Z" 등
            "emotion": result.emotion,
            "fontName": resolvedFontName,
            "emoji": result.emoji ?? "🙂"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            socket?.write(string: jsonString)
        } else {
            print("❌ WebSocket payload 직렬화 실패")
        }

        // ✅ 프리뷰도 같은 id 사용 (result.id)
        let msg = ChatMessageModel(
            id: result.id,
            senderId: currentUserId,
            senderName: "나",
            content: result.client_text,
            sentAt: result.sentAt,
            source: "client"
        )



        DispatchQueue.main.async {
            self.upsertIncoming(msg)          // 아래 3)에서 추가
        }
    }

}

// MARK: - Starscream Delegate

extension ChatWebSocketManager: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(_):
            print("✅ WebSocket 연결됨")
        case .disconnected(let reason, let code):
            print("❌ WebSocket 해제: \(reason), 코드: \(code)")
            // Starscream delegate
            case .text(let text):
                guard let data = text.data(using: .utf8) else { return }
                do {
                    var decoded = try JSONDecoder().decode(ChatMessageModel.self, from: data)

                    
                } catch {
                    let preview = String(text.prefix(200))
                    print("❌ 메시지 디코딩 실패: \(error)\nRAW preview: \(preview)")
                }

        case .binary(let data):
            print("ℹ️ WebSocket binary 수신(\(data.count) bytes) – 무시")
        case .error(let error):
            print("⚠️ WebSocket 에러: \(String(describing: error))")
        default:
            break
        }
    }
    
    // ChatWebSocketManager 내부
    private func upsertIncoming(_ m: ChatMessageModel) {
        if let i = messages.firstIndex(where: { $0.id == m.id }) {
            messages[i] = m        // 같은 clientMessageId면 덮어쓰기
        } else {
            messages.append(m)
        }
    }

}
