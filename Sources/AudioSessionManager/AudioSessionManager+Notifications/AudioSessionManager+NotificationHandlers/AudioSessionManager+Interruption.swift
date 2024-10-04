//
//  AudioSessionManager+Interruption.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation

// MARK: Interruptions
// swiftlint:disable line_length
// Doc: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html#//apple_ref/doc/uid/TP40007875-CH4-SW1

extension AudioSessionManager {
    @objc func handleInterruptionNotification(notification: Notification) {
        guard let payload: NotificationPaylod.Interruption = .init(notification) else {
            logger?(.error, "Failed to cast interruption notification into payload.")
            return
        }

        // Note: The session gets deactivated automatically by the system

        switch payload.type {
        case .began:
            onInterruptionBegan()

        case .ended:
            guard let options = payload.options else {
                // From doc:
                // If the interruption type is AVAudioSession.InterruptionType.ended, the userInfo dictionary
                // contains an AVAudioSession.InterruptionOptions value, which you use to determine whether
                // playback automatically resumes.
                logger?(.error, "Error: interruption type is .ended, but the payload does not contains any options.")
                return
            }
            onInterruptionEnded(options: options)

        @unknown default:
            break
        }
    }

    private func onInterruptionBegan() {
        // An interruption began, update UI if necessary
        switch state {
        case .configured, .error, .uninitialized, .processing, .stoppingRecording:
            // Nothing to do here
            // We were not doing anything with the session.
            break

        case .playing(_, let it, let paused):
            if !paused {
                // We were playing an audio with the session, not paused.
                // We need to update the state to 'paused'.
                _ = pausePlayingItem(it)
            }

        case .recording(_, _, let paused, _, _, _):
            if !paused {
                // We were recording an audio with the session, not paused.
                // We need to cancel the record
                stopRecordingAudio(cancelled: true)
            }
        }
    }

    // Note: we don't have any use case that requires to resume a playing audio for now.
    private func onInterruptionEnded(options: AVAudioSession.InterruptionOptions) {
        // An interruption ended. Resume playback if needed
        if options.contains(.shouldResume) {
            // Resume playback if needed
            // If yes, we'll need to see how does the .shouldResume option works.
            logger?(.trace, "Interruption ended, options contains '.shouldResume'")
        } else {
            // Don't resume playback
            logger?(.trace, "Interruption ended, options DOES NOT contains '.shouldResume'")
        }
    }
}

extension AudioSessionManager.NotificationPaylod {
    public struct Interruption {

        public var type: AVAudioSession.InterruptionType
        public var options: AVAudioSession.InterruptionOptions?
        public var reason: AVAudioSession.InterruptionReason?

        init?(_ notification: Notification) {
            guard   notification.name == AVAudioSession.interruptionNotification,
                    let userInfo = notification.userInfo,
                    let typeValue: UInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                    let type: AVAudioSession.InterruptionType = .init(rawValue: typeValue)
            else { return nil }

            var options: AVAudioSession.InterruptionOptions?
            if let optionsValue: UInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                options = .init(rawValue: optionsValue)
            }

            var reason: AVAudioSession.InterruptionReason?
            if let reasonValue: UInt = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt {
                reason = .init(rawValue: reasonValue)
            }

            self.type = type
            self.options = options
            self.reason = reason
        }
    }
}
