//
//  AudioSessionManager.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 17/04/2023.
//

import Foundation
import AVFoundation

public protocol AudioSessionManagerDataSource: AnyObject {
    func audioSessionManagerAudioRecordingURL(
        _ manager: AudioSessionManager
    ) -> URL
}

public protocol AudioSessionManagerDelegate: AnyObject {
    func audioSessionManagerDidUpdateState(_ manager: AudioSessionManager)
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didStartPlaying item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didStopPlaying item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didPausePlaying item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didFinishPlaying item: AudioSessionManager.AudioItem
    )

    func audioSessionManagerDidStartRecording(
        _ manager: AudioSessionManager
    )
    func audioSessionManagerDidStopRecording(
        _ manager: AudioSessionManager,
        cancelled: Bool,
        output: (url: URL, metadata: AudioSessionManager.AudioMetadata)?
    )

    func audioSessionManager(
        _ manager: AudioSessionManager,
        didStartProcessing item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didFinishProcessing item: AudioSessionManager.AudioItem,
        hasRemainingItems: Bool
    )
}

public class AudioSessionManager: NSObject {

    public struct AudioMetadata {
        public var duration: TimeInterval
        public let mimeType: String
        public let createdAt: Date
    }

    public enum State {
        case uninitialized
        case error(sessionConfiguration: AudioSessionConfiguration?, error: Error)
        case configured(sessionConfiguration: AudioSessionConfiguration)
        case recording(
            sessionConfiguration: AudioSessionConfiguration,
            recorder: AVAudioRecorder,
            paused: Bool,
            previousRecordingDuration: TimeInterval,
            startTimestamp: TimeInterval,
            durationLimit: TimeInterval?
        )
        case stoppingRecording(
            sessionConfiguration: AudioSessionConfiguration,
            recorder: AVAudioRecorder,
            startTimestamp: TimeInterval,
            cancelled: Bool
        )
        case playing(sessionConfiguration: AudioSessionConfiguration, item: AudioItem, paused: Bool)
        case processing(sessionConfiguration: AudioSessionConfiguration, items: [AudioItem])

        var sessionConfiguration: AudioSessionConfiguration? {
            switch self {
            case .uninitialized:
                return nil
            case .error(let sessionConfiguration, _):
                return sessionConfiguration
            case .configured(let sessionConfiguration),
                .recording(let sessionConfiguration, _, _, _, _, _),
                .stoppingRecording(let sessionConfiguration, _, _, _),
                .playing(let sessionConfiguration, _, _),
                .processing(let sessionConfiguration, _):
                return sessionConfiguration
            }
        }

        var error: Error? {
            switch self {
            case .error(_, let error):
                return error
            default:
                return nil
            }
        }
    }

    public weak var delegate: AudioSessionManagerDelegate?
    public weak var dataSource: AudioSessionManagerDataSource?

    public var state: State = .uninitialized {
        didSet {
            assert(Thread.isMainThread, "state modified in a background thread")
            onStateDidUpdate()
        }
    }

    internal var audioSession: AVAudioSession = .sharedInstance()

    var isProximitySensorAvailable: Bool = false

    // MARK: Computed properties
    public var hasRecordPermission: Bool {
        switch audioSession.recordPermission {
        case .undetermined, .denied:
            return false
        case .granted:
            return true
        @unknown default:
            assertionFailure("Unmanaged recordPermission")
            return false
        }
    }

    public var recordPermission: AVAudioSession.RecordPermission {
        return audioSession.recordPermission
    }

    public var audioSessionOutputPortType: AVAudioSession.Port? {
        return audioSession.currentRoute.outputs.first?.portType
    }

    public var audioSessionInputPortType: AVAudioSession.Port? {
        return audioSession.currentRoute.inputs.first?.portType
    }

    public typealias Logger = ((LogLevel, String) -> Void)

    public enum LogLevel {
        case trace
        case debug
        case error
    }
    var logger: Logger?

    public func configure(
        logger: Logger?,
        delegate: AudioSessionManagerDelegate,
        dataSource: AudioSessionManagerDataSource
    ) {
        logger?(.debug, "Configuring AudioSessionManager")
        self.logger = logger
        self.delegate = delegate
        self.dataSource = dataSource
        logger?(.debug, "Checking if proximity sensor is available")
        self.isProximitySensorAvailable = Self.checkIfProximitySensorIsAvailable()
        logger?(.debug, "… isProximitySensorAvailable: \(isProximitySensorAvailable)")
        reconfigureAudioSessionIfNeeded()
        observeAudioNotifications()
        logger?(.debug, "AudioSessionManager is configured.")
        logger?(.debug, "\(debugDescription())")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avPlayerDidFinishPlaying),
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avPlayerDidFailPlayingToEnd),
            name: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        audioSession.requestRecordPermission { granted in
            DispatchQueue.main.async { [weak self] in
                self?.reconfigureAudioSessionIfNeeded()
                completion(granted)
            }
        }
    }

    private func onStateDidUpdate() {
        logger?(.debug, "AudioSessionManager state did change to \(String(describing: state.readableDescription))")
        if case .error(_, let error) = state {
            logger?(
                .error,
                """
                AudioSessionManager is in error state.
                Error: \(error)
                debugDescription: \(debugDescription())
                """
            )
        }
        observeProximitySensorNotificationIfNeeded()

        delegate?.audioSessionManagerDidUpdateState(self)
    }

    public func debugDescription() -> String {
        return """
            - Mic authorization: \(hasRecordPermission)
            - Session configuration: \n\(state.sessionConfiguration?.readableDescription ?? "")
            - State: \(state.readableDescription)
            - Output port: \(audioSessionOutputPortType?.readableDescription ?? "")
            - Input port: \(audioSessionInputPortType?.readableDescription ?? "")
            - Error: \(state.error?.localizedDescription ?? "none")
        """
    }
}
