//
//  AppConfig.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation

enum AppConfig {
    #if DEBUG
    static let baseURL = "http://localhost:8080/api"
    #else
    static let baseURL = "http://13.124.208.108:8080/api"
    #endif
}
