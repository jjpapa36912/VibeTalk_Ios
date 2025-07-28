//
//  MainViewModel.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation

import Foundation
import UIKit

final class MainViewModel: ObservableObject {
    @Published var friends: [FriendResponse] = []

    func syncContacts() {
        #if targetEnvironment(simulator)
        // ✅ 시뮬레이터에서 테스트용 친구 생성
        print("🧑‍💻 시뮬레이터 감지 → 임의의 친구 리스트 표시")
        self.friends = [
            FriendResponse(id: 1, phoneNumber: "01011112222", appName: "김시뮬", contactName: "시뮬친구", statusMessage: "테스트 중", profileImage: nil),
            FriendResponse(id: 2, phoneNumber: "01033334444", appName: "박테스트", contactName: "테스트친구", statusMessage: "시뮬레이터", profileImage: nil)
        ]
        #else
        // ✅ 실제 기기 → 연락처 접근
        let contacts = ContactService.shared.fetchContacts()
        
        // 일부 연락처만 프린트
        let preview = contacts.prefix(5)
        print("📱 연락처 일부 (5개): \(preview)")
        
        guard let url = URL(string: "\(AppConfig.baseURL)/friends/sync") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: contacts)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 친구 동기화 실패: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            
            if let decoded = try? JSONDecoder().decode([FriendResponse].self, from: data) {
                DispatchQueue.main.async {
                    self.friends = decoded
                }
            }
        }.resume()
        #endif
    }
}
