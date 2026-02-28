import AVFoundation
import CoreAudio
import Foundation

class AudioRecorder {
    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var isRecording = false

    func startRecording() {
        guard !isRecording else { return }

        configureInputDevice()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_recording_\(Date().timeIntervalSince1970).wav")
        recordingURL = url

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        do {
            audioFile = try AVAudioFile(forWriting: url,
                                        settings: recordingFormat.settings)
        } catch {
            print("Failed to create audio file: \(error)")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self, let file = self.audioFile else { return }
            do {
                try file.write(from: buffer)
            } catch {
                print("Write error: \(error)")
            }
        }

        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine start error: \(error)")
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioFile = nil
        isRecording = false

        completion(recordingURL)
    }

    // MARK: - Device Selection

    private func configureInputDevice() {
        guard let uid = UserDefaults.standard.string(forKey: "selectedMicUID"),
              !uid.isEmpty,
              let audioUnit = audioEngine.inputNode.audioUnit else { return }

        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfUID = uid as CFString
        var outSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            UInt32(MemoryLayout<CFString>.size),
            &cfUID,
            &outSize,
            &deviceID
        )

        guard deviceID != AudioDeviceID(kAudioObjectUnknown) else { return }
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    static func availableInputDevices() -> [(uid: String, name: String)] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            // Only include devices with input channels
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize)
            guard streamSize >= MemoryLayout<AudioBufferList>.size else { return nil }
            let bufPtr = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufPtr.deallocate() }
            AudioObjectGetPropertyData(id, &streamAddr, 0, nil, &streamSize, bufPtr)
            guard bufPtr.pointee.mNumberBuffers > 0 else { return nil }

            var nameRef = "" as CFString
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &nameRef)

            var uidRef = "" as CFString
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uidSize, &uidRef)

            return (uid: uidRef as String, name: nameRef as String)
        }
    }
}
