import Foundation
import WhisperKit

class WhisperTranscriber {
    private var whisperKit: WhisperKit?
    var isModelLoaded = false

    // Model size options: "tiny", "base", "small", "medium", "large-v3"
    // "base" is a great balance of speed and accuracy for most Macs
    let modelName = "base"

    func loadModel() async {
        do {
            print("Loading WhisperKit model: \(modelName)")
            whisperKit = try await WhisperKit(model: modelName)
            isModelLoaded = true
            print("WhisperKit model loaded successfully")
        } catch {
            print("Failed to load WhisperKit model: \(error)")
        }
    }

    func transcribe(audioURL: URL) async -> String {
        guard let whisperKit else {
            print("WhisperKit not loaded")
            return ""
        }

        do {
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)
            let text = results.map { $0.text }.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean up temp file
            try? FileManager.default.removeItem(at: audioURL)

            print("Transcribed: \(text)")
            return text
        } catch {
            print("Transcription error: \(error)")
            return ""
        }
    }
}
