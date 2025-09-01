import SwiftUI
import Foundation

// 서버에서 가져오는 채팅방 목록 모델
struct ChatRoomListItem: Identifiable, Codable, Hashable {
    let id: Int
    let roomName: String
    let createdBy: String?
    let createdAt: String?
    let mode: String?     // ✅ 추가

}

struct ChatParticipant: Codable, Hashable {
    let id: Int
    let name: String
}

import Foundation

import Foundation

// ChatRoomResponse.swift
// 서버 응답과 통일: 이 모델 하나로 통일해서 사용
struct ChatRoomResponse: Identifiable, Codable, Hashable {
    let id: Int
    let roomName: String
    let mode: String?          // "dialect" | "fun" | "formal" | "random" | null
    let createdBy: Int?        // 서버가 숫자 ID로 내려오는 경우가 있어 Int? 로
    let createdAt: String?     // ISO-8601 문자열

    var roomMode: ChatRoomMode { ChatRoomMode.from(raw: mode) }

    // 편의 생성자 (로컬 생성 시)
    init(id: Int, roomName: String, mode: ChatRoomMode = .random, createdBy: Int? = nil, createdAt: String? = nil) {
        self.id = id
        self.roomName = roomName
        self.mode = mode.rawValue
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}
extension ChatRoomResponse {
    func withMode(_ newMode: ChatRoomMode) -> ChatRoomResponse {
        return ChatRoomResponse(
            id: self.id,
            roomName: self.roomName,
            mode: newMode,
            createdBy: self.createdBy,
            createdAt: self.createdAt
        )
    }
}

//// 편의 init & 보정 유틸
//extension ChatRoomResponse {
//    init(id: Int, roomName: String, mode: ChatRoomMode = .random) {
//        self.id = id
//        self.roomName = roomName
//        self.mode = mode.rawValue
//    }
//    func withMode(_ mode: ChatRoomMode) -> ChatRoomResponse {
//        ChatRoomResponse(id: id, roomName: roomName, mode: mode)
//    }
//}

import SwiftUI

struct ChatRoomListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatRoomListViewModel()
    let currentUserId: Int
    @StateObject private var banner = BannerAdController()

    var body: some View {
        NavigationStack(path: $appState.path) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.chatRooms) { room in
                        NavigationLink(value: room) {
                            ChatRoomRowCard(room: room)
                        }
                        .buttonStyle(.plain)
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
            .refreshable {
                viewModel.fetchChatRooms()
            }
            .navigationDestination(for: ChatRoomResponse.self) { room in
                ChatRoomView(
                    room: room,
                    currentUserId: currentUserId
                )
                .environmentObject(appState)
            }
            // ✅ 하단 배너 (콘텐츠를 위로 밀어주므로 가림 없음)
                    .safeAreaInset(edge: .bottom) {
                        BannerAdView(controller: banner)
                            .frame(height: 50)              // 일반 배너 높이
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial) // 구분감
                            .shadow(radius: 1)
                    }
        }
    }
}

struct ChatRoomRowCard: View {
    let room: ChatRoomResponse

    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
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
                HStack(spacing: 6) {
                    Text(room.roomName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // 모드 뱃지(선택)
                    Text(room.roomMode.displayName)
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }

                HStack(spacing: 6) {
                    if let createdBy = room.createdBy {
                        Text("방장 #\(createdBy)")
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

    private func formatTime(_ isoString: String) -> String? {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: isoString) else { return nil }

        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return f.string(from: date)
        } else {
            let f = DateFormatter(); f.dateFormat = "M월 d일"
            return f.string(from: date)
        }
    }
}

enum RoomModeCache {
    static let key = "roomModeCache"

    static func set(id: Int, mode: ChatRoomMode) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String:String]) ?? [:]
        dict["\(id)"] = mode.rawValue
        UserDefaults.standard.set(dict, forKey: key)
    }

    static func get(id: Int) -> ChatRoomMode? {
        let dict = (UserDefaults.standard.dictionary(forKey: key) as? [String:String]) ?? [:]
        if let raw = dict["\(id)"] { return ChatRoomMode.from(raw: raw) }
        return nil
    }
}
