//
//  SignupView.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

// SignupView.swift
import SwiftUI


struct SignupView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("이름", text: $viewModel.signupName)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                
                TextField("이메일", text: $viewModel.signupEmail)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .keyboardType(.emailAddress)
                TextField("전화번호", text: $viewModel.signupPhoneNumber)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .keyboardType(.emailAddress)
                SecureField("비밀번호", text: $viewModel.signupPassword)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                
                Button(action: {
                    viewModel.register()
                    clearFields()
                    dismiss()
                }) {
                    Text("회원가입")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("회원가입")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        clearFields()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func clearFields() {
        viewModel.signupName = ""
        viewModel.signupEmail = ""
        viewModel.signupPassword = ""
    }
}
