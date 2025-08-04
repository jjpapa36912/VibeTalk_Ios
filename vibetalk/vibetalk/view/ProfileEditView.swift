import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var statusMessage: String
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isSaving = false
    @State private var isLoading = true

    
    let currentProfile: UserProfile
    
    init(currentProfile: UserProfile) {
        _statusMessage = State(initialValue: currentProfile.statusMessage ?? "")
        self.currentProfile = currentProfile
    }
    
    var body: some View {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("불러오는 중...")
                } else {
                    // ✅ 프로필 이미지
                    Button(action: { showImagePicker = true }) {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle")
                                .resizable()
                                .frame(width: 100, height: 100)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // ✅ 상태 메시지
                    TextField("상태 메시지 입력", text: $statusMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    // ✅ 저장 버튼
                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("저장")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isSaving)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("내 프로필 수정")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onAppear(perform: fetchCurrentProfile) // ✅ 진입 시 최신 데이터 로딩
        }
        
    private func fetchCurrentProfile() {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/me"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else {
            print("❌ URL 또는 JWT 토큰 없음")
            return
        }
        
        print("🌐 [Edit] 프로필 요청 URL:", url)
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("🔑 [Edit] Authorization 헤더:", "Bearer \(token)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [Edit] 네트워크 오류:", error.localizedDescription)
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [Edit] 서버 응답 코드:", httpResponse.statusCode)
            }
            
            guard let data = data else {
                print("⚠️ [Edit] 서버 응답 데이터 없음")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            print("📦 [Edit] 서버 응답 원문:", String(data: data, encoding: .utf8) ?? "디코딩 실패")
            
            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                DispatchQueue.main.async {
                    print("✅ [Edit] 디코딩 성공: \(profile)")
                    self.statusMessage = profile.statusMessage ?? ""
                    
                    if let imageUrl = profile.profileImageUrl,
                       let url = URL(string: "\(AppConfig.baseURLSpringBoot)\(imageUrl)") {
                        print("🖼️ [Edit] 프로필 이미지 URL:", url)
                        
                        URLSession.shared.dataTask(with: url) { data, _, error in
                            if let data = data, let uiImage = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self.selectedImage = uiImage
                                    print("✅ [Edit] 이미지 다운로드 성공")
                                }
                            } else {
                                print("⚠️ [Edit] 이미지 다운로드 실패:", error?.localizedDescription ?? "데이터 없음")
                            }
                        }.resume()
                    } else {
                        print("ℹ️ [Edit] 프로필 이미지 없음")
                    }
                    
                    self.isLoading = false
                }
            } catch {
                print("❌ [Edit] JSON 디코딩 오류:", error.localizedDescription)
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }


    private func saveProfile() {
        guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/me/update"),
              let token = UserDefaults.standard.string(forKey: "jwtToken") else { return }
        
        isSaving = true
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // 상태 메시지 추가
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"statusMessage\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(statusMessage)\r\n".data(using: .utf8)!)
        
        // 이미지 추가
        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        URLSession.shared.uploadTask(with: request, from: body) { responseData, response, error in
            DispatchQueue.main.async {
                isSaving = false
                
                // 🔹 네트워크 에러 출력
                if let error = error {
                    print("❌ 요청 에러:", error.localizedDescription)
                }
                
                // 🔹 HTTP 응답 코드 출력
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 응답 코드:", httpResponse.statusCode)
                    print("📋 응답 헤더:", httpResponse.allHeaderFields)
                }
                
                // 🔹 서버에서 보낸 원본 데이터 출력
                if let data = responseData {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("✅ 서버 응답 데이터:", jsonString)
                    } else {
                        print("⚠️ 서버 응답 데이터(디코딩 실패): \(data)")
                    }
                } else {
                    print("⚠️ 서버로부터 데이터가 없습니다.")
                }
                
                // ✅ 정상 동작 시 메인 화면 갱신
                NotificationCenter.default.post(name: Notification.Name("profileUpdated"), object: nil)
                dismiss()
            }
        }.resume()

    }
}
