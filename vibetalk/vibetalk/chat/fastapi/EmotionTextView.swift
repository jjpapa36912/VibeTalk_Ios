//
//  EmotionTextView.swift
//  vibetalk
//
//  Created by 김동준 on 8/4/25.
//

//
//  EmotionTextView.swift
//  messageTest
//
//  Created by 김동준 on 7/31/25.
//
import SwiftUI

struct EmotionTextView: View {
    let result: EmotionResult

    var body: some View {
        let style = emotionStyles[result.emotion] ?? emotionStyles["neutral"]!
        let emoji = result.emoji ?? style.emoji   // ← 요 한 줄 추가

        VStack(spacing: 10) {
            // Whisper 기반 텍스트 + 이모지
            Text("\(style.emoji) \(result.client_text)")
                .font(.system(size: style.fontSize, weight: .bold))
                .foregroundColor(style.color)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style.color.opacity(0.1))
                )
                .shadow(color: style.color.opacity(0.3), radius: 5)

            // Pitch / Volume 보조 정보
            Text("Pitch: \(Int(result.pitch)) Hz | Volume: \(String(format: "%.2f", result.volume))")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct EmotionStyle {
    let emoji: String
    let color: Color
    let fontSize: CGFloat
    let font: Font  // ✅ 여기를 fontName → font로 바꿉니다
    let fontName: String  // ✅ 추가: DB 저장용 폰트 이름


}


import Foundation
struct EmotionResult: Codable, Identifiable, Equatable {
    var id: String

    let client_text: String
    let pitch: Float
    let volume: Float
    let emotion: String
    let confidence: Float
    let source: String
    var fontName: String?
    var emoji: String?

    let senderId: Int?
    let senderName: String
    let sentAt: String
    let roomId: Int?

    // ✅ 추가: 스타일 변환 결과
    var transformed_text: String?   // 서버 키: "transformed_text"
    var styleName: String?          // 서버 키: "style_name"

    private enum CodingKeys: String, CodingKey {
        case id, client_text, pitch, volume, emotion, confidence, source, fontName, emoji
        case senderId, senderName, sentAt, roomId
        // 보조 키들
        case clientMessageId, content, messageId
        // ✅ 스타일 관련 여러 표기 허용
        case transformed_text, transformedText
        case styleName, style_name, style
    }

    init(
        id: String,
        client_text: String,
        pitch: Float,
        volume: Float,
        emotion: String,
        confidence: Float,
        source: String,
        fontName: String? = nil,
        emoji: String? = nil,
        senderId: Int? = nil,
        senderName: String = "",
        sentAt: String = "",
        roomId: Int? = nil,
        transformed_text: String? = nil,
        styleName: String? = nil
    ) {
        self.id = id
        self.client_text = client_text
        self.pitch = pitch
        self.volume = volume
        self.emotion = emotion
        self.confidence = confidence
        self.source = source
        self.fontName = fontName
        self.emoji = emoji
        self.senderId = senderId
        self.senderName = senderName
        self.sentAt = sentAt
        self.roomId = roomId
        self.transformed_text = transformed_text
        self.styleName = styleName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id/clientMessageId/messageId 유연 디코딩
        if let s = try c.decodeIfPresent(String.self, forKey: .id) {
            self.id = s
        } else if let s = try c.decodeIfPresent(String.self, forKey: .clientMessageId) {
            self.id = s
        } else if let s = try c.decodeIfPresent(String.self, forKey: .messageId) {
            self.id = s
        } else if let n = try c.decodeIfPresent(Int.self, forKey: .id) {
            self.id = String(n)
        } else if let n = try c.decodeIfPresent(Int.self, forKey: .clientMessageId) {
            self.id = String(n)
        } else if let n = try c.decodeIfPresent(Int.self, forKey: .messageId) {
            self.id = String(n)
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "Missing id"))
        }

        if let t = try c.decodeIfPresent(String.self, forKey: .client_text) {
            self.client_text = t
        } else if let t = try c.decodeIfPresent(String.self, forKey: .content) {
            self.client_text = t
        } else {
            throw DecodingError.keyNotFound(CodingKeys.client_text, .init(codingPath: decoder.codingPath, debugDescription: "Missing content/client_text"))
        }

        self.pitch      = try c.decodeIfPresent(Float.self, forKey: .pitch) ?? 0
        self.volume     = try c.decodeIfPresent(Float.self, forKey: .volume) ?? 0
        self.emotion    = try c.decodeIfPresent(String.self, forKey: .emotion) ?? "neutral"
        self.confidence = try c.decodeIfPresent(Float.self, forKey: .confidence) ?? 0
        self.source     = try c.decodeIfPresent(String.self, forKey: .source) ?? "server"
        self.fontName   = try c.decodeIfPresent(String.self, forKey: .fontName)
        self.emoji      = try c.decodeIfPresent(String.self, forKey: .emoji)

