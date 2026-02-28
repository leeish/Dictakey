import Foundation
import WhisperKit

class WhisperTranscriber {
    private var whisperKit: WhisperKit?
    var isModelLoaded = false

    // Called on the main thread during load.
    // .downloading(fraction) → actively downloading (0–1)
    // .loading              → download done, initialising model in memory
    enum LoadPhase { case downloading(Double), loading }
    var onPhaseChange: ((LoadPhase) -> Void)?

    func loadModel() async {
        let modelName = UserDefaults.standard.string(forKey: "whisperModel") ?? "base"
        isModelLoaded = false
        whisperKit = nil

        do {
            // WhisperKit.download() is a no-op if the model is already cached,
            // so progress will jump straight to 1.0 on repeat loads.
            let modelFolder = try await WhisperKit.download(
                variant: modelName,
                progressCallback: { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.onPhaseChange?(.downloading(progress.fractionCompleted))
                    }
                }
            )

            // Download finished — now load into memory
            DispatchQueue.main.async { self.onPhaseChange?(.loading) }

            whisperKit = try await WhisperKit(modelFolder: modelFolder.path)
            isModelLoaded = true
            print("WhisperKit model ready: \(modelName)")
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
