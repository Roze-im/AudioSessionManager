//
//  AudioSessionManager+SilenceSecondaryAudioHint.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation

extension AudioSessionManager {
    @objc func handleSilenceSecondaryAudioHintNotification(notification: Notification) {
        guard let payload: NotificationPaylod.SilenceSecondaryAudioHint = .init(notification) else {
            logger?(.error, "Failed to cast silence secondary audio notification into payload.")
            return
        }

        logger?(.trace, "handleSilenceSecondaryAudioHintNotification \(payload)")
    }
}

extension AudioSessionManager.NotificationPaylod {
    public struct SilenceSecondaryAudioHint {

        public var type: AVAudioSession.SilenceSecondaryAudioHintType

        init?(_ notification: Notification) {
            guard   notification.name == AVAudioSession.silenceSecondaryAudioHintNotification,
                    let userInfo = notification.userInfo,
                    let typeValue: UInt = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
                    let type: AVAudioSession.SilenceSecondaryAudioHintType = .init(rawValue: typeValue)
            else { return nil }

            self.type = type
        }
    }
}
