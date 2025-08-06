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

import Foundation

class EmotionWebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    @Published var latestEmotionResult: EmotionResult?

    func connect() {
        guard let url = URL(string: "\(AppConfig.baseURLFastApi.replacingOccurrences(of: "http", with: "ws"))/ws/emotion") else { return }
        webSocketTask = URLSession(configuration: .default).webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(EmotionResult.self, from: data) {
                    DispatchQueue.main.async {
                        self?.latestEmotionResult = decoded
                    }
                }
            case .failure(let error):
                print("WebSocket Error:", error)
            }
            self?.receiveMessages()
        }
    }
}
