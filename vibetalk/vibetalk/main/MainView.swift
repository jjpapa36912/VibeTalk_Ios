import SwiftUI
import Foundation

struct FriendResponse: Codable, Identifiable {
    let id: Int
    let phoneNumber: String
    let appName: String
    let contactName: String
    let statusMessage: String?    // ✅ null 허용
    let profileImage: String?
}

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ✅ friends까지 전달
                ProfileHeaderView(
                    userProfile: viewModel.userProfile,
                    friends: viewModel.friends
                )
                
                Divider()
                
                List(viewModel.friends) { friend in
                    HStack {
                        Image(systemName: "person.circle")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text(friend.contactName.isEmpty ? friend.appName : friend.contactName)
                                .font(.headline)
                            Text(friend.statusMessage ?? "상태 메시지 없음")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("친구")
            .onAppear {
                viewModel.syncContacts()
                viewModel.fetchUserProfile()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("profileUpdated"))) { _ in
                viewModel.fetchUserProfile()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct ProfileHeaderView: View {
    let userProfile: UserProfile?
    let friends: [FriendResponse]   // ✅ 타입 수정
    
    var body: some View {
        HStack {
            if let imageUrl = userProfile?.profileImageUrl,
               let url = URL(string: "\(AppConfig.baseURL)\(imageUrl)") {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                    } else if phase.error != nil {
                        Image(systemName: "person.circle")
                            .resizable()
                    } else {
                        ProgressView()
                    }
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
                Text(userProfile?.name ?? "내 이름")
                    .font(.headline)
                Text(userProfile?.statusMessage ?? "상태 메시지 없음")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            HStack(spacing: 20) {
                Image(systemName: "person.badge.plus")
                
                // ✅ 그룹 채팅 생성 화면 이동
                NavigationLink(
                    destination: CreateChatRoomView(friends: friends)
                ) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
                
                // ✅ 프로필 수정 버튼
                NavigationLink(
                    destination: ProfileEditView(
                        currentProfile: userProfile ?? UserProfile(
                            name: "",
                            statusMessage: "",
                            profileImageUrl: nil
                        )
                    )
                ) {
                    Image(systemName: "gearshape.fill")
                }
            }
            .font(.title3)
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
}
