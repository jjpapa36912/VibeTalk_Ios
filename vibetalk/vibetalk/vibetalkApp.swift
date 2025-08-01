//
//  vibetalkApp.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//
import SwiftUI

@main
struct vibetalkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isLoggedIn {
                MainTabView()
                    .environmentObject(appState)
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenChatRoom"))) { notification in
                        if let roomId = notification.object as? Int {
                            print("🔔 푸시 클릭 → 채팅방 열기: \(roomId)")
                            appState.selectedTab = 1
                            appState.path.append(ChatRoomResponse(id: roomId, roomName: "알림으로 열림"))
                        }
                    }
            } else {
                ContentView()
                    .environmentObject(appState)
            }
        }
    }
}

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
    static let didLogin = Notification.Name("didLogin")
}
