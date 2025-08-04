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

        // ✅ FCM Delegate 설정
        Messaging.messaging().delegate = self

        // ✅ 원격 알림 등록
        UIApplication.shared.registerForRemoteNotifications()

        return true
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ [AppDelegate] 알림 권한 요청 실패: \(error.localizedDescription)")
            } else {
                print("🔔 [AppDelegate] 푸시 권한 허용: \(granted)")
            }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 [AppDelegate] APNs 토큰: \(token)")
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [AppDelegate] 원격 알림 등록 실패: \(error.localizedDescription)")
    }

    // ✅ FCM 토큰 갱신 시 호출
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 발급받은 FCM 토큰:", fcmToken ?? "")
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcmToken")
            updateDeviceTokenToServer(token)
        }
    }

    func updateDeviceTokenToServer(_ fcmToken: String) {
        guard let jwtToken = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("⚠️ [AppDelegate] JWT 토큰 없음 → 로그인 후 재시도 필요")
            return
        }
        
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/device-token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["deviceToken": fcmToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FCM 토큰 업데이트 실패:", error.localizedDescription)
                return
            }
            print("✅ FCM 토큰 서버 전송 성공")
        }.resume()
    }

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
