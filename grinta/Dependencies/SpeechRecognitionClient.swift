@preconcurrency import AVFoundation
import ComposableArchitecture
import Foundation
@preconcurrency import Speech

enum SpeechRecognitionClientError: Error {
    case speechRecognizerUnavailable
    case audioEngineError(String)
}

final class SpeechRecognitionClientImpl: @unchecked Sendable {
    let audioEngine = AVAudioEngine()
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    var lastSpeechTime = Date()
    var lastString = ""

    private var operationQueue = DispatchQueue(label: "com.grinta.speechrecognitionclientimpl")

    func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                switch authStatus {
                case .authorized:
                    continuation.resume(returning: ())
                case .denied, .restricted, .notDetermined:
                    continuation.resume(throwing: SpeechRecognitionClientError.speechRecognizerUnavailable)
                @unknown default:
                    continuation.resume(throwing: SpeechRecognitionClientError.speechRecognizerUnavailable)
                }
            }
        }
    }

    func startRecording() async throws -> AsyncStream<String> {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionClientError.audioEngineError(error.localizedDescription)
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true

        operationQueue.sync {
            self.recognitionRequest = recognitionRequest
        }

        let inputNode = audioEngine.inputNode

        let stream = AsyncStream<String> { continuation in
            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result {
                    if result.bestTranscription.formattedString != self.lastString {
                        self.lastSpeechTime = Date()
                        self.lastString = result.bestTranscription.formattedString
                        continuation.yield(result.bestTranscription.formattedString)
                    }
                }

                if error != nil || result?.isFinal ?? false {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    continuation.finish()
                }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)

                let quietDuration = Date().timeIntervalSince(self.lastSpeechTime)
                let didInitialTimePass = self.lastString == "" && quietDuration >= 3
                let didPostSpeechTimePass = self.lastString != "" && quietDuration >= 1.5

                if didInitialTimePass || didPostSpeechTimePass {
                    continuation.finish()
                    self.stopRecording()
                }
            }

            self.audioEngine.prepare()

            do {
                try self.audioEngine.start()
                lastString = ""
                lastSpeechTime = Date()
            } catch {
                continuation.finish()
            }

            continuation.onTermination = { [recognitionRequest, audioEngine, recognitionTask] _ in
                audioEngine.stop()
                recognitionRequest.endAudio()
                recognitionTask?.cancel()
            }
        }

        return stream
    }

    func stopRecording() {
        operationQueue.sync {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()

            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Error deactivating audio session: \(error.localizedDescription)")
            }
        }
    }
}

@DependencyClient
struct SpeechRecognitionClient {
    var requestAuthorization: @Sendable () async throws -> Void
    var startRecording: @Sendable () async throws -> AsyncStream<String>
    var stopRecording: @Sendable () -> Void
}

extension SpeechRecognitionClient: DependencyKey {
    static let liveValue: Self = {
        // Store the AVAudioEngine and related state in this instance
        let clientImpl = SpeechRecognitionClientImpl()
        return Self(
            requestAuthorization: { try await clientImpl.requestAuthorization() },
            startRecording: { try await clientImpl.startRecording() },
            stopRecording: { clientImpl.stopRecording() }
        )
    }()
}
