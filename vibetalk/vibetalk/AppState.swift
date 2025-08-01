import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = UserDefaults.standard.string(forKey: "jwtToken") != nil
    @Published var selectedTab: Int = 0
    @Published var path = NavigationPath()
    
    func loginSuccess(token: String) {
        print("✅ [AppState] 로그인 성공, 토큰 저장")
        UserDefaults.standard.set(token, forKey: "jwtToken")
        isLoggedIn = true
    }
    
    func logout() {
        print("🚪 [AppState] 로그아웃")
        UserDefaults.standard.removeObject(forKey: "jwtToken")
        isLoggedIn = false
        selectedTab = 0
    }
}
