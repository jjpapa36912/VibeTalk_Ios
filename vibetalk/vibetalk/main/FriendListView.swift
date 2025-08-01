//
//  FriendListView.swift
//  vibetalk
//
//  Created by 김동준 on 8/1/25.
//

import Foundation
import SwiftUI

struct FriendListView: View {
    @StateObject private var viewModel = MainViewModel()
    let currentUserId: Int
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileHeaderView(
                    userProfile: viewModel.userProfile,
                    friends: viewModel.friends,
                    currentUserId: currentUserId
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
        }
    }
}
