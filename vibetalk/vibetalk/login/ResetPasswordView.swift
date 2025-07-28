//
//  ResetPasswordView.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//
import Foundation
import SwiftUI

struct ResetPasswordView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("가입한 이메일 입력", text: $email)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .keyboardType(.emailAddress)
                
                Button("비밀번호 재설정") {
                    viewModel.resetPassword(email: email)
                    dismiss()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("비밀번호 찾기")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
