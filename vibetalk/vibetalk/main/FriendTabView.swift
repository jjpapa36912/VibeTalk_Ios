//
//  FriendTabView.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//

import Foundation
import SwiftUI

struct FriendTabView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject var appState: AppState
    @State private var showCreateRoom = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 프로필 헤더
            HStack {
                if let profile = viewModel.userProfile,
                   let url = URL(string: "\(AppConfig.baseURL)\(profile.profileImageUrl ?? "")") {
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
                }) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                }
                
                // 설정 버튼
                NavigationLink(destination: ProfileEditView(
                    currentProfile: viewModel.userProfile ?? UserProfile(id: 0, name: "", statusMessage: nil, profileImageUrl: nil)
                )) {
                    Image(systemName: "gearshape.fill")
                }
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            
            Divider()
            
            // 친구 목록
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
        .sheet(isPresented: $showCreateRoom) {
            CreateChatRoomView(
                friends: viewModel.friends,
                currentUserId: viewModel.userId,
                onRoomCreated: { room in
                    // ✅ 방 생성 성공 시 Sheet 닫고 Path에 추가
                    showCreateRoom = false
                    appState.path.append(room)   // ✅ NavigationStack 자동 이동
                }
            )
            .environmentObject(appState)
        }
    }
}
