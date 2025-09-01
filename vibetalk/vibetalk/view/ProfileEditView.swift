import SwiftUI

import SafariServices   // ← 추가

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState        // ✅ 추가
    @State private var showPolicyWeb = false       // Safari로 정책 페이지 열기
    @State private var showPolicyDetail = false    // 인앱 상세 고지(목적/항목/보관 등)


    @State private var statusMessage: String
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isSaving = false
    @State private var isLoading = true
    @StateObject private var banner = BannerAdController()

    // 🔻 추가: 계정 삭제 UI 상태
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    @ObservedObject var viewModel: MainViewModel

    let currentProfile: UserProfile

    init(currentProfile: UserProfile, viewModel: MainViewModel) {
        _statusMessage = State(initialValue: currentProfile.statusMessage ?? "")
        self.currentProfile = currentProfile
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("불러오는 중...")
            } else {
                // 대체: 고정 아이콘만 표시
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                // ✅ 프로필 이미지
//                Button(action: { showImagePicker = true }) {
//                    if let selectedImage = selectedImage {
//                        Image(uiImage: selectedImage)
//                            .resizable()
//                            .frame(width: 100, height: 100)
//                            .clipShape(Circle())
//                    } else {
//                        Image(systemName: "person.circle")
//                            .resizable()
//                            .frame(width: 100, height: 100)
//                    }
//                }
//                .buttonStyle(PlainButtonStyle())

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

                // ─────────────────────────────────────────
                // 🔻 계정 삭제 섹션 (파괴적 액션)
                VStack(spacing: 8) {
                    Divider().padding(.top, 8)

                    if let err = deleteError {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text(isDeleting ? "계정 삭제 중…" : "계정 삭제")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                    .disabled(isDeleting)
                    .confirmationDialog(
                        "정말 계정을 삭제하시겠어요?",
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("영구 삭제", role: .destructive) {
                            Task { await deleteAccount() }
                        }
                        Button("취소", role: .cancel) {}
                    } message: {
                        Text("계정과 데이터(프로필, 채팅 등)가 영구 삭제됩니다. 이 작업은 취소할 수 없습니다.")
                    }
                }
                // ─────────────────────────────────────────
                // ─────────────────────────────────────────
                // 🔐 개인정보/정책 섹션
                VStack(alignment: .leading, spacing: 12) {
                    Divider().padding(.top, 4)
                    Text("개인정보 및 정책")
                        .font(.headline)

                    // 3-1) 개인정보 처리방침(웹으로 열기)
                    Button {
                        showPolicyWeb = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("개인정보 처리방침 보기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // 3-2) 데이터 수집 고지(인앱 안내)
                    Button {
                        showPolicyDetail = true
                    } label: {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                            Text("데이터 수집 및 이용 안내")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // 3-3) 문의 이메일(mailto)
                    Link(destination: URL(string: "mailto:jjpapa36912@gmail.com?subject=VibeTalk%20Privacy%20Inquiry")!) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("문의: jjpapa36912@gmail.com")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.top, 4)
                // ─────────────────────────────────────────

            }

            Spacer()
        }
        .padding()
        .navigationTitle("내 프로필 수정")
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage)
//        }
        // Safari로 정책 페이지 열기
        .sheet(isPresented: $showPolicyWeb) {
            SFSafariViewControllerWrapper(url: URL(string: "https://jjpapa36912.tistory.com/87")!)
        }

        // 인앱 상세 고지(목적/항목/보관기간/제3자/권리/문의)
        .sheet(isPresented: $showPolicyDetail) {
            PrivacyDetailView()
        }

        .overlay {
            if isDeleting {
                // 삭제 중 오버레이
                ProgressView("계정 삭제 중…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        // ✅ 하단 배너 (콘텐츠를 위로 밀어주므로 가림 없음)
                .safeAreaInset(edge: .bottom) {
                    BannerAdView(controller: banner)
                        .frame(height: 50)              // 일반 배너 높이
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial) // 구분감
                        .shadow(radius: 1)
                }
        .onAppear(perform: fetchCurrentProfile)
    }

    // MARK: - 최신 프로필 로딩
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

//                    if let imageUrl = profile.profileImageUrl,
//                       let url = URL(string: "\(AppConfig.baseURLSpringBoot)\(imageUrl)") {
//                        print("🖼️ [Edit] 프로필 이미지 URL:", url)
//
//                        URLSession.shared.dataTask(with: url) { data, _, error in
//                            if let data = data, let uiImage = UIImage(data: data) {
//                                DispatchQueue.main.async {
//                                    self.selectedImage = uiImage
//                                    print("✅ [Edit] 이미지 다운로드 성공")
//                                }
//                            } else {
//                                print("⚠️ [Edit] 이미지 다운로드 실패:", error?.localizedDescription ?? "데이터 없음")
//                            }
//                        }.resume()
//                    } else {
//                        print("ℹ️ [Edit] 프로필 이미지 없음")
//                    }

                    self.isLoading = false
                }
            } catch {
                print("❌ [Edit] JSON 디코딩 오류:", error.localizedDescription)
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }

    // MARK: - 저장
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

        // 상태 메시지
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"statusMessage\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(statusMessage)\r\n".data(using: .utf8)!)

