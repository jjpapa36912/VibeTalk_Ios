//
//  FriendTabView.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//
//
//  FriendTabView.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//

import Foundation
import SwiftUI
// AppConfig.swift (혹은 Constants.swift)
enum TestFriendConfig {
    static let userId: Int = 4                 // DB에 미리 만들어둔 테스트 유저 id
    static let displayName: String = "VibeTalk Test" // 리스트 표시용 이름
    static let status: String = "Demo account for review"
    static let avatarURL: String? = nil              // 있으면 절대 URL 넣기
}

struct FriendTabView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject var appState: AppState
    @State private var showCreateRoom = false
    @State private var showConsentSheet = false
    @State private var showSettingsAlert = false
    @StateObject private var banner = BannerAdController()


    var body: some View {
        VStack(spacing: 0) {
            // 프로필 헤더
            HStack {
                if let url = viewModel.userProfile?.absoluteProfileURL {
                    AuthAsyncImageView(
                        url: url,
                        token: nil, // 공개 이미지면 nil 넣어도 OK
                        placeholder: Image(systemName: "person.circle"),
                        contentMode: .fill,
                        cornerRadius: 25,
                        size: CGSize(width: 50, height: 50)
                    )
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }



                VStack(alignment: .leading) {
                    Text(viewModel.userProfile?.name ?? "내 이름")
                        .font(.headline)
                    Text(viewModel.userProfile?.statusMessage ?? "상태 메시지 없음")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()

                // 채팅방 개설 버튼
                Button(action: {
                    print("➕ [FriendTabView] 채팅방 개설 버튼 클릭")
                    showCreateRoom = true
                    print("🟢 showCreateRoom -> true")
                }) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }

                // 설정 버튼
                NavigationLink(
                    destination: ProfileEditView(
                        currentProfile: viewModel.userProfile ?? UserProfile(id: 0, name: "", statusMessage: nil, profileImageUrl: nil),
                        viewModel: viewModel
                    )
                ) {
                    Image(systemName: "gearshape.fill")
                }
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)

            Divider()

            Button {
                // 2차 흐름 시작
                viewModel.ensureContactsSyncFlow(
                    presentConsent: { showConsentSheet = true },
                    presentSettingsGuide: { showSettingsAlert = true }
                )
            } label: {
                Text("연락처로 친구 찾기")
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            // 친구 목록
            // 친구 목록
            if viewModel.friends.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("친구 목록 불러오는 중…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.friends) { friend in
                    HStack(spacing: 12) {
                        // ✅ 아바타: absoluteProfileImageUrl 사용
                        if let url = friend.absoluteProfileURL {
                            AuthAsyncImageView(
                                url: url,
                                token: nil, // 공개면 nil
                                placeholder: Image(systemName: "person.circle"),
                                contentMode: .fill,
                                cornerRadius: 20,
                                size: CGSize(width: 40, height: 40)
                            )
                        } else {
                            Image(systemName: "person.circle")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .onAppear {
                                    print("🚫 no URL for id=\(friend.id), name=\(friend.contactName.isEmpty ? friend.appName : friend.contactName)")
                                }
                        }




                        VStack(alignment: .leading, spacing: 4) {
                            Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
                                .font(.headline)
                            Text(friend.statusMessage ?? "상태 메시지 없음")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

        }
        // ✅ 시트로 띄우기: onAppear 로깅 포함
        // (A) 채팅방 생성 시트
        .sheet(isPresented: $showCreateRoom) {
            CreateChatRoomView(
                friends: viewModel.friends,
                onRoomCreated: { room in
                    print("🎉 onRoomCreated: id=\(room.id), name=\(room.roomName), mode=\(room.mode)")
                    viewModel.fetchChatRooms()             // 목록 새로고침
                    showCreateRoom = false                  // 시트 닫기
                    print("🔻 showCreateRoom -> false (close sheet)")
                    // 필요 시 채팅방으로 이동
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.path.append(room)
                        print("➡️ push ChatRoomView for roomId=\(room.id)")
                    }
                }
            )
            .environmentObject(appState)
            .onAppear {
                print("🟩 CreateChatRoomView sheet onAppear (friends=\(viewModel.friends.count))")
            }
        }

        // (B) 연락처 업로드 동의 시트
        .sheet(isPresented: $showConsentSheet) {
            ContactUploadConsentSheet(
                onAgree: {
                    viewModel.recordContactsConsent()      // 동의 저장
                    showConsentSheet = false
                    viewModel.ensureContactsSyncFlow(      // 다시 진입 → 권한요청/업로드
                        presentConsent: {},
                        presentSettingsGuide: { showSettingsAlert = true }
                    )
                },
                onCancel: { showConsentSheet = false }
            )
        }
        // ✅ 하단 배너 (콘텐츠를 위로 밀어주므로 가림 없음)
                .safeAreaInset(edge: .bottom) {
                    BannerAdView(controller: banner)
                        .frame(height: 50)              // 일반 배너 높이
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial) // 구분감
                        .shadow(radius: 1)
                }

        // (C) 연락처 접근 권한 안내 알럿
        .alert("연락처 접근 권한 필요", isPresented: $showSettingsAlert) {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("설정 > 개인정보보호 > 연락처에서 vibetalk 권한을 허용하세요.")
        }

        // FriendTabView 진입 시 실행
        .onAppear {
            print("👣 FriendTabView onAppear")
            viewModel.fetchUserProfile()
            // viewModel.syncContacts() ❌ 자동 호출 금지 → 버튼 눌렀을 때만 실행
        }

        // 상태 변화 로깅
        .onChange(of: showCreateRoom) { newVal in
            print("🔁 showCreateRoom changed -> \(newVal)")
        }
        .onChange(of: viewModel.friends.count) { count in
            print("📥 friends count updated -> \(count)")
        }

    }
}
struct ContactUploadConsentSheet: View {
    @State private var agree = false
    let onAgree: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("연락처 서버 업로드 동의")
                    .font(.title3).bold()
                Text("""
친구 찾기 기능을 위해 연락처(해시 처리)를 서버로 업로드합니다.
• 목적: 내 연락처와 앱 사용자 일치 여부 확인
• 보관: 일치 검사용으로만 사용 후 정책에 따라 삭제
• 거부 시: 앱 사용 가능(친구 찾기 기능만 제한)
""")
                Toggle("서버 업로드에 동의합니다", isOn: $agree)
                    .padding(.vertical, 8)
                Spacer()
                HStack {
                    Button("취소", action: onCancel)
                    Spacer()
                    Button("동의하고 계속", action: onAgree).disabled(!agree)
                }
            }
            .padding()
            .toolbar {
                if let url = URL(string: "https://jjpapa36912.tistory.com/87") {
                    ToolbarItem(placement: .topBarTrailing) {
                        Link("개인정보 처리방침", destination: url)
                    }
                }
            }
        }
    }
}

