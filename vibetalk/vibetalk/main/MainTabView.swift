import SwiftUI
import SwiftUI

import SwiftUI

struct MainTabView: View {
    @StateObject private var badgeViewModel = UnreadBadgeViewModel()
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationStack {
            TabView(selection: $appState.selectedTab) {
                // 친구 탭
                FriendTabView(viewModel: viewModel)
                    .tabItem {
                        Label("친구", systemImage: "person.2.fill")
                    }
                    .tag(0)

                // 채팅방 탭
                ChatRoomListView(currentUserId: viewModel.userId)
                    .tabItem {
                        Label("채팅", systemImage: "message.fill")
                    }
                    .tag(1)
                    .badge(badgeViewModel.totalUnreadCount)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("로그아웃") {
                        appState.logout()
                    }
                }
            }
            .onAppear {
                print("🌐 [MainTabView] onAppear → 친구/프로필 로딩")
                badgeViewModel.connectForUnread(userId: viewModel.userId)
                viewModel.fetchUserProfile()
                viewModel.syncContacts()
            }
            .onDisappear {
                print("🔌 [MainTabView] onDisappear → STOMP 해제")
                badgeViewModel.disconnect()
            }
            .navigationTitle(appState.selectedTab == 0 ? "친구" : "채팅")
        }
    }
}


// ✅ 커스텀 Badge Modifier
struct BadgeModifier: ViewModifier {
    let count: Int
    
    func body(content: Content) -> some View {
        if count > 0 {
            content.badge(count)
        } else {
            content
        }
    }
}
extension View {
    @ViewBuilder
    func applyBadge(_ count: Int) -> some View {
        if count > 0 {
            self.badge(count)
        } else {
            self
        }
    }
}
