import Foundation


// MARK: - ViewModel
class ChatRoomListViewModel: ObservableObject {
    @Published var chatRooms: [ChatRoomListItem] = []
    @Published var friends: [FriendResponse] = []   // ✅ 추가


    func fetchChatRooms() {
        print("🚀 [ChatRoomListViewModel] fetchChatRooms() 시작")
        
        guard let url = URL(string: "\(AppConfig.baseURL)/api/chat/rooms") else {
            print("❌ URL 생성 실패")
            return
        }
        guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ JWT 토큰 없음")
            return
        }
        
        print("🌐 요청 URL: \(url)")
        print("🔑 Authorization: Bearer \(token.prefix(10))...") // 토큰 일부만 로그
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 네트워크 요청 실패: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 서버 응답 코드: \(httpResponse.statusCode)")
            } else {
                print("⚠️ HTTPURLResponse 변환 실패")
            }
            
            guard let data = data else {
                print("⚠️ 응답 데이터 없음")
                return
            }
            
            print("📦 응답 데이터 크기: \(data.count) bytes")
            if let rawJson = String(data: data, encoding: .utf8) {
                print("🔎 응답 JSON 미리보기: \(rawJson)")
            }
            
            do {
                let decoded = try JSONDecoder().decode([ChatRoomListItem].self, from: data)
                DispatchQueue.main.async {
                    self.chatRooms = decoded
                    print("✅ 채팅방 목록 디코딩 성공: \(decoded.count)개 방")
                }
            } catch {
                print("❌ JSON 디코딩 오류: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchFriends() {
            guard let url = URL(string: "\(AppConfig.baseURL)/api/friends"),
                  let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data,
                   let decoded = try? JSONDecoder().decode([FriendResponse].self, from: data) {
                    DispatchQueue.main.async {
                        self.friends = decoded
                    }
                }
            }.resume()
        }
}

extension Notification.Name {
    static let chatRoomLeft = Notification.Name("chatRoomLeft")
}