import SwiftUI

struct AuthAsyncImageView: View {
    let url: URL
    let token: String?                 // Bearer 토큰 필요 없으면 nil
    let placeholder: Image             // 실패/로딩시 보여줄 기본 이미지
    let contentMode: ContentMode       // .fill / .fit
    let cornerRadius: CGFloat
    let size: CGSize?

    @State private var uiImage: UIImage?
    @State private var isLoading = false
    @State private var loadId = UUID() // 뷰 갱신시 재시도 제어

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .frame(width: size?.width, height: size?.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .id(loadId) // SwiftUI 재조립 시도시 안정화
        .onAppear(perform: load)
    }

    private func load() {
        guard uiImage == nil, !isLoading else { return }
        isLoading = true

        var request = URLRequest(url: url)

        // 공개 이미지면 token은 nil로 두세요.
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        // ✅ ngrok 인터스티셜 우회 헤더 + 커스텀 UA
        // AuthAsyncImageView.load() 내부
        #if DEBUG
        if let host = url.host, host.contains("ngrok") {
            request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
            request.setValue("VibeTalk-iOS/1.0", forHTTPHeaderField: "User-Agent")
        }
        #endif


        URLSession.shared.dataTask(with: request) { data, resp, err in
            defer { isLoading = false }
            if let err = err {
                print("❌ [AuthAsyncImageView] network:", err.localizedDescription, "→", url.absoluteString)
                return
            }
            guard let http = resp as? HTTPURLResponse else { return }
            print("📡 [AuthAsyncImageView] status:", http.statusCode, "url:", url.absoluteString)

            guard (200..<300).contains(http.statusCode),
                  let data = data,
                  let img = UIImage(data: data) else {
                if let data, let body = String(data: data, encoding: .utf8) {
                    print("📝 [AuthAsyncImageView] error body:", body.prefix(200))
                }
                return
            }
            DispatchQueue.main.async { self.uiImage = img }
        }.resume()
    }

}
extension String {
    func ensuringLeadingSlash() -> String {
        hasPrefix("/") ? self : "/" + self
    }
}

extension UserProfile {
    var absoluteProfileURL: URL? {
        guard let path = profileImageUrl, !path.isEmpty else { return nil }
        if path.lowercased().hasPrefix("http") { return URL(string: path) }
        return URL(string: AppConfig.baseURLSpringBoot + path.ensuringLeadingSlash())
    }
}

extension FriendResponse {
    var absoluteProfileURL: URL? {
        guard let raw = profileImageUrl,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if raw.lowercased().hasPrefix("http") { return URL(string: raw) }
        return URL(string: AppConfig.baseURLSpringBoot + raw.ensuringLeadingSlash())
    }
}
