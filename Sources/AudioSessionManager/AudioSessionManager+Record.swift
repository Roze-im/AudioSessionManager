//
//  AudioSessionManager+Record.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation

extension AudioSessionManager {

    public enum RecordError: Error, LocalizedError {
        case startRecordingFailed(Error?)
        case missingAuthorization
        case wrongState(State)
        case wrongSessionConfiguration(AudioSessionConfiguration)
        case missingAudioRecordingURL

        case resumeRecordingFailed

        // Human readable error title
        public var localizedTitle: String {
            return NSLocalizedString("recorderror.generic.title", bundle: .module, comment: "")
        }

        // LocalizedError protocol, human readable error message
        public var errorDescription: String? {
            switch self {
            case .startRecordingFailed,
                    .resumeRecordingFailed,
                    .missingAudioRecordingURL,
                    .wrongSessionConfiguration:
                return NSLocalizedString("recorderror.generic.message", bundle: .module, comment: "")
                
            case .missingAuthorization:
                return NSLocalizedString("configurationerror.missingMicrophoneAuthorization.message", bundle: .module, comment: "")

            case .wrongState(let state):
                switch state {
                case .error(_, let error):
                    switch error {
                    case let configurationError as ConfigurationError:
                        return configurationError.localizedDescription

                    default:
                        return NSLocalizedString("recorderror.generic.message", bundle: .module, comment: "")
                    }
                default:
                    return NSLocalizedString("recorderror.generic.message", bundle: .module, comment: "")

                }
            }
        }

        // Debugging purpose
        var debugDescription: String {
            switch self {
            case .startRecordingFailed(let error):
                return "Start recording failed: \(String(describing: error?.localizedDescription))"
            case .resumeRecordingFailed:
                return "Resume recording failed"
            case .missingAuthorization:
                return "Missing microphone authorization"
            case .wrongState(let state):
                return "Wrong state \(String(describing: state))"
            case .wrongSessionConfiguration(let sessionConfiguration):
                return "Wrong session configuration \(sessionConfiguration.category)"
            case .missingAudioRecordingURL:
                return "No url to record to"
            }
        }
    }

    static let audioRecordSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC, // mp4 format
        AVSampleRateKey: 44100, // 8kHz is the rate that land-line telephones use
        AVNumberOfChannelsKey: 1, //
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    public var currentRecordDuration: TimeInterval? {
        switch state {
        case .recording(_, _, _, let previousRecordingDuration, let startTimestamp, _):
            return previousRecordingDuration + Date().timeIntervalSince1970 - startTimestamp
        default:
            return nil
        }
    }

    public func startRecordingAudio(durationLimit: TimeInterval?) -> Error? {
        logger?(.debug, "Start recording audio")
        // Do we have the microphone authorization ?
        guard hasRecordPermission else {
            let error = RecordError.missingAuthorization
            logger?(.error, error.debugDescription)
            return error
        }

        // Are we in a state allowing us to start a record ?
        if case .playing(_, let it, _) = state {
            stopPlayingItem(it, deactivateSession: false)
        }

        reconfigureAudioSessionIfNeeded()

        guard case .configured(let sessionConfiguration) = state else {
            let error = RecordError.wrongState(state)
            logger?(.error, error.debugDescription)
            return error
        }

        // Is our session correctly configured ?
        guard sessionConfiguration.category == .record || sessionConfiguration.category == .playAndRecord else {
            let error = RecordError.wrongSessionConfiguration(sessionConfiguration)
            logger?(.error, error.debugDescription)
            return error
        }

        // Get a location to record to
        guard let url = dataSource?.audioSessionManagerAudioRecordingURL(self) else {
            let error = RecordError.missingAudioRecordingURL
            logger?(.error, error.debugDescription)
            return error
        }

        // Everything's fine, let's create a recorder.
        do {
            let recorder: AVAudioRecorder = try .init(
                url: url,
                settings: Self.audioRecordSettings
            )
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            // Activate session
            try activateSession()

            let recordStarted = durationLimit.map { recorder.record(forDuration: $0) } ?? recorder.record()
            if recordStarted {
                logger?(.debug, "Start recording succeed")
                self.state = .recording(
                    sessionConfiguration: sessionConfiguration,
                    recorder: recorder,
                    paused: false,
                    previousRecordingDuration: 0,
                    startTimestamp: Date().timeIntervalSince1970,
                    durationLimit: durationLimit
                )
                delegate?.audioSessionManagerDidStartRecording(self)
                return nil
            } else {
                // This can happens if:
                // - we set wrong recorder settings
                // - ... please add any other case you encounter
                let error = RecordError.startRecordingFailed(nil)
                logger?(.error, error.debugDescription)
                return error
            }
        } catch {
            let error = RecordError.startRecordingFailed(error)
            logger?(.error, error.debugDescription)
            return error
        }
    }

