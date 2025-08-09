import Foundation
import Starscream

// MARK: - ChatMessageModel

struct ChatMessageModel: Identifiable, Codable, Equatable {
    /// 서버/클라 모두 처리하기 위해 String으로 통일 (서버가 Int 보내면 디코더에서 String 변환)
    let id: String
    let senderId: Int
    let senderName: String
    let content: String
    let sentAt: String

    // 확장(옵셔널)
    var emotion: String?
    var fontName: String?
    var emoji: String?
    var source: String?

    enum CodingKeys: String, CodingKey {
        case id, senderId, senderName, content, sentAt, emotion, fontName, emoji, source
    }

    // 서버가 id를 Int로 보낼 때도 처리
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let s = try? c.decode(String.self, forKey: .id) {
            self.id = s
        } else if let n = try? c.decode(Int.self, forKey: .id) {
            self.id = String(n)
        } else {
            self.id = UUID().uuidString
        }

        self.senderId   = try c.decode(Int.self,    forKey: .senderId)
        self.senderName = try c.decode(String.self, forKey: .senderName)
        self.content    = try c.decode(String.self, forKey: .content)
        self.sentAt     = try c.decode(String.self, forKey: .sentAt)
        self.emotion    = try? c.decode(String.self, forKey: .emotion)
        self.fontName   = try? c.decode(String.self, forKey: .fontName)
        self.emoji      = try? c.decode(String.self, forKey: .emoji)
        self.source     = try? c.decode(String.self, forKey: .source)
    }

    /// 로컬에서 생성할 때 쓰는 편의 생성자
    init(
        id: String,
        senderId: Int,
        senderName: String,
        content: String,
        sentAt: String,
        emotion: String? = nil,
        fontName: String? = nil,
        emoji: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.sentAt = sentAt
        self.emotion = emotion
        self.fontName = fontName
        self.emoji = emoji
        self.source = source
    }
}

// 서버 DTO -> 뷰 모델 변환 (초기 이력 로딩 등에 사용)
extension ChatMessageModel {
    func withUpdated(content: String,
                         emotion: String?,
                         fontName: String?,
                         emoji: String?,
                         source: String?) -> ChatMessageModel {
            ChatMessageModel(
                id: self.id,                 // 🔒 id 유지 → 같은 셀 재사용
                senderId: self.senderId,
                senderName: self.senderName,
                content: content,
                sentAt: self.sentAt, emotion: emotion ?? self.emotion,
                fontName: fontName ?? self.fontName,
                emoji: emoji ?? self.emoji,
                source: source ?? self.source
            )
        }
    init(from r: ChatMessageResponse) {
        self.id = String(r.id)
        self.senderId = r.senderId
        self.senderName = r.senderName
        self.content = r.content
        self.sentAt = r.sentAt
        self.emotion = r.emotion
        self.fontName = r.fontName
        self.emoji = r.emoji
        self.source = "server"

        // 🔧 응급 보강(선택): 서버가 아직 보내지 않는 경우
        if self.fontName == nil || self.emoji == nil {
            let key = (r.emotion ?? "neutral").lowercased()
            if self.fontName == nil {
                self.fontName = emotionStyles[key]?.fontName ?? "YOnepick-Regular"
            }
            if self.emoji == nil {
                self.emoji = emotionStyles[key]?.emoji ?? "🙂"
            }
        }
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
    func sendMessage(_ result: EmotionResult) {
        // 1) 서버가 기대하는 JSON 페이로드 구성 (서버 DTO에 맞추세요)
        // 기존 STOMP에서 쓰던 포맷과 동일하게 맞춤
        let resolvedFontName = result.fontName ?? "YOnepick-Regular"
        let payload: [String: Any] = [
            "chatRoomId": currentRoomId,
            "senderId": currentUserId,
            "content": result.client_text,
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

        // 2) 로컬 즉시 반영용(에코 오기 전에 프리뷰)
        let msg = ChatMessageModel(
            id: UUID().uuidString, // 로컬 임시 id (서버 echo에서 교체/추가될 수 있음)
            senderId: currentUserId,
            senderName: "나",
            content: result.client_text,
            sentAt: ISO8601DateFormatter().string(from: Date()),
            emotion: result.emotion,
            fontName: resolvedFontName,
            emoji: result.emoji,
            source: "client"
        )

        DispatchQueue.main.async {
            self.messages.append(msg)
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
        case .text(let text):
            guard let data = text.data(using: .utf8) else { return }
            do {
                let decoded = try JSONDecoder().decode(ChatMessageModel.self, from: data)
                let ready = enrichEmotionFields(decoded)     // ✅ 보강

                DispatchQueue.main.async {
                    self.messages.append(decoded)
                }
            } catch {
                // 디코딩 실패 원인 확인
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
    private func enrichEmotionFields(_ m: ChatMessageModel) -> ChatMessageModel {
        var mm = m
        let key = (m.emotion ?? "neutral").lowercased()
        if mm.fontName == nil { mm.fontName = emotionStyles[key]?.fontName ?? "YOnepick-Regular" }
        if mm.emoji == nil    { mm.emoji    = emotionStyles[key]?.emoji    ?? "🙂" }
        return mm
    }
}
