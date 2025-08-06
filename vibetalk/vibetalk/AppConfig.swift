//
//  AppConfig.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation

enum AppConfig {
    #if DEBUG
//    static let baseURL = "http://172.29.107.196:8080"//https://4cffc47374ec.ngrok-free.app
    static let baseURLSpringBoot = "https://3af12dd2c382.ngrok-free.app"
    static let baseURLFastApi = "https://45bdf6b84671.ngrok-free.app"
//    static let baseURL = "http://localhost:8080"
    #else
    static let baseURLSpringBoot = "http://13.124.208.108:8080"
    static let baseURLFastApi = "http://13.124.208.108:9001"
    #endif
//    // 포트 제거된 URL 반환
//    static var baseHost: String {
//        if var components = URLComponents(string: baseURL) {
//            components.port = nil
//            return components.url?.absoluteString ?? baseURL
//        }
//        return baseURL
//    }
    // ✅ WebSocket URL
    static var webSocketURL: String {
        #if DEBUG
//        return "ws://172.30.1.73:8080/ws"
        return "wss://3af12dd2c382.ngrok-free.app/ws"
        #else
        return "ws://13.124.208.108:8080/ws"
        #endif
    }


}