    public func pauseRecordingAudio() {
        logger?(.debug, "Pause recording audio")
        guard case .recording(let sessionConfiguration, let recorder, let paused, let previousRecordingDuration, let startTimestamp, let durationLimit) = state, paused == false else {
            logger?(.error, "Cannot pause recording audio, wrong state \(String(describing: state))")
            return
        }
        recorder.pause()
        self.state = .recording(
            sessionConfiguration: sessionConfiguration,
            recorder: recorder,
            paused: true,
            previousRecordingDuration: previousRecordingDuration + Date().timeIntervalSince1970 - startTimestamp,
            startTimestamp: startTimestamp,
            durationLimit: durationLimit
        )
    }

    public func stopRecordingAudio(cancelled: Bool) {
        logger?(.debug, "Stop recording audio")
        guard case .recording(let sessionConfiguration, let recorder, _, _, let startedAt, _) = state else {
            let error = RecordError.wrongState(state)
            logger?(.error, error.debugDescription)
            return
        }

        state = .stoppingRecording(
            sessionConfiguration: sessionConfiguration,
            recorder: recorder,
            startTimestamp: startedAt,
            cancelled: cancelled
        )
        recorder.stop()
    }

    public func getRecorderAveragePower() -> Float? {
        guard case .recording(_, let recorder, _, _, _, _) = state else {
            logger?(.debug, "Cannot get dB, wrong state \(String(describing: state))")
            return nil
        }

        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

}

extension AudioSessionManager: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        switch state {
        case .recording(let sessionConfiguration, _, _, _, let startedAt, _):
            audioRecorderDidFinishRecording(
                sessionConfiguration: sessionConfiguration,
                recorder: recorder,
                startedAt: startedAt,
                cancelled: !flag
            )
        case .stoppingRecording(let sessionConfiguration, _, let startedAt, let cancelled):
            audioRecorderDidFinishRecording(
                sessionConfiguration: sessionConfiguration,
                recorder: recorder,
                startedAt: startedAt,
                cancelled: cancelled || !flag
            )
        default:
            break
        }
    }

    private func audioRecorderDidFinishRecording(
        sessionConfiguration: AudioSessionConfiguration,
        recorder: AVAudioRecorder,
        startedAt: TimeInterval,
        cancelled: Bool
    ) {
        var duration: TimeInterval = 0
        do {
            let player: AVAudioPlayer = try .init(contentsOf: recorder.url)
            duration = player.duration
        } catch {
            logger?(.error, "Failed to generate player \(error)")
        }

        let metadata: AudioMetadata = .init(
            duration: duration,
            mimeType: "audio/mp4",
            createdAt: Date(timeIntervalSince1970: startedAt)
        )

        deactivateSessionAndNotifyOthers()

        state = .configured(sessionConfiguration: sessionConfiguration)

        let output: (url: URL, metadata: AudioMetadata)? = {
            if cancelled {
                do {
                    try FileManager.default.removeItem(at: recorder.url)
                } catch {
                    logger?(.error, "Failed to remove item at \(recorder.url) \(error)")
                }
                return nil
            }
            return (url: recorder.url, metadata: metadata)
        }()

        delegate?.audioSessionManagerDidStopRecording(
            self,
            cancelled: cancelled,
            output: output
        )
    }
}
