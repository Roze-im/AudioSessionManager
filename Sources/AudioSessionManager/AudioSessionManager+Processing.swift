//
//  AudioSessionManager.swift
//
//
//  Created by Thibaud David on 16/09/2024.
//

import Foundation

extension AudioSessionManager {
    public func startProcessingItem(_ item: AudioItem) -> Error? {
        logger?(.debug, "startPlayingItem")
        switch state {
        case .configured(let sessionConfiguration):
            do {
                // We activate the session only when necessary, so we don't stop any other app audio before.
                try activateSession()

                state = .processing(
                    sessionConfiguration: sessionConfiguration,
                    items: [item]
                )
                delegate?.audioSessionManager(self, didStartProcessing: item)
            } catch {
                let error = PlayError.startProcessingFailed(item: item, error: error)
                logger?(.error, error.debugDescription)
                return error
            }

        case .processing(let sessionConfiguration, let items):
            state = .processing(
                sessionConfiguration: sessionConfiguration,
                items: items + [item]
            )

        case .playing(_, let it, _) where it != item:
            stopPlayingItem(it, deactivateSession: false)
            if case .configured = state {
                return startProcessingItem(item)
            } else {
                let error = PlayError.wrongState(state)
                logger?(.error, error.debugDescription)
                return error
            }

        default:
            let error = PlayError.wrongState(state)
            logger?(.error, error.debugDescription)
            return error
        }

        return nil
    }

    func didStopProcessing(item: AudioItem) {
        logger?(.debug, "Audio player did finish processing")
        guard case .processing(let sessionConfiguration, var items) = state else {
            logger?(.error, "audioPlayerDidFinishPlaying: wrong state \(String(describing: state))")
            return
        }

        items = items.filter { $0 != item}
        if items.isEmpty {
            self.state = .configured(sessionConfiguration: sessionConfiguration)
        } else {
            self.state = .processing(sessionConfiguration: sessionConfiguration, items: items)
        }

        delegate?.audioSessionManager(self, didFinishProcessing: item, hasRemainingItems: !items.isEmpty)

        // The call to delegate.didFinishPlaying may have resulted in a state change.
        switch state {
        case .playing, .processing:
            break
        default:
            if item.deactivateSessionOnDidFinish {
                // Deactivate the session and notify other apps in order to resume any previously playing audio
                deactivateSessionAndNotifyOthers()
            }
        }
    }
}
