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
    private var webSocketTask: URLSessionWebSocketTask?
    @Published var latestEmotionResult: EmotionResult?

    func connect() {
        // 네가 쓰던 방식 유지: http -> ws / https -> wss
        let wsBase = AppConfig.baseURLFastApi.replacingOccurrences(of: "http", with: "ws")
        guard let url = URL(string: "\(wsBase)/ws/emotion") else {
            print("❌ [EmotionWS] URL 생성 실패")
            return
        }
        print("🔌 [EmotionWS] Connect → \(url.absoluteString)")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        print("⛔️ [EmotionWS] Disconnected")
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            defer { self.receiveMessages() } // 계속 수신

            switch result {
            case .failure(let error):
                print("❌ [EmotionWS] receive error: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    print("🌐 [EmotionWS] 수신: \(text)")
                    guard let data = text.data(using: .utf8) else { return }
                    do {
                        // 서버가 보내는 경량 스키마로 먼저 디코드
                        let d = try JSONDecoder().decode(DecodableEmotionResult.self, from: data)

                        // 감정 라벨 정규화 (예: sadness -> sad)
                        let normalized = normalizeEmotion(d.emotion)

                        // 폰트/이모지 보강
                        let style = emotionStyles[normalized] ?? emotionStyles["neutral"]!

                        // 최종 UI 모델로 변환
                        let enriched = EmotionResult(
                            id: UUID().uuidString,
                            client_text: d.client_text,
                            pitch: d.pitch,
                            volume: d.volume,
                            emotion: normalized,
                            confidence: d.confidence,
                            source: d.source,            // "hubert" | "openai"
                            fontName: style.fontName,
                            emoji: style.emoji,
                            senderId: nil,                // 분석 시스템 메시지면 nil
                            senderName: "Analyzer",
                            sentAt: ISO8601DateFormatter().string(from: Date())
                        )

                        DispatchQueue.main.async { self.latestEmotionResult = enriched }
                    } catch {
                        print("❌ [EmotionWS] decode failed: \(error)\nRAW: \(text)")
                    }

                case .data(let data):
                    print("ℹ️ [EmotionWS] binary ignored (\(data.count) bytes)")
                @unknown default:
                    break
                }
            }
        }
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
