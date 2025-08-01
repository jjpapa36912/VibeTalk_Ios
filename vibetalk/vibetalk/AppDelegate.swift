//
//  AppDelegate.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//

import UIKit
import Firebase
import UserNotifications
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 [AppDelegate] 앱 시작")

        // ✅ Firebase 초기화
        FirebaseApp.configure()

        // ✅ 알림 권한 요청
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()

        // ✅ FCM 토큰 delegate 설정
        Messaging.messaging().delegate = self

        // ✅ 원격 알림 등록
        UIApplication.shared.registerForRemoteNotifications()

        return true
    }

    /// ✅ 알림 권한 요청
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ [AppDelegate] 알림 권한 요청 실패: \(error.localizedDescription)")
            } else {
                print("🔔 [AppDelegate] 푸시 권한 허용: \(granted)")
            }
        }
    }

    /// ✅ APNs 토큰 등록 완료
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 [AppDelegate] APNs 토큰: \(token)")

        // ✅ FCM에 APNs 토큰 설정
        Messaging.messaging().apnsToken = deviceToken
    }

    /// ✅ 원격 알림 등록 실패
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [AppDelegate] 원격 알림 등록 실패: \(error.localizedDescription)")
    }

    /// ✅ FCM 토큰 수신
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("🔑 [AppDelegate] FCM 토큰 수신: \(fcmToken)")

        // UserDefaults에 저장 후 서버로 전송
        UserDefaults.standard.set(fcmToken, forKey: "deviceToken")
        sendDeviceTokenToServer(token: fcmToken)
    }

    /// ✅ 서버에 토큰 전송
    private func sendDeviceTokenToServer(token: String) {
        guard let jwtToken = UserDefaults.standard.string(forKey: "jwtToken"),
              let url = URL(string: "\(AppConfig.baseURL)/api/device-token") else {
            print("⚠️ [AppDelegate] 서버 전송 실패: JWT 토큰 없음")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["deviceToken": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("❌ [AppDelegate] 서버 전송 실패: \(error.localizedDescription)")
                return
            }
            print("✅ [AppDelegate] 서버에 FCM 토큰 전송 완료")
        }.resume()
    }

    /// ✅ 푸시 알림 클릭 시 동작
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let roomId = userInfo["roomId"] as? String,
           let intRoomId = Int(roomId) {
            print("🔔 [AppDelegate] 알림 클릭 → 채팅방 진입: \(intRoomId)")
            NotificationCenter.default.post(name: Notification.Name("OpenChatRoom"), object: intRoomId)
        }
        completionHandler()
    }
}
