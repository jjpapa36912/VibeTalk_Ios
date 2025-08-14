import SwiftUI
import Foundation

// 서버에서 가져오는 채팅방 목록 모델
struct ChatRoomListItem: Identifiable, Codable, Hashable {
    let id: Int
    let roomName: String
    let createdBy: String?
    let createdAt: String?
}

struct ChatParticipant: Codable, Hashable {
    let id: Int
    let name: String
}

// 기존 ChatRoomResponse와 동일
struct ChatRoomResponse: Identifiable, Codable, Hashable {
    let id: Int
    let roomName: String
}

// MARK: - ChatRoomListView (리뉴얼)
struct ChatRoomListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatRoomListViewModel()
    let currentUserId: Int

    var body: some View {
        NavigationStack(path: $appState.path) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.chatRooms) { room in
                        NavigationLink(value: ChatRoomResponse(id: room.id, roomName: room.roomName)) {
                            ChatRoomRowCard(room: room)
                        }
                        .buttonStyle(.plain) // 링크 눌렀을 때 하이라이트 안 보이게
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("채팅")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.fetchChatRooms()
                viewModel.fetchFriends()
            }
            .refreshable {        // 아래로 당겨 새로고침
                viewModel.fetchChatRooms()
            }
            // 🔕 툴바/로그아웃 버튼 없음
        }
    }
}

// MARK: - 카드형 셀
struct ChatRoomRowCard: View {
    let room: ChatRoomListItem

    var body: some View {
        HStack(spacing: 12) {
            // 아이콘 배지
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(room.roomName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let createdBy = room.createdBy, !createdBy.isEmpty {
                        Text("방장 \(createdBy)")
                    }
                    if let createdAt = room.createdAt, let pretty = formatTime(createdAt) {
                        Text(pretty)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // “HH:mm” 대신 상대시간 표기 (오늘은 시간만, 하루 이상은 날짜)
    private func formatTime(_ isoString: String) -> String? {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: isoString) else { return nil }

        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        } else {
            let f = DateFormatter()
            f.dateFormat = "M월 d일"
            return f.string(from: date)
        }
    }
}
