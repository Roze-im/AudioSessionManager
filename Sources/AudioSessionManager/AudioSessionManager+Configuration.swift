//
//  AudioSessionManager+Configuration.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation
import UIKit

extension AudioSessionManager {

    public enum ConfigurationError: Error, LocalizedError {
        case missingMicrophoneAuthorization
        case failedToActivateSession(error: Error?)
        case mediaServiceWereLost
        case failedToOverrideOutputPort(error: Error?)

        public var errorDescription: String? {
            switch self {
            case .missingMicrophoneAuthorization:
                return NSLocalizedString("configurationerror.missingMicrophoneAuthorization.message", bundle: .module, comment: "")
            case .failedToActivateSession:
                return NSLocalizedString("configurationerror.failedToActivateSession.message", bundle: .module, comment: "")
            case .mediaServiceWereLost:
                return NSLocalizedString("configurationerror.mediaServiceWereLost.message", bundle: .module, comment: "")
            case .failedToOverrideOutputPort:
                return NSLocalizedString("configurationerror.failedToOverrideOutputPort.message", bundle: .module, comment: "")
            }
        }
    }

    public struct AudioSessionConfiguration: Equatable {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions

        static let defaultMode: AVAudioSession.Mode = .default
        // Note from doc:
        // If allowBluetoothA2DP and the allowBluetooth option are both set,
        // when a single device supports both the Hands-Free Profile (HFP) and A2DP,
        // the system gives hands-free ports a higher priority for routing.
        static let playAndRecordOptions: AVAudioSession.CategoryOptions = [
            .allowBluetoothA2DP,
            .allowBluetooth,
        ]
        static let playbackOptions: AVAudioSession.CategoryOptions = []
    }

    // MARK: Set of configurations
    // Playback
    private static let playbackConfiguration: AudioSessionConfiguration = .init(
        category: .playback,
        mode: AudioSessionConfiguration.defaultMode,
        options: AudioSessionConfiguration.playbackOptions
    )

    // Play and record
    private static let playAndRecordConfiguration: AudioSessionConfiguration = .init(
        category: .playAndRecord,
        mode: AudioSessionConfiguration.defaultMode,
        options: AudioSessionConfiguration.playAndRecordOptions
    )

    internal func reconfigureAudioSessionIfNeeded(force: Bool = false) {
        let configuration: AudioSessionConfiguration = hasRecordPermission
        ? Self.playAndRecordConfiguration
        : Self.playbackConfiguration

        if !force,
           case .configured(let currentConfiguration) = state,
           currentConfiguration == configuration {
            logger?(.debug, "Session already configured")
            return
        }

        // Configure the session, but do not activate it to not stop other running sessions (eg Music app)
        self.state = configureAudioSession(
            audioSession,
            with: configuration,
            hasRecordPermission: hasRecordPermission,
            logger: logger
        )
    }

    // Note: deactivating the session before re-configuring it seems to be non-mandatory.
    private func configureAudioSession(
        _ audioSession: AVAudioSession,
        with configuration: AudioSessionConfiguration,
        hasRecordPermission: Bool,
        logger: Logger?
    ) -> State {
        logger?(.debug, "Configuring audio session")

        // We should not continue if we're trying to set a category containing
        // the record option without having the permission to record.
        // Doing so does not fail, but create empty audio files when recording.
        switch (configuration.category, hasRecordPermission) {
        case (.record, false),
            (.playAndRecord, false):
            return .error(
                sessionConfiguration: nil,
                error: ConfigurationError.missingMicrophoneAuthorization
            )
        default:
            break
        }

        do {
            try audioSession.setCategory(
                configuration.category,
                mode: configuration.mode,
                options: configuration.options
            )
            try computeAndUpdatePortOverride(logger: logger)
            return .configured(sessionConfiguration: configuration)
        } catch {
            logger?(.error, "Failed to configure audio session: \(error)")
            return .error(
                sessionConfiguration: nil,
                error: error
            )
        }
    }

    // MARK: Session activation
    internal func activateSession() throws {
        do {
            try audioSession.setActive(true)
            logger?(.debug, "Activated audio session")
        } catch {
            throw ConfigurationError.failedToActivateSession(error: error)
        }
    }

    // MARK: Session deactivation
    internal func deactivateSessionAndNotifyOthers() {
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            logger?(.debug, "Deactivated audio session")
        } catch {
            logger?(.error, "Failed to deactivate session: \(error)")
        }
    }

    /// Sometimes the played item won't deactivate the session once finished playing.
    /// This is a parameter set in AudioSessionManager.AudioItem
    /// In this case, the caller is responsible of the session deactivation.
    public func deactivateSessionAndNotifyOthersIfNeeded() {
        guard case .configured = state else { return }
        deactivateSessionAndNotifyOthers()
    }

    // MARK: Output Audio Port override
    internal func computeAndUpdatePortOverride(logger: Logger?) throws {
        logger?(.debug, "Compute PortOverride and update session")
        guard audioSession.category == .playAndRecord else {
            logger?(
                .debug,
                """
                … cannot override output port if session's category is not .playAndRecord.
                returning without modification."
                """
            )
            return
        }

        // port = .builtInReceiver = ear speaker
        let proximityState: Bool = UIDevice.current.proximityState
        let isHeadphonesConnected = isHeadphonesConnected()

        logger?(.debug, "… isHeadphonesConnected: \(isHeadphonesConnected)")
        logger?(.debug, "… proximityState: \(proximityState)")

        var portOverride: AVAudioSession.PortOverride
        switch (isHeadphonesConnected, proximityState) {
        case (true, _):
            // Headphone connected, do not override port
            portOverride = .none
        case (false, true):
            // Headphone not connected, proximityState = true,
            // override to .none in order to use the .builtInReceiver port (aka 'ear speaker')
            portOverride = .none
        case (false, false):
            // Headphone not connected, proximityState = true, override to .speaker to force the use
            portOverride = .speaker
        }

        do {
            logger?(.debug, "… trying to override Output Audio Port to \(portOverride.readableDescription)")
            try audioSession.overrideOutputAudioPort(portOverride)
            logger?(.debug, "… success overriding Output Audio Port to \(portOverride.readableDescription)")
        } catch {
            logger?(
                .error,
                """
                … failed overriding Output Audio Port to \(portOverride.readableDescription).
                Error: \(error)
                """
            )
            throw(ConfigurationError.failedToOverrideOutputPort(error: error))
        }
    }

    internal func isHeadphonesConnected() -> Bool {
        switch audioSessionOutputPortType {
        case .none:
            return false

        case .builtInReceiver?,
                .builtInSpeaker?:
            return false

        case .airPlay?,
                .bluetoothA2DP?,
                .bluetoothLE?,
                .bluetoothHFP?,
                .HDMI?,
                .headphones?,
                .lineOut?:
            return true

        default:
            return false

        }
    }

    func onRouteDidChange() {
        do {
            try computeAndUpdatePortOverride(logger: logger)
        } catch {
            self.state = .error(
                sessionConfiguration: state.sessionConfiguration,
                error: ConfigurationError.failedToOverrideOutputPort(error: error)
            )
        }

        delegate?.audioSessionManagerDidUpdateState(self)
    }
}
