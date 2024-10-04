//
//  AudioSessionManager+MediaService.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation

// MARK: Media service
// swiftlint:disable line_length
// Doc: (at the bottom of the page) https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html#//apple_ref/doc/uid/TP40007875-CH4-SW1

extension AudioSessionManager {
    // Note: there is no userInfo dictionary in those two notifications.

    @objc func handleMediaServiceWereReset(notification: Notification) {
        // Media service were reset. We need to:
        // - dispose any previously created player / recorder / converters, and create new ones if needed
        // - call setActive(true) if needed
        // - reset internal audio state being tracked
        logger?(.debug, "Media Service Notification RESET: \(notification)")

        deactivateSessionAndNotifyOthers()

        switch state {
        case .uninitialized, .error, .configured, .processing, .stoppingRecording:
            break

        case .recording:
            stopRecordingAudio(cancelled: true)

        case .playing(_, let it, _):
            stopPlayingItem(it, deactivateSession: true)
        }

        reconfigureAudioSessionIfNeeded(force: true)
    }

    @objc func handleMediaServiceWereLost(notification: Notification) {
        // For now, We're not doing anything special when receiving this notification.
        // If needed, we could update our UI to reflect the state before receiving the "reset"
        // notification.
        logger?(.debug, "Media Service Notification LOST: \(notification)")
        switch state {
        case .uninitialized, .error, .configured, .processing, .stoppingRecording:
            break

        case .recording:
            stopRecordingAudio(cancelled: true)

        case .playing(_, let it, _):
            stopPlayingItem(it, deactivateSession: true)
        }

        self.state = .error(
            sessionConfiguration: state.sessionConfiguration,
            error: ConfigurationError.mediaServiceWereLost
        )
    }
}
