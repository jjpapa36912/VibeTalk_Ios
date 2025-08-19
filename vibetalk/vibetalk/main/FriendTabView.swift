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

    var body: some View {
        VStack(spacing: 0) {
            // 프로필 헤더
            HStack {
                if let profile = viewModel.userProfile,
                   let url = URL(string: "\(AppConfig.baseURLSpringBoot)\(profile.profileImageUrl ?? "")") {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable() }
                        else { Image(systemName: "person.circle").resizable() }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
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
                        if let urlStr = friend.absoluteProfileImageUrl,
                           let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .onAppear { print("⌛ [AsyncImage] start: \(urlStr)") }
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                        .onAppear { print("🖼️ [AsyncImage] success: \(urlStr)") }
                                case .failure(let error):
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .onAppear { print("❌ [AsyncImage] fail: \(urlStr) – \(error.localizedDescription)") }
                                @unknown default:
                                    Image(systemName: "person.circle").resizable()
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .onAppear { print("🚫 no URL for id=\(friend.id), name=\(friend.contactName.isEmpty ? friend.appName : friend.contactName)") }
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
        .sheet(isPresented: $showCreateRoom) {
            // onDismiss
            print("🔴 CreateChatRoomView sheet dismissed")
        } content: {
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
        .onAppear {
            print("👣 FriendTabView onAppear")
            viewModel.fetchUserProfile()
            viewModel.syncContacts()
        }
        // 🔍 상태 변화 로깅
        .onChange(of: showCreateRoom) { newVal in
            print("🔁 showCreateRoom changed -> \(newVal)")
        }
        .onChange(of: viewModel.friends.count) { count in
            print("📥 friends count updated -> \(count)")
        }
    }
}
