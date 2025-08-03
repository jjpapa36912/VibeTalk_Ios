//
//  AppConfig.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation

enum AppConfig {
    #if DEBUG
    static let baseURL = "http://172.30.1.73:8080"
//    static let baseURL = "http://localhost:8080"
    #else
    static let baseURL = "http://13.124.208.108:8080"
    #endif
    
    // ✅ WebSocket URL
    static var webSocketURL: String {
        #if DEBUG
        return "ws://172.30.1.73:8080/ws"
        #else
        return "wss://13.124.208.108/ws"
        #endif
    }


}
