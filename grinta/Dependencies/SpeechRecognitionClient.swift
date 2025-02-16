@preconcurrency import AVFoundation
import ComposableArchitecture
import Foundation
import NaturalLanguage
@preconcurrency import Speech

final class SpeechRecognitionService: @unchecked Sendable {
    let audioEngine = AVAudioEngine()
    var recognitionRequests: [SFSpeechAudioBufferRecognitionRequest] = []
    var recognitionTasks: [SFSpeechRecognitionTask] = []
    var speechRecognizers: [SFSpeechRecognizer] = []
    private var languageRecognizers: [Locale: NLLanguageRecognizer] = [:]
    private var operationQueue = DispatchQueue(label: "com.grinta.speechrecognitionclientimpl")

    init() {
        setupRecognizers()
    }

    private func setupRecognizers() {
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        let preferredLanguageIDs = Set(Locale.preferredLanguages)

        speechRecognizers = supportedLocales
            .filter { preferredLanguageIDs.contains($0.identifier) }
            .compactMap { SFSpeechRecognizer(locale: $0) }

        // Pre-configure language recognizers for each supported locale
        for recognizer in speechRecognizers {
            let languageRecognizer = NLLanguageRecognizer()
            if let languageCode = recognizer.locale.language.languageCode?.identifier {
                languageRecognizer.languageConstraints = [NLLanguage(languageCode)]
                languageRecognizer.languageHints = [NLLanguage(languageCode): 1.0]
            }
            languageRecognizers[recognizer.locale] = languageRecognizer
        }

        print("Initialized speech recognizers for locales: \(speechRecognizers.map(\.locale.identifier))")
    }

    func requestAuthorization() async throws {
        guard !speechRecognizers.isEmpty else {
            throw SpeechRecognitionClientError.noSupportedLocales
        }

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
        recognitionTasks.forEach { $0.cancel() }
        recognitionTasks = []

        try initializeAudioSession()

        recognitionRequests = (0 ..< speechRecognizers.count).map { _ in
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            return request
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let localeResults = LocaleResults()
        let speechTimer = SpeechTimer()

        return AsyncStream<String> { continuation in
            Task {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        // Check if should stop recording
                        group.addTask {
                            while await speechTimer.shouldStopRecording() {
                                try Task.checkCancellation()
                                try await Task.sleep(for: .milliseconds(50))

                                self.recognitionTasks.forEach { $0.cancel() }
                                continuation.finish()
                            }
                        }

                        // Add a task for each supported locale
                        for (index, recognizer) in speechRecognizers.enumerated() {
                            let request = self.recognitionRequests[index]
                            let recognitionResults = AsyncStream<RecognitionResult> { continuation in

                                let task = recognizer.recognitionTask(with: request) { result, _ in
                                    if let result {
                                        let languageRecognizer = self.languageRecognizers[recognizer.locale]
                                        // Although we could have gotten a result from the recognizer
                                        // it doesn't mean it's good quality in the target language.
                                        // Use NLP to get a confidence of that language.
                                        languageRecognizer?.reset()
                                        languageRecognizer?.processString(result.bestTranscription.formattedString)
                                        let languageHypothesis = languageRecognizer?.languageHypotheses(withMaximum: 1).first

                                        let currentResult = RecognitionResult(
                                            text: result.bestTranscription.formattedString,
                                            confidence: Float(languageHypothesis?.value ?? 0),
                                            locale: recognizer.locale
                                        )
                                        continuation.yield(currentResult)
                                    }

                                    if Task.isCancelled {
                                        self.recognitionTasks.forEach { $0.cancel() }
                                        continuation.finish()
                                    }
                                }
                                self.recognitionTasks.append(task)
                            }

                            group.addTask { [locale = recognizer.locale] in
                                for await result in recognitionResults {
                                    guard Task.isCancelled == false else {
                                        continuation.finish()
                                        break
                                    }
                                    await localeResults.update(result, for: locale)
                                }
                            }
                        }

                        group.addTask {
                            while await speechTimer.shouldStopRecording() == false, Task.isCancelled == false {
                                try Task.checkCancellation()
                                try await Task.sleep(for: .milliseconds(100))

                                // Pick the result with the highest confidence of being a query
                                // in a given language.
                                if let bestResult = await localeResults.highestConfidenceResult() {
                                    let currentText = await speechTimer.lastEmittedText

                                    if bestResult.text != currentText {
                                        await speechTimer.updateLastEmittedText(bestResult.text, at: Date())
                                        continuation.yield(bestResult.text)
                                    }
                                }
                            }

                            continuation.finish()
                        }

                        try await group.waitForAll()
                    }
                } catch {
                    print(error)

                    continuation.finish()
                    stopRecording()
                }
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequests.forEach { $0.append(buffer) }
            }

            audioEngine.prepare()

            do {
                try audioEngine.start()
            } catch {
                continuation.finish()
            }

            continuation.onTermination = { [weak self] _ in
                self?.stopRecording()
            }
        }
    }

    func stopRecording() {
        operationQueue.sync {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)

            recognitionRequests.forEach { $0.endAudio() }
            recognitionTasks.forEach { $0.cancel() }

            recognitionRequests = []
            recognitionTasks = []

            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Error deactivating audio session: \(error.localizedDescription)")
            }
        }
    }

    private func initializeAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionClientError.audioEngineError(error.localizedDescription)
        }
    }
}

enum SpeechRecognitionClientError: Error {
    case speechRecognizerUnavailable
    case audioEngineError(String)
    case noSupportedLocales
}

private struct RecognitionResult: Comparable {
    let text: String
    let confidence: Float
    let locale: Locale

    static func < (lhs: RecognitionResult, rhs: RecognitionResult) -> Bool {
        lhs.confidence < rhs.confidence
    }
}

private actor LocaleResults {
    private var results: [Locale: RecognitionResult] = [:]

    func update(_ result: RecognitionResult, for locale: Locale) {
        results[locale] = result
    }

    func highestConfidenceResult() -> RecognitionResult? {
        results.values.max()
    }

    func clear() {
        results.removeAll()
    }
}

private actor SpeechTimer {
    private var lastSpeechTime = Date()
    private(set) var lastEmittedText = ""

    func updateLastEmittedText(_ text: String, at date: Date) {
        lastEmittedText = text
        lastSpeechTime = date
    }

    func shouldStopRecording() -> Bool {
        let quietDuration = Date().timeIntervalSince(lastSpeechTime)
        let didInitialTimePass = lastEmittedText.isEmpty && quietDuration >= 3
        let didPostSpeechTimePass = !lastEmittedText.isEmpty && quietDuration >= 1.5
        return didInitialTimePass || didPostSpeechTimePass
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
        let service = SpeechRecognitionService()
        return Self(
            requestAuthorization: { try await service.requestAuthorization() },
            startRecording: { try await service.startRecording() },
            stopRecording: { service.stopRecording() }
        )
    }()
}