        if let sid = try c.decodeIfPresent(Int.self, forKey: .senderId) {
            self.senderId = sid
        } else if let sidStr = try c.decodeIfPresent(String.self, forKey: .senderId), let sid = Int(sidStr) {
            self.senderId = sid
        } else {
            self.senderId = nil
        }

        self.senderName = try c.decodeIfPresent(String.self, forKey: .senderName) ?? ""
        self.sentAt     = try c.decodeIfPresent(String.self, forKey: .sentAt) ?? ""
        self.roomId     = try c.decodeIfPresent(Int.self, forKey: .roomId)

        // ✅ 스타일 필드 디코딩
        // ✅ 스타일 필드 디코딩 (try? + ?? 체이닝)
        self.transformed_text =
            (try? c.decodeIfPresent(String.self, forKey: .transformed_text)) ??
            (try? c.decodeIfPresent(String.self, forKey: .transformedText))

        self.styleName =
            (try? c.decodeIfPresent(String.self, forKey: .styleName)) ??
            (try? c.decodeIfPresent(String.self, forKey: .style_name)) ??
            (try? c.decodeIfPresent(String.self, forKey: .style))

    }

    func encode(to encoder: Encoder) throws {
        var e = encoder.container(keyedBy: CodingKeys.self)
        try e.encode(id, forKey: .clientMessageId) // 서버에 보낼 때 통일
        try e.encode(client_text, forKey: .content)
        try e.encode(pitch, forKey: .pitch)
        try e.encode(volume, forKey: .volume)
        try e.encode(emotion, forKey: .emotion)
        try e.encode(confidence, forKey: .confidence)
        try e.encode(source, forKey: .source)
        try e.encodeIfPresent(fontName, forKey: .fontName)
        try e.encodeIfPresent(emoji, forKey: .emoji)
        if let senderId = senderId { try e.encode(senderId, forKey: .senderId) }
        try e.encode(senderName, forKey: .senderName)
        try e.encode(sentAt, forKey: .sentAt)
        if let roomId = roomId { try e.encode(roomId, forKey: .roomId) }
        // 필요 시 아래 두 줄로 서버에 스타일 최종본도 싱크 가능
        // try e.encodeIfPresent(transformed_text, forKey: .transformed_text)
        // try e.encodeIfPresent(styleName, forKey: .style_name)
    }
}

// ✨ 편의 생성자: 로컬 임시 버블(draft) 만들 때 사용
extension EmotionResult {
    static func draft(
        text: String,
        currentUserId: Int,
        currentUserName: String? = nil,
        roomId: Int? = nil
    ) -> EmotionResult {
        EmotionResult(
            id: UUID().uuidString,
            client_text: text,
            pitch: 0, volume: 0,
            emotion: "neutral", confidence: 0,
            source: "manual",
            fontName: nil, emoji: "🙂",
            senderId: currentUserId,
            senderName: currentUserName ?? "Me",
            sentAt: ISO8601DateFormatter().string(from: Date()),
            roomId: roomId,
            transformed_text: nil,
            styleName: nil
        )
    }
}






let emotionStyles: [String: EmotionStyle] = [
    "joy": EmotionStyle(
        emoji: "😄", color: .yellow, fontSize: 28,
        font: .custom("Dongle-Bold", size: 28),           // ✅ 존재
        fontName: "Dongle-Bold"
    ),
    "sadness": EmotionStyle(
        emoji: "😢", color: .blue, fontSize: 26,
        font: .custom("ChosunCentennial", size: 26),      // ✅ ChosunCentennial (파일명 아님)
        fontName: "ChosunCentennial"
    ),
    "anger": EmotionStyle(
        emoji: "😡", color: .red, fontSize: 30,
        font: .custom("Giants-Regular", size: 30),        // ✅ 존재
        fontName: "Giants-Regular"
    ),
    "fear": EmotionStyle(
        emoji: "😨", color: .purple, fontSize: 26,
        font: .custom("Yydimibang-OTFBold", size: 26),    // ✅ 덤프에 있음 (Bold만 존재)
        fontName: "Yydimibang-OTFBold"
    ),
    "surprise": EmotionStyle(
        emoji: "😲", color: .orange, fontSize: 28,
        font: .custom("YOnepickTTF-Regular", size: 28),
        fontName: "YOnepickTTF-Regular"
    ),

    "curiosity": EmotionStyle(
        emoji: "🤔", color: .green, fontSize: 24,
        font: .custom("MarkerFelt-Wide", size: 24),
        fontName: "MarkerFelt-Wide"
    ),

    "neutral": EmotionStyle(
        emoji: "🙂", color: .gray, fontSize: 22,
        font: .custom("YOnepickTTF-Regular", size: 22),   // ✅ Onepick은 이 이름이 정답
        fontName: "YOnepickTTF-Regular"
    )
]
