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
//struct EmotionResult: Identifiable, Codable {
//    let id: Int  // ✅ 이 필드를 추가
//    let client_text: String
//    let pitch: Float
//    let volume: Float
//    let emotion: String
//    let confidence: Float
//    let source: String
//    let fontName: String?
//    
//    var font: Font?
//
//    private enum CodingKeys: String, CodingKey {
//        case id, client_text, pitch, volume, emotion, confidence, source, fontName
//        // font는 Codable에서 제외됨
//    }
//}
struct EmotionResult: Codable, Identifiable, Equatable {
    var id: Int = UUID().hashValue
    
    let client_text: String
    let pitch: Float
    let volume: Float
    let emotion: String
    let confidence: Float
    let source: String
    var fontName: String?   // ✅ 바뀔 수 있으므로 var로
    var emoji: String?        // ✅ 추가
    let font: Font? = nil

    enum CodingKeys: String, CodingKey {
        case client_text, pitch, volume, emotion, confidence, source, fontName, emoji  // ✅ 추가
    }

    static func == (lhs: EmotionResult, rhs: EmotionResult) -> Bool {
        return lhs.id == rhs.id
    }
}









let emotionStyles: [String: EmotionStyle] = [
    "joy": EmotionStyle(emoji: "😄", color: .yellow, fontSize: 28,font: .custom("YOnepick-Regular", size:28), fontName: "YOnepick-Regular"),
    "sadness": EmotionStyle(emoji: "😢", color: .blue, fontSize: 26, font: .custom("ChosunCentennial_ttf", size:26), fontName: "ChosunCentennial_ttf"),
    "anger": EmotionStyle(emoji: "😡", color: .red, fontSize: 30, font: .custom("Giants-Regular", size:30), fontName: "Giants-Regular"),
    "fear": EmotionStyle(emoji: "😨", color: .purple, fontSize: 26,font: .custom("YOnepick-Regular", size:26), fontName: "YOnepick-Regular"),
    "surprise": EmotionStyle(emoji: "😲", color: .orange, fontSize: 28,  font: .custom("YOnepick-Regular", size:28), fontName: "YOnepick-Regular"),
    "curiosity": EmotionStyle(emoji: "🤔", color: .green, fontSize: 24, font: .custom("YOnepick-Regular", size:24), fontName: "YOnepick-Regular"),
    "neutral": EmotionStyle(emoji: "🙂", color: .gray, fontSize: 22, font: .custom("YOnepick-Regular", size:22), fontName: "YOnepick-Regular")
]

