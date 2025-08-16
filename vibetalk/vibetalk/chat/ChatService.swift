//
//  ChatService.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//

import Foundation

struct CreateChatRoomRequest: Codable {
    let userIds: [Int]
    let creatorId: Int
    let roomName: String
}

//struct ChatRoomResponse: Codable, Identifiable {
//    let id: Int
//    let roomName: String
//}

//
//  ChatService.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//


final class ChatService {
    static let shared = ChatService()

    func createChatRoom(
        memberIds: [Int],
        roomName: String,
        mode: ChatRoomMode,
        completion: @escaping (Result<ChatRoomResponse, Error>) -> Void
    ) {
        let reqId = UUID().uuidString.prefix(8)
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            let err = NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "JWT 없음"])
            print("🟥 [\(reqId)] createRoom: \(err.localizedDescription)")
            completion(.failure(err)); return
        }

        let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 서버 스펙에 따라 "memberIds" vs "userIds" 확인 필요!
        let body: [String: Any] = [
            "memberIds": memberIds,
            "roomName": roomName,
            "mode": mode.rawValue
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("🟦 [\(reqId)] POST \(url.absoluteString)")
        print("     headers: Authorization=Bearer <redacted>")
        print("     body  : \(prettyJSON(body))")

        let started = Date()
        URLSession.shared.dataTask(with: request) { data, response, error in
            let elapsed = String(format: "%.2fs", Date().timeIntervalSince(started))

            if let error = error {
                print("🟥 [\(reqId)] net err (\(elapsed)): \(error.localizedDescription)")
                completion(.failure(error)); return
            }
            guard let http = response as? HTTPURLResponse else {
                let err = NSError(domain: "HTTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "응답 없음"])
                print("🟥 [\(reqId)] \(err.localizedDescription)")
                completion(.failure(err)); return
            }

            let status = http.statusCode
            let text = String(data: data ?? Data(), encoding: .utf8) ?? "<no body>"
            print("🟨 [\(reqId)] status=\(status) (\(elapsed))")
            print("     resp  : \(text)")

            guard (200...299).contains(status), let data = data else {
                let err = NSError(domain: "HTTP", code: status, userInfo: [NSLocalizedDescriptionKey: "방 생성 실패(\(status))"])
                completion(.failure(err)); return
            }

            do {
                let decoded = try JSONDecoder().decode(ChatRoomResponse.self, from: data)
                print("🟩 [\(reqId)] decode OK → roomId=\(decoded.id)")
                completion(.success(decoded))
            } catch {
                print("🟥 [\(reqId)] decode fail: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}

// 보기 좋은 JSON 로그
private func prettyJSON(_ dict: [String: Any]) -> String {
    guard JSONSerialization.isValidJSONObject(dict),
          let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
          let s = String(data: data, encoding: .utf8) else { return "\(dict)" }
    return s.replacingOccurrences(of: "\\/", with: "/")
}
