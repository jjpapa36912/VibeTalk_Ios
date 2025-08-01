//
//  LoginViewModel.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation
import Combine

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
    func login(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/auth/login") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "네트워크 오류: \(error.localizedDescription)"
                    self.showAlert = true
                    completion(false, nil)
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["token"] as? String else {
                DispatchQueue.main.async {
                    self.alertMessage = "로그인 실패"
                    self.showAlert = true
                    completion(false, nil)
                }
                return
            }
            
            // ✅ 토큰 저장
            UserDefaults.standard.set(token, forKey: "jwtToken")
            
            DispatchQueue.main.async {
                completion(true, token)
            }
        }.resume()
    }

    func login(completion: @escaping (Bool) -> Void) {
        #if DEBUG
        let serverURL = "\(AppConfig.baseURL)/api/auth/login"
        #else
        let serverURL = "\(AppConfig.baseURL)/api/auth/login"
        #endif
        
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
                    completion(false) // ❌ 실패 시 false 반환
                }
            }, receiveValue: { response in
                self.loginResult = "✅ 로그인 성공! 사용자: \(response.name)"
                print("🔑 JWT 토큰: \(response.token)")
                
                // JWT 토큰 저장 (자동 로그인)
                UserDefaults.standard.set(response.token, forKey: "jwtToken")
                
                completion(true) // ✅ 성공 시 true 반환
                NotificationCenter.default.post(name: .didLogin, object: nil)

            })
            .store(in: &cancellables)
    }

    
    func register() {
        #if DEBUG
        let serverURL = "\(AppConfig.baseURL)/api/auth/register"
        #else
        let serverURL = "\(AppConfig.baseURL)/api/auth/register"
        #endif
        
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
    func resetPassword(email: String) {
            #if DEBUG
            let serverURL = "\(AppConfig.baseURL)/api/auth/reset-password"
            #else
            let serverURL = "\(AppConfig.baseURL)/api/auth/reset-password"
            #endif
            
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

