import SwiftUI
import Foundation

import PhotosUI   // ✅ 추가


struct FriendListView: View {
    @StateObject private var viewModel = MainViewModel()
    let currentUserId: Int

    @State private var query: String = ""
    @State private var showEditProfile = false   // ✅ 추가


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 상단 프로필 영역은 그대로 사용
                    ProfileHeaderView(
                        userProfile: viewModel.userProfile,
                        friends: viewModel.friends,
                        currentUserId: currentUserId
                    )

                    Divider().opacity(0.15)

                    // 검색창
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        TextField("친구 검색", text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // 카드형 리스트
                    LazyVStack(spacing: 12) {
                        ForEach(filteredFriends) { friend in
                            Button {
                                // TODO: 프로필/채팅 화면으로 이동 로직 연결
                            } label: {
                                FriendRowCard(friend: friend)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .contextMenu {
                                Button { /* 채팅 시작 */ } label: {
                                    Label("채팅하기", systemImage: "bubble.right.fill")
                                }
                                Button(role: .destructive) { /* 숨기기 */ } label: {
                                    Label("숨기기", systemImage: "eye.slash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button { /* 채팅 시작 */ } label: {
                                    Label("채팅", systemImage: "paperplane.fill")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 14)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("친구")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.syncContacts()
                viewModel.fetchUserProfile()
            }
            .refreshable {
                viewModel.syncContacts()
                viewModel.fetchUserProfile()
            }
        }
    }

    // 뷰모델 friends → 화면용 모델로 표준화 (URL 필드는 현재 없음 → nil)
    private var filteredFriends: [FriendModel] {
        let base = viewModel.friends.map {
            FriendModel(
                id: $0.id,
                name: ($0.contactName.isEmpty ? $0.appName : $0.contactName),
                status: $0.statusMessage ?? "상태 메시지 없음",
                avatarURL: nil // 백엔드에 이미지 URL 생기면 이 필드만 교체
            )
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(q)
            || $0.status.localizedCaseInsensitiveContains(q)
        }
    }
}

// 화면 렌더용 표준 모델
struct FriendModel: Identifiable, Hashable {
    let id: Int
    let name: String
    let status: String
    let avatarURL: String?
}

// 카드형 친구 셀 (채팅방 카드와 동일한 톤)
private struct FriendRowCard: View {
    let friend: FriendModel

    var body: some View {
        HStack(spacing: 12) {
            // 그라디언트 아바타 + 이니셜
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.88), Color.purple.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                if let urlStr = friend.avatarURL,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Text(initials(friend.name))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Text(initials(friend.name))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 52, height: 52)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(friend.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 우측 빠른 액션 아이콘군
            HStack(spacing: 14) {
                Image(systemName: "bubble.right.fill")
                Image(systemName: "ellipsis")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        .contentShape(Rectangle())
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = (parts.count > 1 ? parts.last?.first.map(String.init) : nil) ?? ""
        return (first + last).uppercased()
    }
}
