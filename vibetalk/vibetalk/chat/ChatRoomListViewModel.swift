import Foundation


// MARK: - ViewModel
class ChatRoomListViewModel: ObservableObject {
    @Published var chatRooms: [ChatRoomResponse] = []
    @Published var friends: [FriendResponse] = []   // ✅ 추가

       func fetchChatRooms() {
           guard let token = UserDefaults.standard.string(forKey: "jwtToken") else {
               print("❌ 토큰 없음"); return
           }
           guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/chat/rooms") else { return }

           var req = URLRequest(url: url)
           req.httpMethod = "GET"
           req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
           req.setValue("application/json", forHTTPHeaderField: "Accept")

           URLSession.shared.dataTask(with: req) { data, resp, err in
               if let err = err {
                   print("❌ 네트워크 오류: \(err.localizedDescription)")
                   return
               }
               guard let data = data else { print("⚠️ 데이터 없음"); return }

               // 디버그 프리뷰
               if let raw = String(data: data, encoding: .utf8) {
                   print("🔎 응답 JSON 미리보기:", raw)
               }

               do {
                   let decoded = try JSONDecoder().decode([ChatRoomResponse].self, from: data)
                   DispatchQueue.main.async { self.chatRooms = decoded }
                   print("✅ 채팅방 목록 디코딩 성공: \(decoded.count)개 방")
               } catch {
                   print("❌ JSON 디코딩 오류:", error.localizedDescription)
               }
           }.resume()
       }
    func fetchFriends() {
            guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/friends"),
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
