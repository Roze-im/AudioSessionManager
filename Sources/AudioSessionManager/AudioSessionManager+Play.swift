//
//  AudioSessionManager+Play.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation

extension AudioSessionManager {

    public enum PlayError: Error, LocalizedError {
        case startPlayingFailed(item: AudioItem, error: Error?)
        case startProcessingFailed(item: AudioItem, error: Error?)
        case resumePlayingFailed(item: AudioItem, error: Error?)
        case audioPlayerDecodeErrorDidOccur(url: URL?, error: Error?)
        case wrongState(State)

        // Human readable error title
        public var localizedTitle: String {
            return NSLocalizedString("playerror.generic.title", bundle: .module, comment: "")
        }

        // LocalizedError protocol, human readable error message
        public var errorDescription: String? {
            switch self {
            case .startPlayingFailed,
                    .resumePlayingFailed,
                    .startProcessingFailed,
                    .audioPlayerDecodeErrorDidOccur:
                return NSLocalizedString("playerror.generic.message", bundle: .module, comment: "")

            case .wrongState(let state):
                switch state {
                case .error(_, let error):
                    switch error {
                    case let configurationError as ConfigurationError:
                        return configurationError.localizedDescription

                    default:
                        return NSLocalizedString("playerror.generic.message", bundle: .module, comment: "")
                    }
                default:
                    return NSLocalizedString("playerror.generic.message", bundle: .module, comment: "")

                }
            }
        }

        // Debugging purpose
        var debugDescription: String {
            switch self {
            case .startPlayingFailed(let item, let error):
                return "Start playing failed. Item: \(item), error: \(String(describing: error))"
            case .resumePlayingFailed(let item, let error):
                return "Resume playing failed. Item: \(item), error: \(String(describing: error))"
            case .audioPlayerDecodeErrorDidOccur(let url, let error):
                return "Decode error did occur. URL: \(String(describing: url)), error: \(String(describing: error))"
            case .startProcessingFailed(let item, let error):
                return "Start processing failed. Item: \(item), error: \(String(describing: error))"
            case .wrongState(let state):
                return "Wrong state \(String(describing: state))"
            }
        }
    }

