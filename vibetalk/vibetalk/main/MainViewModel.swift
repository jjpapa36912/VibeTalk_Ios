import Foundation
import UIKit

struct UserProfile: Codable {
    let id: Int?
    let name: String
    let statusMessage: String?
    let profileImageUrl: String?
}

final class MainViewModel: ObservableObject {
    @Published var friends: [FriendResponse] = []
    @Published var userProfile: UserProfile? = nil
    @Published var userId: Int = 0
    @Published var chatRooms: [ChatRoomResponse] = []

    // MARK: - Helpers
    private var authToken: String? {
        UserDefaults.standard.string(forKey: "jwtToken")
    }
    private func authorizedRequest(_ url: URL, method: String = "GET") -> URLRequest? {
        guard let token = authToken else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    // MARK: - 내 프로필 가져오기
    func fetchUserProfile() {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/me"),
              var request = authorizedRequest(url) else {
            print("❌ URL 또는 JWT 토큰 없음")
            return
        }
        // GET 기본값이지만 명시
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { print("❌ [Main] 네트워크 오류:", error.localizedDescription); return }
            if let http = response as? HTTPURLResponse { print("📡 [Main] /api/me 응답:", http.statusCode) }
            guard let data = data else { print("⚠️ [Main] 응답 데이터 없음"); return }

            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                DispatchQueue.main.async {
                    self.userProfile = profile
                    self.userId = profile.id ?? 0
                }
            } catch {
                print("❌ [Main] JSON 디코딩 오류:", error.localizedDescription)
                print("📦 원문:", String(data: data, encoding: .utf8) ?? "N/A")
            }
        }.resume()
    }

    // MARK: - 프로필 업데이트(상태메시지/이미지)
    /// 상태메시지 또는 프로필 이미지를 변경한다. (둘 중 하나만 보내도 OK)
    func updateUserProfile(statusMessage: String?, image: UIImage?, completion: (() -> Void)? = nil) {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/me/update"),
              var request = authorizedRequest(url, method: "POST") else {
            print("❌ URL 또는 JWT 토큰 없음")
            completion?(); return
        }

        // ✅ JWT 토큰 확인 로그
        if let token = request.value(forHTTPHeaderField: "Authorization") {
            print("🔑 [updateUserProfile] Authorization 헤더: \(token.prefix(30))...(길이=\(token.count))")
        } else {
            print("🚨 [updateUserProfile] Authorization 헤더 없음!")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        if let statusMessage = statusMessage {
            appendField(name: "statusMessage", value: statusMessage)
        }

        if let image = image, let data = image.jpegData(compressionQuality: 0.85) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        print("📡 [updateUserProfile] 요청 시작 → \(url.absoluteString)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [updateUserProfile] 실패:", error.localizedDescription)
                DispatchQueue.main.async { completion?() }
                return
            }
            if let http = response as? HTTPURLResponse {
                print("📡 [updateUserProfile] 응답 코드:", http.statusCode)
                if http.statusCode == 403 { print("🚨 [updateUserProfile] 서버에서 403 (인증/권한 실패)") }
            }

            guard let data = data else {
                print("⚠️ [updateUserProfile] 데이터 없음")
                DispatchQueue.main.async { completion?() }
                return
            }

            if let updated = try? JSONDecoder().decode(UserProfile.self, from: data) {
                DispatchQueue.main.async {
                    self.userProfile = updated
                    self.syncContacts()
                    completion?()
                }
            } else {
                print("⚠️ [updateUserProfile] 디코딩 실패. 원문:", String(data: data, encoding: .utf8) ?? "N/A")
                DispatchQueue.main.async { completion?() }
            }
        }.resume()
    }


    // MARK: - 연락처 동기화 (기존 로직 유지)
    func syncContacts() {
        #if targetEnvironment(simulator)
        print("🧑‍💻 시뮬레이터 감지 → 임의 친구 표시")
        DispatchQueue.main.async {
            self.friends = [
                FriendResponse(id: 2, phoneNumber: "01012345678", appName: "테스트유저", contactName: "테스트", statusMessage: "Hello", profileImage: nil)
            ]
        }
        #else
        ContactService.shared.fetchContacts { contacts in
            guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/friends/sync") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // 서버가 인증 필요하면 아래 주석 해제
            if let token = self.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let json = try? JSONSerialization.data(withJSONObject: contacts, options: .prettyPrinted)
            request.httpBody = json

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error { print("❌ 친구 동기화 실패:", error.localizedDescription); return }
                if let http = response as? HTTPURLResponse { print("🌐 /api/friends/sync 응답:", http.statusCode) }
                guard let data = data else { return }
                // ✅ 서버에서 내려온 JSON 원문 디버깅 출력
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📩 Raw JSON Response:\n\(jsonString)")
                    }

                do {
                    let decoded = try JSONDecoder().decode([FriendResponse].self, from: data)
                    // ✅ 디버깅용: 각 친구의 프로필 이미지 URL 확인
                    for friend in decoded {
                        _ = friend.absoluteProfileImageUrl   // 접근해야 내부 print 실행됨
                    }
                    DispatchQueue.main.async {
                        self.friends = decoded
                    }
                } catch {
                    print("❌ JSON 디코딩 오류:", error)
                    print("📦 원문:", String(data: data, encoding: .utf8) ?? "N/A")
                }
            }.resume()
        }
        #endif
    }

    // MARK: - 채팅방 목록
    func fetchChatRooms() {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms"),
              let request = authorizedRequest(url) else { return }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { print("❌ 채팅방 목록 불러오기 실패:", error.localizedDescription); return }
            guard let data = data else { return }
            do {
                let decoded = try JSONDecoder().decode([ChatRoomResponse].self, from: data)
                DispatchQueue.main.async { self.chatRooms = decoded }
            } catch {
                print("❌ 디코딩 오류:", error.localizedDescription)
            }
        }.resume()
    }

    // MARK: - 로그아웃
    func logout() {
        UserDefaults.standard.removeObject(forKey: "jwtToken")
        DispatchQueue.main.async {
            self.userProfile = nil
            self.userId = 0
            self.friends = []
        }
        print("🚪 로그아웃 완료")
    }
}