//        // 이미지
//        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
//            body.append("--\(boundary)\r\n".data(using: .utf8)!)
//            body.append("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
//            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
//            body.append(imageData)
//            body.append("\r\n".data(using: .utf8)!)
//        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { responseData, response, error in
            DispatchQueue.main.async {
                isSaving = false

                if let error = error {
                    print("❌ 요청 에러:", error.localizedDescription)
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 응답 코드:", httpResponse.statusCode)
                }

                if let data = responseData {
                    print("✅ 서버 응답:", String(data: data, encoding: .utf8) ?? "디코딩 실패")
                }

                // ✅ 메인 화면 데이터 갱신
                viewModel.fetchUserProfile()
//                viewModel.syncContacts()

                dismiss()
            }
        }.resume()
    }

    // MARK: - 계정 삭제
    @MainActor
        private func deleteAccount() async {
            deleteError = nil
            guard let url = URL(string: "\(AppConfig.baseURLSpringBoot)/api/me"),
                  let token = UserDefaults.standard.string(forKey: "jwtToken") else {
                deleteError = "인증 정보가 없습니다."
                return
            }

            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            isDeleting = true
            defer { isDeleting = false }

            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                print("📡 [Delete] 응답 코드:", code)

                if (200..<300).contains(code) || code == 204 {
                    // ✅ 성공: 전역 상태 초기화 → 로그인 화면으로 전환
                    viewModel.logout()        // 뷰모델 메모리/친구목록 정리
                    appState.logout()         // 토큰 제거 + 로그인 플래그 false + 탭/상태 초기화
                    appState.path = NavigationPath() // (선택) 네비 스택 초기화
                    // 로그인 루트로 스왑되므로 굳이 dismiss()는 필요 없음. 다만 호출해도 무방.
                    dismiss()
                } else {
                    deleteError = "삭제 실패(코드 \(code)). 잠시 후 다시 시도해 주세요."
                }
            } catch {
                deleteError = "네트워크 오류: \(error.localizedDescription)"
            }
        }
}
// Safari Wrapper
struct SFSafariViewControllerWrapper: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// 인앱 상세 고지(심사용 핵심 항목 명시)
struct PrivacyDetailView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("데이터 수집 목적") {
                    Text("친구 찾기 기능 제공(내 연락처와 앱 사용자 일치 여부 확인)")
                }
                Section("수집 항목") {
                    Text("연락처의 전화번호/이메일(최소 수집).")
                }
                
                Section("제3자 제공") {
                    Text("제3자에게 제공하지 않습니다.")
                }
                Section("사용자 권리") {
                    Text("데이터 열람/정정/삭제 요청 가능. 이메일로 요청하세요.")
                }
                Section("문의 이메일") {
                    Link("jjpapa36912@gmail.com",
                         destination: URL(string: "mailto:jjpapa36912@gmail.com")!)
                }
                Section("정책 전문") {
                    Link("개인정보 처리방침 전체보기",
                         destination: URL(string: "https://jjpapa36912.tistory.com/87")!)
                }
            }
            .navigationTitle("데이터 수집 및 이용 안내")
        }
    }
}
