//
//  ContentView.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showSignupSheet = false
    @State private var showResetSheet = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @StateObject private var banner = BannerAdController()

    
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
                            if success {
                                if let token = UserDefaults.standard.string(forKey: "jwtToken") {
                                    appState.loginSuccess(token: token)
                                }
                            }
                        }
                    })  {
                        Text("로그인")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    // ✅ 1차 동의 (선택)
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "consent.contacts.upload") },
                        set: { newVal in
                            UserDefaults.standard.set(newVal, forKey: "consent.contacts.upload")
                            UserDefaults.standard.set("v1.0", forKey: "consent.version")
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("친구 찾기 기능을 위해 연락처 접근 권한이 필요합니다. 동의 시 연락처는 서버에 업로드되며 친구 추천/검색 목적에만 사용됩니다. 동의하지 않으면 업로드되지 않습니다.")
                                .font(.footnote)
                            // 정책 링크가 있으면 버튼 하나 더
                            if let url = URL(string: "https://jjpapa36912.tistory.com/87") {
                                Link("개인정보 처리방침", destination: url).font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal)

                    
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
                // ✅ 하단 배너 (콘텐츠를 위로 밀어주므로 가림 없음)
                        .safeAreaInset(edge: .bottom) {
                            BannerAdView(controller: banner)
                                .frame(height: 50)              // 일반 배너 높이
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial) // 구분감
                                .shadow(radius: 1)
                        }
            }
        }
    }
}



#Preview {
    ContentView()
}