    public func startPlayingItem(_ item: AudioItem) -> Error? {
        logger?(.debug, "startPlayingItem")
        switch state {
        case .configured(let sessionConfiguration):
            do {
                // Configure audio player
                switch item {
                case .local(_,_ , let player, _):
                    player.delegate = self
                case .remote:
                    break
                }

                // We activate the session only when necessary, so we don't stop any other app audio before.
                try activateSession()

                let playStarted = item.player.startPlaying()
                if playStarted {
                    state = .playing(
                        sessionConfiguration: sessionConfiguration,
                        item: item,
                        paused: false
                    )
                    delegate?.audioSessionManager(self, didStartPlaying: item)
                    return nil
                } else {
                    let error = PlayError.startPlayingFailed(item: item, error: nil)
                    logger?(.error, error.debugDescription)
                    return error
                }
            } catch {
                let error = PlayError.startPlayingFailed(item: item, error: error)
                logger?(.error, error.debugDescription)
                return error
            }

        case .playing(_, let it, let paused) where it == item && paused == true:
            return resumePlayingItem(item)

        case .playing(_, let it, _) where it != item:
            stopPlayingItem(it, deactivateSession: false)
            if case .configured = state {
                return startPlayingItem(item)
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
    }

    private func resumePlayingItem(_ item: AudioItem) -> Error? {
        guard case .playing(let sessionConfiguration, let it, let paused) = state,
              it == item,
              paused == true else {
            let error = PlayError.wrongState(state)
            logger?(.error, error.debugDescription)
            return error
        }

        let playStarted = it.player.startPlaying()
        if playStarted {
            state = .playing(
                sessionConfiguration: sessionConfiguration,
                item: item,
                paused: false
            )
            delegate?.audioSessionManager(self, didStartPlaying: item)
            return nil
        } else {
            let error = PlayError.resumePlayingFailed(item: item, error: nil)
            logger?(.error, error.debugDescription)
            return error
        }
    }

    public func pausePlayingItem(_ item: AudioItem) -> Error? {
        guard case .playing(let sessionConfiguration, let it, let paused) = state,
              it == item,
              paused == false else {
            let error = PlayError.wrongState(state)
            logger?(.error, error.debugDescription)
            return error
        }

        it.player.pause()
        deactivateSessionAndNotifyOthers()
        state = .playing(
            sessionConfiguration: sessionConfiguration,
            item: item,
            paused: true
        )
        delegate?.audioSessionManager(self, didPausePlaying: item)
        return nil
    }

    public func stopPlayingItem(_ item: AudioItem, deactivateSession: Bool) {
        guard case .playing(let sessionConfiguration, let it, _) = state,
        it == item else {
            logger?(.debug, "Cannot stop audio: wrong state \(String(describing: state))")
            return
        }
        it.player.stop()
        if deactivateSession {
            deactivateSessionAndNotifyOthers()
        }
        state = .configured(sessionConfiguration: sessionConfiguration)
        delegate?.audioSessionManager(self, didStopPlaying: item)
    }

    public func setPlayerRate(rate: Float, items: [AudioItem]) {
        logger?(.debug, "Set rate to \(rate)")
        items.forEach { item in
            switch item {
            case .local(_, _, let player, _):
                player.rate = rate
            case .remote:
                logger?(.debug, "setPlayerRate unsupported for remote player, skipping")
            }
        }
        delegate?.audioSessionManagerDidUpdateState(self)
    }

    public func moveItemCursor(
        item: AudioItem,
        percent: Float
    ) {
        logger?(.debug, "Move playing item cursor to \(percent)")
        guard case .local(_, _, let player, _) = item else {
            logger?(.error, "moveItemCursor not supported on remote audio")
            return
        }
        player.currentTime = Self.targetTime(
            audioDuration: player.duration,
            percent: percent
        )
    }

    private static func targetTime(audioDuration: TimeInterval, percent: Float) -> TimeInterval {
        return min(audioDuration, audioDuration * Double(percent))
    }

    public struct PlayerCursorData {
        public let duration: TimeInterval
        public let currentTime: TimeInterval
        public let remainingTime: TimeInterval
        public let percent: Double

        public static let zero: PlayerCursorData = .init(
            duration: 0, currentTime: 0, remainingTime: 0, percent: 0
        )

        init(
            duration: TimeInterval,
            currentTime: TimeInterval,
            remainingTime: TimeInterval,
            percent: Double
        ) {
            self.duration = duration
            self.currentTime = currentTime
            self.remainingTime = remainingTime
            self.percent = percent
        }

        public init(item: AudioItem) throws {
            guard case .local(_, _, let player, _) = item else {
                throw PlayerCursorDataError.remotePlayerNotSupported
            }
            self.init(
                duration: player.duration,
                currentTime: player.currentTime,
                remainingTime: player.duration - player.currentTime,
                percent: player.currentTime / player.duration
            )
        }

        enum PlayerCursorDataError: Error {
            case remotePlayerNotSupported
        }
    }
}

extension AudioSessionManager {
    func playerDidFinishPlaying() {
        logger?(.debug, "Audio player did finish playing")
        guard case .playing(let sessionConfiguration, let item, _) = state else {
            logger?(.error, "audioPlayerDidFinishPlaying: wrong state \(String(describing: state))")
            return
        }

        self.state = .configured(sessionConfiguration: sessionConfiguration)

        delegate?.audioSessionManager(self, didFinishPlaying: item)

        // The call to delegate.didFinishPlaying may have resulted in a state change.
        switch state {
        case .playing:
            break
        default:
            if item.deactivateSessionOnDidFinish {
                // Deactivate the session and notify other apps in order to resume any previously playing audio
                deactivateSessionAndNotifyOthers()
            }
        }

        item.player.moveToStart()
    }
    func playerDidFailPlaying(_ url: URL?, error: Error?) {
        self.state = .error(
            sessionConfiguration: state.sessionConfiguration,
            error: PlayError.audioPlayerDecodeErrorDidOccur(url: url, error: error)
        )
    }
}

extension AudioSessionManager: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playerDidFinishPlaying()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        playerDidFailPlaying(player.url, error: error)
    }
}

extension AudioSessionManager {
    @objc func avPlayerDidFinishPlaying(_ notification: Notification) {
        guard let notifierItem = notification.object as? AVPlayerItem else {
            logger?(.error, "Unexpected notifier \(String(describing: notification.object))")
            return
        }
        func checkItemRelevancy(_ item: AudioSessionManager.AudioItem) -> Bool {
            guard case .remote(_, _, let player, _) = item else {
                logger?(.error, "Unexpected playerItem player \(String(describing: notification.object))")
                return false
            }
            guard player.currentItem == notifierItem else {
                logger?(.debug, "Received notification for unrelated player, aborted")
                return false
            }
            return true
        }

        switch state {
        case .playing(_, let item, _) where checkItemRelevancy(item):
            if item.options.contains(.loopPlay) {
                item.player.moveToStart()
                _ = item.player.startPlaying()
            } else {
                playerDidFinishPlaying()
            }
        default:
            break
        }
    }

    @objc func avPlayerDidFailPlayingToEnd(_ notification: Notification) {
        guard case .playing(_, .remote(let url, _, _, _), _) = state else { return }
        guard let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error else {
            playerDidFailPlaying(nil, error: NSError(domain: "AudioSessionManager", code: 1))
            return
        }

        playerDidFailPlaying(url, error: error)
    }
}
