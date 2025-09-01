import SwiftUI

struct CreateChatRoomView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFriends: Set<Int> = []
    @State private var isCreatingRoom = false
    @State private var selectedMode: ChatRoomMode? = nil

    let friends: [FriendResponse]
    let onRoomCreated: (ChatRoomResponse) -> Void
    @StateObject private var banner = BannerAdController()

    // ✅ 이 조건만 참이면 버튼 활성화
    private var canCreate: Bool {
        !selectedFriends.isEmpty && selectedMode != nil && !isCreatingRoom
    }

    var body: some View {
        VStack(spacing: 0) {
            // (선택) 선택된 친구 가로 스크롤 영역이 있으면 여기 유지

            modeSelector  // ⬅️ 모드 선택 영역

            // 친구 리스트
            List(friends) { friend in
                HStack {
                    Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
                    Spacer()
                    Button {
                        if selectedFriends.contains(friend.id) {
                            selectedFriends.remove(friend.id)
                        } else if selectedFriends.count < 7 {
                            selectedFriends.insert(friend.id)
                        }
                    } label: {
                        Image(systemName: selectedFriends.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedFriends.contains(friend.id) ? .blue : .gray)
                    }
                }
            }

            // ⚠️ 모드 미선택 시 경고 텍스트
            if selectedMode == nil {
                Text("방 모드를 선택해 주세요.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            // ✅ 여기만 바꾸면 됨
            Button(action: {
                createRoom()
            }) {
                Text(isCreatingRoom ? "생성 중..." : "방 생성하기")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canCreate ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .disabled(!canCreate)  // ← canCreate를 단일 진실로 사용
        }
        .navigationTitle("그룹 채팅")
        // ✅ 하단 배너 (콘텐츠를 위로 밀어주므로 가림 없음)
                .safeAreaInset(edge: .bottom) {
                    BannerAdView(controller: banner)
                        .frame(height: 50)              // 일반 배너 높이
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial) // 구분감
                        .shadow(radius: 1)
                }
    }

    // MARK: - 모드 선택 + 안내 문구
    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("방 모드 선택")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                modeButton(.fun, tint: .pink)
                modeButton(.formal, tint: .indigo)
                modeButton(.dialect, tint: .orange)
                modeButton(.random, tint: .teal)
            }
            .padding(.horizontal)

            if let mode = selectedMode {
                Text(mode.noticeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func modeButton(_ mode: ChatRoomMode, tint: Color) -> some View {
        let isSel = (selectedMode == mode)
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                Text(mode.displayName).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSel ? tint.opacity(0.2) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSel ? tint : Color(.systemGray4), lineWidth: isSel ? 2 : 1)
            )
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 방 생성 실행
    private func createRoom() {
        guard let selectedMode, !isCreatingRoom, !selectedFriends.isEmpty else {
            // 디버깅용 로그
            print("⛔️ createRoom guard fail — mode=\(String(describing: selectedMode)), isCreating=\(isCreatingRoom), members=\(selectedFriends)")
            return
        }

        isCreatingRoom = true
        print("🚀 createRoom start — mode=\(selectedMode.rawValue), members=\(selectedFriends)")

        ChatService.shared.createChatRoom(
            memberIds: Array(selectedFriends),
            roomName: "새 그룹",
            mode: selectedMode
        ) { result in
            DispatchQueue.main.async {
                self.isCreatingRoom = false
                switch result {
                    // CreateChatRoomView.createRoom() 안의 성공 처리 부분 교체
                    // CreateChatRoomView.createRoom() 성공 블록
                    case .success(let room):
                        // 서버 응답에 mode가 없으면 선택한 모드로 보정
                        let final = (room.mode == nil) ? room.withMode(selectedMode) : room
                        RoomModeCache.set(id: final.id, mode: final.roomMode)   // ✅ 캐시 저장
                        onRoomCreated(final)

                case .failure(let error):
                    print("❌ createRoom FAIL — \(error.localizedDescription)")
                }
            }
        }
    }
}
import Foundation

import Foundation

enum ChatRoomMode: String, Codable, CaseIterable, Identifiable {
    case fun, formal, dialect, random
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fun: return "재밌는"
        case .formal: return "포멀·라이트"
        case .dialect: return "사투리"
        case .random: return "랜덤"
        }
    }

    var noticeText: String {
        switch self {
        case .fun:    return "재밌는 방은 모든 메시지가 유쾌하고 웃긴 톤으로 변환됩니다."
        case .formal: return "포멀·라이트 방은 모든 메시지가 부드럽고 정중한 톤으로 변환됩니다."
        case .dialect:return "사투리방은 모든 메시지가 사투리 톤으로 변환됩니다."
        case .random: return "랜덤 방은 메시지가 매번 다른 톤으로 변환됩니다."
        }
    }

    var systemImage: String {
        switch self {
        case .fun:    return "sparkles"
        case .formal: return "briefcase.fill"
        case .dialect:return "waveform"
        case .random: return "die.face.5"
        }
    }

    static func from(raw: String?) -> ChatRoomMode {
        guard let r = raw?.lowercased() else { return .random }
        return ChatRoomMode(rawValue: r) ?? .random
    }
}
