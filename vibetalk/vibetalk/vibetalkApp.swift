//
//  vibetalkApp.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import SwiftUI

@main
struct vibetalkApp: App {
    // ✅ 앱 전체에서 로그인 상태 관리
    @State private var isLoggedIn = UserDefaults.standard.string(forKey: "jwtToken") != nil
    
    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                MainView()
                    .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
                        // 로그아웃 시 로그인 화면으로 전환
                        isLoggedIn = false
                    }
            } else {
                ContentView()
                    .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { _ in
                        // 로그인 성공 시 메인 화면으로 전환
                        isLoggedIn = true
                    }
            }
        }
    }
}

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
    static let didLogin = Notification.Name("didLogin")
}
