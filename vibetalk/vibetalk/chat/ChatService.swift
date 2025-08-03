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

class ChatService {
    static let shared = ChatService()

//    func createChatRoom(userIds: [Int], creatorId: Int, roomName: String,
//                        completion: @escaping (Result<ChatRoomResponse, Error>) -> Void) {
//
//        guard let url = URL(string: "\(AppConfig.baseURL)/api/chat/rooms"),
//              let token = UserDefaults.standard.string(forKey: "jwtToken") else {
//            print("❌ [ChatService] URL 또는 토큰 없음")
//            return
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//
//        let body: [String: Any] = [
//            "userIds": userIds,
//            "creatorId": creatorId,
//            "roomName": roomName
//        ]
//
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
//            print("📤 [ChatService] Request Body: \(body)")
//        } catch {
//            print("❌ [ChatService] JSON 직렬화 실패: \(error)")
//            return
//        }
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("❌ [ChatService] 네트워크 오류: \(error)")
//                completion(.failure(error))
//                return
//            }
//
//            if let httpResponse = response as? HTTPURLResponse {
//                print("📡 [ChatService] 서버 응답 코드: \(httpResponse.statusCode)")
//            }
//
//            guard let data = data else {
//                print("❌ [ChatService] 응답 데이터 없음")
//                completion(.failure(NSError(domain: "", code: -1)))
//                return
//            }
//
//            print("📦 [ChatService] 서버 응답 원문: \(String(data: data, encoding: .utf8) ?? "데이터 없음")")
//
//            do {
//                let decoded = try JSONDecoder().decode(ChatRoomResponse.self, from: data)
//                print("✅ [ChatService] 디코딩 성공: \(decoded)")
//                completion(.success(decoded))
//            } catch {
//                print("❌ [ChatService] 디코딩 실패: \(error)")
//                completion(.failure(error))
//            }
//        }.resume()
//    }
    func createChatRoom(memberIds: [Int], roomName: String, completion: @escaping (Result<ChatRoomResponse, Error>) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        var request = URLRequest(url: URL(string: "\(AppConfig.baseURL)/api/chat/rooms")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "memberIds": memberIds,
            "roomName": roomName
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            do {
                let decoded = try JSONDecoder().decode(ChatRoomResponse.self, from: data)
                completion(.success(decoded))  // ✅ 올바르게 Result로 리턴
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

}
