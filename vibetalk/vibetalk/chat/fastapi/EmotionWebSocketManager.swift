//
//  EmotionWebSocketManager.swift
//  vibetalk
//
//  Created by 김동준 on 8/6/25.
//

import Foundation

final class EmotionWebSocketManager: ObservableObject {
    @Published var latestEmotionResult: EmotionResult?

    private var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 30
        return URLSession(configuration: cfg)
    }()

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectWorkItem: DispatchWorkItem?
    private(set) var isConnected = false
    private var backoff: TimeInterval = 1   // 1,2,4,8.. 최대 60

    // 🔑 재연결용으로 보존
    private var lastUserId: Int?
    private var lastRoomId: Int?

    // MARK: - Connect / Disconnect

    func connect(userId: Int, roomId: Int) {
        guard !isConnected else {
            print("ℹ️ [EmotionWS] already connected — skip")
            return
        }
        lastUserId = userId
        lastRoomId = roomId

        // http -> ws, https -> wss
        let wsBase = AppConfig.baseURLFastApi.replacingOccurrences(of: "http", with: "ws")

        var comps = URLComponents(string: "\(wsBase)/ws/emotion")
        comps?.queryItems = [
            URLQueryItem(name: "user_id", value: String(userId)),
            URLQueryItem(name: "room_id", value: String(roomId))
        ]
        guard let url = comps?.url else {
            print("❌ [EmotionWS] URL 생성 실패")
            return
        }
        print("🔌 [EmotionWS] Connect → \(url.absoluteString)")

        // 잔여 상태 정리
        reconnectWorkItem?.cancel()
        stopPing()
        webSocketTask?.cancel()

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        backoff = 1
        startPing()
        receiveOnce()
    }

    func disconnect() {
        print("⛔️ [EmotionWS] Disconnected (manual)")
        isConnected = false
        stopPing()
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Ping

    private func startPing() {
        stopPing()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self, self.isConnected else { return }
            self.webSocketTask?.sendPing { err in
                if let err = err {
                    print("❌ [EmotionWS] ping 실패: \(err.localizedDescription)")
                    self.handleDisconnectAndScheduleReconnect()
                }
            }
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - Receive

    private func receiveOnce() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            // 이미 끊긴 뒤면 수신 콜백 무시
            guard self.isConnected else { return }

            switch result {
            case .failure(let error):
                print("❌ [EmotionWS] receive error: \(error.localizedDescription)")
                self.handleDisconnectAndScheduleReconnect()

            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleString(text)
                case .data(let data):
                    // 일부 환경에서 binary로 올 수도 있으니 방어적으로 문자열 변환 시도
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleString(text)
                    } else {
                        print("ℹ️ [EmotionWS] binary ignored (\(data.count) bytes)")
                    }
                @unknown default:
                    break
                }
                // 정상 수신 시에만 다음 수신 예약
                self.receiveOnce()
            }
        }
    }

    private func handleString(_ text: String) {
        print("🌐 WS raw: \(text)")

        guard let data = text.data(using: .utf8) else { return }

        // 1) 풀 포맷(EmotionResult) 우선
        if var full = try? JSONDecoder().decode(EmotionResult.self, from: data) {
            let normalized = normalizeEmotion(full.emotion)
            // senderId/roomId가 비어있으면 마지막 연결 정보로 보강
            full = EmotionResult(
                id: full.id,
                client_text: full.client_text,
                pitch: full.pitch,
                volume: full.volume,
                emotion: normalized,
                confidence: full.confidence,
                source: full.source,
                fontName: full.fontName,
                emoji: full.emoji,
                senderId: full.senderId ?? lastUserId,     // 🔥 보강
                senderName: full.senderName,
                sentAt: full.sentAt,
                roomId: full.roomId ?? lastRoomId          // 🔥 보강
            )
            print("✅ WS decode(full) → id=\(full.id), src=\(full.source), sid=\(String(describing: full.senderId)), rid=\(String(describing: full.roomId))")
            DispatchQueue.main.async { self.latestEmotionResult = full }
            return
        }

        // 2) 폴백: 간소 포맷(DecodableEmotionResult) → EmotionResult 변환
        do {
            let d = try JSONDecoder().decode(DecodableEmotionResult.self, from: data)
            let normalized = normalizeEmotion(d.emotion)

            let result = EmotionResult(
                id: UUID().uuidString,               // 서버가 id를 안 보낼 때 임시
                client_text: d.client_text,
                pitch: d.pitch,
                volume: d.volume,
                emotion: normalized,
                confidence: d.confidence,
                source: d.source,                    // "hubert" | "openai"
                fontName: nil,
                emoji: nil,
                senderId: lastUserId,                // 🔥 내가 연결 때 넘긴 userId
                senderName: "Analyzer",
                sentAt: ISO8601DateFormatter().string(from: Date()),
                roomId: lastRoomId                   // 🔥 내가 연결 때 넘긴 roomId
            )
            print("✅ WS decode(fallback) → id=\(result.id), src=\(result.source), sid=\(String(describing: result.senderId)), rid=\(String(describing: result.roomId))")
            DispatchQueue.main.async { self.latestEmotionResult = result }
        } catch {
            print("❌ [EmotionWS] decode failed: \(error)\nRAW: \(text)")
        }
    }


    // MARK: - Reconnect

    private func handleDisconnectAndScheduleReconnect() {
        guard isConnected else { return } // 중복 처리 방지
        isConnected = false
        stopPing()
        webSocketTask?.cancel()
        webSocketTask = nil

        reconnectWorkItem?.cancel()
        let delay = backoff
        backoff = min(backoff * 2, 60)

        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  let uid = self.lastUserId,
                  let rid = self.lastRoomId else { return }
            print("🔁 [EmotionWS] reconnecting...")
            self.connect(userId: uid, roomId: rid)
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

// 서버 라벨 → 앱 내부 라벨 매핑 (emotionStyles 키와 1:1)
private func normalizeEmotion(_ raw: String) -> String {
    switch raw.lowercased() {
    case "joy", "happy": return "joy"
    case "sad", "sadness": return "sadness"   // ← styles에 "sadness" 키 사용
    case "anger", "angry": return "anger"
    case "fear": return "fear"
    case "surprise": return "surprise"
    case "curiosity": return "curiosity"
    default: return "neutral"                 // 알 수 없으면 neutral
    }
}
