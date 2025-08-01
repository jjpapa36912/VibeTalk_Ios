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

    // ✅ 프로필 정보 가져오기
    func fetchUserProfile() {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/me"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ URL 또는 JWT 토큰 없음")
            return
        }
        
        print("🌐 [Main] 프로필 요청 URL:", url)
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("🔑 [Main] Authorization 헤더:", "Bearer \(token)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [Main] 네트워크 오류:", error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [Main] 서버 응답 코드:", httpResponse.statusCode)
            }
            
            guard let data = data else {
                print("⚠️ [Main] 서버 응답 데이터 없음")
                return
            }
            
            print("📦 [Main] 서버 응답 원문:", String(data: data, encoding: .utf8) ?? "디코딩 실패")
            
            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                DispatchQueue.main.async {
                    print("✅ [Main] 디코딩 성공: \(profile)")
                    self.userProfile = profile
                    self.userId = profile.id ?? 0
                }
            } catch {
                print("❌ [Main] JSON 디코딩 오류:", error.localizedDescription)
            }
        }.resume()
    }

    // ✅ 연락처 동기화
    func syncContacts() {
        #if targetEnvironment(simulator)
        print("🧑‍💻 시뮬레이터 감지 → 임의 친구 표시")
        self.friends = [
            FriendResponse(id: 1, phoneNumber: "01011112222", appName: "김시뮬", contactName: "시뮬친구", statusMessage: "테스트 중", profileImage: nil),
            FriendResponse(id: 2, phoneNumber: "01033334444", appName: "박테스트", contactName: "테스트친구", statusMessage: "시뮬레이터", profileImage: nil)
        ]
        #else
        ContactService.shared.fetchContacts { contacts in
            guard let url = URL(string: "\(AppConfig.baseURL)/api/friends/sync") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let json = try? JSONSerialization.data(withJSONObject: contacts, options: .prettyPrinted)
            request.httpBody = json

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ 친구 동기화 실패: \(error.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 서버 응답 코드: \(httpResponse.statusCode)")
                }
                guard let data = data else { return }

                do {
                    let decoded = try JSONDecoder().decode([FriendResponse].self, from: data)
                    DispatchQueue.main.async {
                        print("✅ 서버 응답 친구 수: \(decoded.count)")
                        self.friends = decoded
                    }
                } catch {
                    print("❌ JSON 디코딩 오류: \(error)")
                }
            }.resume()
        }
        #endif
    }

    // ✅ 로그아웃 처리
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
