import Foundation


// MARK: - ViewModel
class ChatRoomListViewModel: ObservableObject {
    @Published var chatRooms: [ChatRoomListItem] = []
    @Published var friends: [FriendResponse] = []   // ✅ 추가


    func fetchChatRooms() {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/chat/rooms"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let decoded = try? JSONDecoder().decode([ChatRoomListItem].self, from: data) {
                DispatchQueue.main.async {
                    self.chatRooms = decoded
                }
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
