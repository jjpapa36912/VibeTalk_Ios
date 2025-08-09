//
//  EmotionWebSocketManager.swift
//  vibetalk
//
//  Created by 김동준 on 8/6/25.
//

import Foundation
//
//  EmotionWebSocketManager.swift
//  vibetalk
//
//  Created by 김동준 on 8/6/25.
//
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

    func connect() {
        guard !isConnected else {
            print("ℹ️ [EmotionWS] already connected — skip")
            return
        }

        // http -> ws, https -> wss (네가 쓰던 방식 유지)
        let wsBase = AppConfig.baseURLFastApi.replacingOccurrences(of: "http", with: "ws")
        guard let url = URL(string: "\(wsBase)/ws/emotion") else {
            print("❌ [EmotionWS] URL 생성 실패")
            return
        }
        print("🔌 [EmotionWS] Connect → \(url.absoluteString)")

        // 이전 잔여 상태 정리
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

    // MARK: - Private

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

    private func receiveOnce() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            // 이미 끊긴 뒤면 수신 콜백 무시
            guard self.isConnected else { return }

            switch result {
            case .failure(let error):
                print("❌ [EmotionWS] receive error: \(error.localizedDescription)")
                // 여기서 더 이상 재귀 호출하지 않음 — 끊김 처리 후 재연결 예약
                self.handleDisconnectAndScheduleReconnect()

            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleString(text)
                case .data(let data):
                    print("ℹ️ [EmotionWS] binary ignored (\(data.count) bytes)")
                @unknown default:
                    break
                }
                // 정상 수신 시에만 다음 수신 예약
                self.receiveOnce()
            }
        }
    }

    private func handleString(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let d = try JSONDecoder().decode(DecodableEmotionResult.self, from: data)
            let normalized = normalizeEmotion(d.emotion)
            let style = emotionStyles[normalized] ?? emotionStyles["neutral"]!
            let enriched = EmotionResult(
                id: UUID().uuidString,
                client_text: d.client_text,
                pitch: d.pitch,
                volume: d.volume,
                emotion: normalized,
                confidence: d.confidence,
                source: d.source,         // "hubert" | "openai"
                fontName: style.fontName,
                emoji: style.emoji,
                senderId: nil,
                senderName: "Analyzer",
                sentAt: ISO8601DateFormatter().string(from: Date())
            )
            DispatchQueue.main.async { self.latestEmotionResult = enriched }
        } catch {
            print("❌ [EmotionWS] decode failed: \(error)\nRAW: \(text)")
        }
    }

    private func handleDisconnectAndScheduleReconnect() {
        guard isConnected else { return } // 중복 처리 방지
        isConnected = false
        stopPing()
        webSocketTask?.cancel()
        webSocketTask = nil

        reconnectWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            print("🔁 [EmotionWS] reconnecting...")
            self.connect()
            self.backoff = min(self.backoff * 2, 60)
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + backoff, execute: work)
    }
}

// 서버 라벨 → 앱 내부 라벨 매핑
private func normalizeEmotion(_ raw: String) -> String {
    switch raw.lowercased() {
    case "sadness": return "sad"
    case "joy", "happy": return "joy"
    case "anger", "angry": return "anger"
    case "fear": return "fear"
    case "surprise": return "surprise"
    case "curiosity": return "curiosity"
    default: return raw.lowercased()
    }
}
