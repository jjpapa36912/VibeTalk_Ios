////
////  MainView.swift
////  vibetalk
////
////  Created by 김동준 on 7/28/25.
////
//
//import Foundation
//import SwiftUI
//
struct FriendResponse: Codable, Identifiable {
    let id: Int
    let phoneNumber: String
    let appName: String
    let contactName: String
    let statusMessage: String
    let profileImage: String?
}

import SwiftUI

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileHeaderView()
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
                            Text(friend.statusMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("친구")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "jwtToken")
                        NotificationCenter.default.post(
                            name: Foundation.Notification.Name("didLogout"),
                            object: nil
                        )
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                            Text("로그아웃")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.syncContacts()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


struct ProfileHeaderView: View {
    var body: some View {
        HStack {
            Image("profile")
                .resizable()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text("내 이름")
                    .font(.headline)
                Text("상태 메시지")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            HStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                Image(systemName: "person.badge.plus")
                Image(systemName: "music.note")
                Image(systemName: "gearshape.fill")
            }
            .font(.title3)
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
}
