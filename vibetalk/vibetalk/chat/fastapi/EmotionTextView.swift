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
    let senderId: Int?         // ✅ 추가
    let senderName: String
    let sentAt: String

    enum CodingKeys: String, CodingKey {
        case id, client_text, pitch, volume, emotion, confidence, source, fontName, emoji, senderId, senderName, sentAt
    }

    // 멤버와이즈 생성자, init(from:)에서도 senderId 디코딩
    init(
        id: String,
        client_text: String,
        pitch: Float,
        volume: Float,
        emotion: String,
        confidence: Float,
        source: String,
        fontName: String?,
        emoji: String?,
        senderId: Int?,        // ✅ 추가
        senderName: String,
        sentAt: String
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.client_text = try container.decode(String.self, forKey: .client_text)
        self.pitch = try container.decode(Float.self, forKey: .pitch)
        self.volume = try container.decode(Float.self, forKey: .volume)
        self.emotion = try container.decode(String.self, forKey: .emotion)
        self.confidence = try container.decode(Float.self, forKey: .confidence)
        self.source = try container.decode(String.self, forKey: .source)
        self.fontName = try container.decodeIfPresent(String.self, forKey: .fontName)
        self.emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        self.senderId = try container.decodeIfPresent(Int.self, forKey: .senderId)  // ✅ 추가
        self.senderName = try container.decode(String.self, forKey: .senderName)
        self.sentAt = try container.decode(String.self, forKey: .sentAt)
    }

    static func == (lhs: EmotionResult, rhs: EmotionResult) -> Bool {
        lhs.id == rhs.id
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
