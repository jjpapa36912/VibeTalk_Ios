////
////  ProfileHeaderView.swift
////  vibetalk
////
////  Created by 김동준 on 7/28/25.
////
//
//import Foundation
//import SwiftUI
//struct ProfileHeaderView: View {
//    var body: some View {
//        HStack {
//            Image("profile") // 사용자 프로필 이미지
//                .resizable()
//                .frame(width: 50, height: 50)
//                .clipShape(Circle())
//            
//            VStack(alignment: .leading) {
//                Text("김동준")
//                    .font(.headline)
//                Text("잠잠하게")
//                    .font(.subheadline)
//                    .foregroundColor(.gray)
//            }
//            Spacer()
//            
//            HStack(spacing: 20) {
//                Image(systemName: "magnifyingglass")
//                Image(systemName: "person.badge.plus")
//                Image(systemName: "music.note")
//                Image(systemName: "gearshape.fill")
//            }
//            .font(.title3)
//        }
//        .padding()
//        .background(Color.black)
//        .foregroundColor(.white)
//    }
//}
