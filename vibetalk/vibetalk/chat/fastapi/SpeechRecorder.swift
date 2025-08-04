import Foundation
import AVFoundation
import Speech
import Combine

class SpeechRecorder: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?

    @Published var recognizedText: String = ""
    @Published var isRecording: Bool = false
    var recordedFileURL: URL?

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        requestPermissions()
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            print("🔑 Speech 권한:", status == .authorized ? "✅" : "❌")
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("🎤 마이크 권한:", granted ? "✅" : "❌")
        }
    }

    func startRecording() {
        recognizedText = ""
        isRecording = true

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                }
            }
            if error != nil {
                self.stopRecording()
            }
        }

        // WAV 파일 녹음
        recordedFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        audioRecorder = try? AVAudioRecorder(url: recordedFileURL!, settings: settings)
        audioRecorder?.record()
    }

    func stopRecording() {
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioRecorder?.stop()
        print("⏹ 녹음 종료")
    }
}
