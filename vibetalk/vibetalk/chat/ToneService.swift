//
//  ToneService.swift
//  vibetalk
//
//  Created by 김동준 on 8/16/25.
//

import Foundation

struct ConvertRequestBody: Codable {
    let sentence: String
    let mode: String    // "fun" | "formal" | "dialect" | "random"
}

struct ConvertResponseBody: Codable {
    let mode: String
    let style: String
    let output: String
}

enum ToneServiceError: LocalizedError {
    case badURL, network(Error), badStatus(Int, String), emptyData, decode(Error)
    var errorDescription: String? {
        switch self {
        case .badURL: return "유효하지 않은 URL"
        case .network(let e): return "네트워크 오류: \(e.localizedDescription)"
        case .badStatus(let code, let body): return "서버 상태 \(code): \(body)"
        case .emptyData: return "응답이 비었습니다"
        case .decode(let e): return "디코딩 실패: \(e.localizedDescription)"
        }
    }
}

final class ToneService {
    static func convert(sentence: String, mode: ChatRoomMode, completion: @escaping (Result<ConvertResponseBody, ToneServiceError>) -> Void) {
        guard let url = URL(string: "\(AppConfig.baseURLFastApi)/convert") else {
            completion(.failure(.badURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = ConvertRequestBody(sentence: sentence, mode: mode.rawValue)
        do {
            req.httpBody = try JSONEncoder().encode(payload)
        } catch {
            completion(.failure(.decode(error))); return
        }

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(.network(err))); return }
            guard let http = resp as? HTTPURLResponse else { completion(.failure(.emptyData)); return }
            guard let data = data, !data.isEmpty else { completion(.failure(.emptyData)); return }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<no body>"
                completion(.failure(.badStatus(http.statusCode, body))); return
            }
            do {
                let decoded = try JSONDecoder().decode(ConvertResponseBody.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decode(error)))
            }
        }.resume()
    }
}
