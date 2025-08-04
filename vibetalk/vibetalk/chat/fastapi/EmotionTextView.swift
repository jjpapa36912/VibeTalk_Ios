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
            Text("\(style.emoji) \(result.whisper_text)")
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
}
struct EmotionResult: Codable {
    let client_text: String
    let whisper_text: String
    let pitch: Double
    let volume: Double
    let emotion: String
    let confidence: Double
}

let emotionStyles: [String: EmotionStyle] = [
    "joy": EmotionStyle(emoji: "😄", color: .yellow, fontSize: 28),
    "sadness": EmotionStyle(emoji: "😢", color: .blue, fontSize: 26),
    "anger": EmotionStyle(emoji: "😡", color: .red, fontSize: 30),
    "fear": EmotionStyle(emoji: "😨", color: .purple, fontSize: 26),
    "surprise": EmotionStyle(emoji: "😲", color: .orange, fontSize: 28),
    "curiosity": EmotionStyle(emoji: "🤔", color: .green, fontSize: 24),
    "neutral": EmotionStyle(emoji: "🙂", color: .gray, fontSize: 22)
]
