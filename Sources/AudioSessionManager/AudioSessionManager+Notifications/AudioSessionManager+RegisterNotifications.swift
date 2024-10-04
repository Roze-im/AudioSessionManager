//
//  AudioSessionManager+Notifications.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation
import UIKit

// MARK: Audio session related notifications
extension AudioSessionManager {
    /// A struct used as a namespace for audio notification payloads
    struct NotificationPaylod { }

    internal func observeAudioNotifications() {
        // Interruption
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruptionNotification),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )

        // Media service
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServiceWereLost),
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: audioSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServiceWereReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession
        )

        // Route change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChangeNotification),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )

        // Note: Deactivated as we do not need it for now.
        // Spatial playback capability
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleSpatialPlaybackCapabilitiesChangedNotification),
//            name: AVAudioSession.spatialPlaybackCapabilitiesChangedNotification,
//            object: Self.audioSession
//        )

        // Note: Deactivated as we do not need it for now.
        // Silence secondary audio hint
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleSilenceSecondaryAudioHintNotification),
//            name: AVAudioSession.silenceSecondaryAudioHintNotification,
//            object: Self.audioSession
//        )
    }
}

// MARK: Proximity sensor notification
extension AudioSessionManager {
    internal static func checkIfProximitySensorIsAvailable() -> Bool {
        // From doc:
        // Not all iOS devices have proximity sensors. To determine if proximity monitoring is available,
        // attempt to enable it. If the value of the isProximityMonitoringEnabled property remains false,
        // proximity monitoring isn’t available.
        var isAvailable: Bool

        if UIDevice.current.isProximityMonitoringEnabled {
            // Already enabled, no need to go further, the sensor is available
            isAvailable = true
        } else {
            // Not enabled. We have to enable it and verify is stays enabled.
            UIDevice.current.isProximityMonitoringEnabled = true

            // Check the state, if is stays enabled, it means the sensor is available
            isAvailable = UIDevice.current.isProximityMonitoringEnabled

            // Set back the state to previous state (disabled).
            UIDevice.current.isProximityMonitoringEnabled = false
        }

        return isAvailable
    }

    internal func observeProximitySensorNotificationIfNeeded() {
        var shouldObserveProximitySensor: Bool

        switch state {
        case .playing:
            if isHeadphonesConnected() {
                shouldObserveProximitySensor = false
            } else {
                // We're observing for proximity sensor changes only when playing, without headphones.
                // Documentation specifically states that we should observe those changes only when our app needs it.
                shouldObserveProximitySensor = true
            }
        case .uninitialized, .error, .configured, .recording, .stoppingRecording, .processing:
            shouldObserveProximitySensor = false
        }

        observeProximitySensorNotification(shouldObserveProximitySensor)
    }

    private func observeProximitySensorNotification(_ shouldObserve: Bool) {
        logger?(.trace, "observe proximity sensor notification")
        guard audioSession.category == .playAndRecord else {
            logger?(
                .trace,
                """
                … no need to listen to proximity sensor. As the session category
                is NOT playAndRecord, we cannot override the output."
                """
            )
            stopObservingProximitySensorNotification()
            return
        }

        guard isProximitySensorAvailable else {
            logger?(.trace, "… proximity sensor is not available.")
            stopObservingProximitySensorNotification()
            return
        }

        if shouldObserve {
            startObservingProximitySensorNotification()
        } else {
            stopObservingProximitySensorNotification()
        }
    }

    private func startObservingProximitySensorNotification() {
        logger?(.trace, "Start observing proximity sensor")
        UIDevice.current.isProximityMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProximitySensorNotification),
            name: UIDevice.proximityStateDidChangeNotification,
            object: nil
        )
    }

    private func stopObservingProximitySensorNotification() {
        logger?(.trace, "Stop observing proximity sensor")
        UIDevice.current.isProximityMonitoringEnabled = false

        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.proximityStateDidChangeNotification,
            object: nil
        )
    }
}
