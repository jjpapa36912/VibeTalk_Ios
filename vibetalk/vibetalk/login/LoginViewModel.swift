//
//  LoginViewModel.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation
import Combine
import FirebaseMessaging
import UIKit

struct LoginResponse: Codable {
    let userId: Int
    let email: String
    let name: String
    let token: String
}

struct SignupResponse: Codable {
    let userId: Int
    let email: String
    let name: String
}

struct PasswordResetResponse: Codable {
    let success: Bool
    let message: String
}

final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var loginResult: String = ""
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    // 회원가입용 상태
    @Published var signupName: String = ""
    @Published var signupEmail: String = ""
    @Published var signupPhoneNumber: String = ""
    @Published var signupPassword: String = ""

    private var cancellables = Set<AnyCancellable>()
    
    // ✅ 로그인 함수
    func login(completion: @escaping (Bool) -> Void) {
        let serverURL = "\(AppConfig.baseURL)/api/auth/login"
        guard let url = URL(string: serverURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode) else {
                    throw URLError(.userAuthenticationRequired)
                }
                return output.data
            }
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                if case .failure(_) = result {
                    self.alertMessage = "사용자 정보가 올바르지 않습니다."
                    self.showAlert = true
                    completion(false)
                }
            }, receiveValue: { response in
                self.loginResult = "✅ 로그인 성공! 사용자: \(response.name)"
                print("🔑 JWT 토큰: \(response.token)")
                
                // ✅ JWT 토큰 저장
                UserDefaults.standard.set(response.token, forKey: "jwtToken")
                
                // ✅ FCM 토큰 서버로 전송
                if let fcmToken = Messaging.messaging().fcmToken {
                    print("🔥 [LoginViewModel] 현재 FCM 토큰: \(fcmToken)")
                    (UIApplication.shared.delegate as? AppDelegate)?
                        .updateDeviceTokenToServer(fcmToken)
                } else {
                    print("⚠️ [LoginViewModel] FCM 토큰을 가져올 수 없습니다")
                }
                
                completion(true)
                NotificationCenter.default.post(name: .didLogin, object: nil)
            })
            .store(in: &cancellables)
    }

    // ✅ 회원가입 함수
    func register() {
        let serverURL = "\(AppConfig.baseURL)/api/auth/register"
        guard let url = URL(string: serverURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "name": signupName,
            "email": signupEmail,
            "password": signupPassword,
            "phoneNumber": signupPhoneNumber
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "회원가입 실패: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            guard let data = data else { return }
            
            if let signupResponse = try? JSONDecoder().decode(SignupResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.alertMessage = "회원가입 성공! \(signupResponse.name)"
                    self.showAlert = true
                }
            } else {
                DispatchQueue.main.async {
                    self.alertMessage = "회원가입 응답 파싱 실패"
                    self.showAlert = true
                }
            }
        }.resume()
    }
    
    // ✅ 비밀번호 재설정 함수
    func resetPassword(email: String) {
        let serverURL = "\(AppConfig.baseURL)/api/auth/reset-password"
        guard let url = URL(string: serverURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "비밀번호 재설정 실패: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            guard let data = data else { return }
            
            if let result = try? JSONDecoder().decode(PasswordResetResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.alertMessage = result.message
                    self.showAlert = true
                }
            }
        }.resume()
    }
}
