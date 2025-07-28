//
//  ContentView.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var isLoggedIn = false
    @State private var showSignupSheet = false
    @State private var showResetSheet = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.black : Color.white)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    Text("로그인")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    TextField("이메일", text: $viewModel.email)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("비밀번호", text: $viewModel.password)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button(action: {
                        viewModel.login { success in
                            if success { isLoggedIn = true }
                        }
                    }) {
                        Text("로그인")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    // 🔹 회원가입 / 비밀번호 찾기 버튼 복원
                    HStack {
                        Button("회원가입") {
                            showSignupSheet = true
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("비밀번호 찾기") {
                            showResetSheet = true
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                .alert(isPresented: $viewModel.showAlert) {
                    Alert(
                        title: Text("알림"),
                        message: Text(viewModel.alertMessage),
                        dismissButton: .default(Text("확인"))
                    )
                }
                .sheet(isPresented: $showSignupSheet) {
                    SignupView(viewModel: viewModel)
                }
                .sheet(isPresented: $showResetSheet) {
                    ResetPasswordView(viewModel: viewModel)
                }
                
                NavigationLink("", destination: MainView(), isActive: $isLoggedIn)
                    .hidden()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
            viewModel.email = ""
            viewModel.password = ""
            isLoggedIn = false
        }
    }
}




#Preview {
    ContentView()
}
