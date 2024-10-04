//
//  AudioSessionManager+RouteChange.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation

// MARK: Route changes
// swiftlint:disable line_length
// Doc: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html#//apple_ref/doc/uid/TP40007875-CH5-SW1

extension AudioSessionManager {

    // swiftlint:disable cyclomatic_complexity
    @objc func handleRouteChangeNotification(notification: Notification) {
        guard let payload: NotificationPaylod.RouteChange = .init(notification) else {
            logger?(.error, "Failed to cast route change notification into payload.")
            return
        }

        logger?(.debug, "Route Change Notification. reason: \(payload.reason.description)")

        switch payload.reason {
        case .newDeviceAvailable:
            // A new device has been connected.
            // If recording, we need to stop recording
            // If playing, we need to continue playing in this new device
            debugPrintOutputs(payload: payload, logger: logger)

            switch state {
            case .uninitialized, .error, .configured, .playing, .processing, .stoppingRecording:
                // Nothing to do in those cases
                break

            case .recording:
                stopRecordingAudio(cancelled: true)

            }

        case .oldDeviceUnavailable:
            // A device has been deconnected
            // If recording, we need to stop recording
            // If playing, we need to stop playing
            debugPrintOutputs(payload: payload, logger: logger)

            switch state {
            case .uninitialized, .error, .configured, .processing, .stoppingRecording:
                // Nothing to do in those cases
                break

            case .playing(_, let it, _):
                _ = pausePlayingItem(it)

            case .recording:
                stopRecordingAudio(cancelled: true)

            }

        case .unknown,
                .categoryChange,
                .override,
                .wakeFromSleep,
                .noSuitableRouteForCategory,
                .routeConfigurationChange:
            break

        @unknown default:
            break
        }
        onRouteDidChange()
    }

    func debugPrintOutputs(
        payload: AudioSessionManager.NotificationPaylod.RouteChange,
        logger: Logger?
    ) {
        logger?(.debug, "\(payload.reason)")
        logger?(.debug, "Previous outputs:")
        (payload.previousRouteDescription?.outputs ?? [AVAudioSessionPortDescription]()).forEach {
            logger?(.debug, "\($0)")
        }
        logger?(.debug, "New outputs:")
        debugPrintAudioSessionOutputs(logger: logger)
    }

    func debugPrintAudioSessionOutputs(logger: Logger?) {
        audioSession.currentRoute.outputs.forEach {
            logger?(.debug, "\($0)")
        }
    }

}

extension AudioSessionManager.NotificationPaylod {
    public struct RouteChange {

        public var reason: AVAudioSession.RouteChangeReason
        public var previousRouteDescription: AVAudioSessionRouteDescription?

        init?(_ notification: Notification) {
            guard   notification.name == AVAudioSession.routeChangeNotification,
                    let userInfo = notification.userInfo,
                    let reasonValue: UInt = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                    let reason: AVAudioSession.RouteChangeReason = .init(rawValue: reasonValue)
            else { return nil }

            let previousRouteDescription: AVAudioSessionRouteDescription? = userInfo[
                AVAudioSessionRouteChangePreviousRouteKey
            ] as? AVAudioSessionRouteDescription

            self.reason = reason
            self.previousRouteDescription = previousRouteDescription
        }
    }
}

extension AVAudioSession.RouteChangeReason {
    var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .newDeviceAvailable:
            return "newDeviceAvailable"
        case .oldDeviceUnavailable:
            return "oldDeviceUnavailable"
        case .categoryChange:
            return "categoryChange"
        case .override:
            return "override"
        case .wakeFromSleep:
            return "wakeFromSleep"
        case .noSuitableRouteForCategory:
            return "noSuitableRouteForCategory"
        case .routeConfigurationChange:
            return "routeConfigurationChange"
        @unknown default:
            return "unknown case \(self.rawValue)"
        }
    }
}
