//
//  ChatRoomViewModel.swift
//  vibetalk
//
//  Created by 김동준 on 8/3/25.
//

import Foundation
import Foundation
import Combine
import StompClientLib



final class ChatRoomViewModel: ObservableObject {
    @Published var messages: [ChatMessageResponse] = []

    private let token: String
    private let roomId: Int
    private let baseURL = AppConfig.baseURLSpringBoot  // ✅ 실제 서버 URL로 변경
    private let wsURL = AppConfig.webSocketURL   // ✅ WebSocket URL로 변경

    private var stompClient = StompClientLib()
    
    init(token: String, roomId: Int) {
        self.token = token
        self.roomId = roomId
    }
    
    // MARK: - 1. 과거 메시지 불러오기
    func fetchChatHistory() {
        guard let url = URL(string: "\(baseURL)/chatroom/\(roomId)/messages") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let decoded = try JSONDecoder().decode([ChatMessageResponse].self, from: data)
                DispatchQueue.main.async {
                    self.messages = decoded
                }
            } catch {
                print("❌ Failed to decode messages: \(error)")
            }
        }.resume()
    }
    
    // MARK: - 2. WebSocket 연결 및 구독
    func connectAndSubscribeWebSocket() {
        guard let url = URL(string: wsURL) else { return }
        stompClient.openSocketWithURLRequest(request: URLRequest(url: url) as NSURLRequest, delegate: self)

        // STOMP 구독
        stompClient.subscribe(destination: "/topic/chatroom/\(roomId)")
    }
    
    // MARK: - 3. 메시지 전송
    func sendMessage(content: String) {
        let destination = "/app/chat.sendMessage"
        let message: [String: Any] = [
            "chatRoomId": roomId,
            "content": content
        ]
        stompClient.sendJSONForDict(dict: message as AnyObject, toDestination: destination)
    }
}

extension ChatRoomViewModel: StompClientLibDelegate {
    func stompClientDidConnect(client: StompClientLib!) {
        print("✅ WebSocket connected")
    }
    
    func stompClientDidDisconnect(client: StompClientLib!) {
        print("❌ WebSocket disconnected")
    }
    
    func stompClientError(client: StompClientLib!, didReceiveErrorMessage description: String) {
        print("⚠️ STOMP Error: \(description)")
    }
    
    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
        print("📩 STOMP Receipt: \(receiptId)")
    }
    
    func serverDidSendError(client: StompClientLib!, withErrorMessage description: String,
                            detailedErrorMessage message: String?) {
        print("🚨 Server Error: \(description), details: \(message ?? "")")
    }
    
    func serverDidSendPing() {
        print("🏓 Ping")
    }
    
    func stompClient(client: StompClientLib!,
                     didReceiveMessageWithJSONBody jsonBody: AnyObject?,
                     akaStringBody stringBody: String?,
                     withHeader header: [String : String]?,
                     withDestination destination: String) {

        if let data = stringBody?.data(using: .utf8),
           let newMessage = try? JSONDecoder().decode(ChatMessageResponse.self, from: data) {
            DispatchQueue.main.async {
                self.messages.append(newMessage)
            }
        }
    }
}
