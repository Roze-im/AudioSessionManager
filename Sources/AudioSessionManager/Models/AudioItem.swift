//
//  AudioItem.swift
//
//
//  Created by Thibaud David on 08/03/2024.
//

import Foundation
import AVFoundation

extension AudioSessionManager {
    public enum AudioItem: Equatable {
        public static func == (lhs: AudioItem, rhs: AudioItem) -> Bool {
            return lhs.url == rhs.url
        }

        case local(
            url: URL,
            options: Options,
            player: AVAudioPlayer,
            deactivateSessionOnDidFinish: Bool
        )
        case remote(
            url: URL,
            options: Options,
            player: AVPlayer,
            deactivateSessionOnDidFinish: Bool
        )


        public var url: URL {
            switch self {
            case .local(let url, _, _, _):
                return url
            case .remote(let url, _, _, _):
                return url
            }
        }

        var player: AudioPlayer {
            switch self {
            case .local(_, _, let player, _):
                return player
            case .remote(_, _, let player, _):
                return player
            }
        }

        var options: Options {
            switch self {
            case .local(_, let options, _, _):
                return options
            case .remote(_, let options, _, _):
                return options
            }
        }

        var deactivateSessionOnDidFinish: Bool {
            switch self {
            case .local(_, _, _, let deactivate):
                return deactivate
            case .remote(_, _, _, let deactivate):
                return deactivate
            }
        }

        public init(
            url: URL,
            rate: Float = 1,
            options: Options,
            deactivateSessionOnDidFinish: Bool
        ) throws {
            if url.isFileURLOrNilScheme {
                self = try .init(
                    localFileUrl: url,
                    rate: rate,
                    options: options,
                    deactivateSessionOnDidFinish: deactivateSessionOnDidFinish
                )
            } else {
                self = .init(
                    remoteFileUrl: url,
                    rate: rate,
                    options: options,
                    deactivateSessionOnDidFinish: deactivateSessionOnDidFinish
                )
            }
        }

        init(
            localFileUrl: URL,
            rate: Float,
            options: Options,
            deactivateSessionOnDidFinish: Bool
        ) throws {
            let player: AVAudioPlayer = try .init(contentsOf: localFileUrl)
            player.enableRate = true
            player.rate = rate

            self = .local(
                url: localFileUrl,
                options: options,
                player: player,
                deactivateSessionOnDidFinish: deactivateSessionOnDidFinish
            )
        }

        init(
            remoteFileUrl: URL,
            rate: Float,
            options: Options,
            deactivateSessionOnDidFinish: Bool
        ) {
            let player: AVPlayer = AVPlayer(url: remoteFileUrl)
            player.rate = rate

            self = .remote(
                url: remoteFileUrl,
                options: options,
                player: player,
                deactivateSessionOnDidFinish: deactivateSessionOnDidFinish
            )
        }
    }
}

extension AudioSessionManager.AudioItem {
    public struct Options: OptionSet {
        public let rawValue: Int8

        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public static let loopPlay = Options(rawValue: 1 << 0)
        public static let postProcessing = Options(rawValue: 1 << 1)
    }
}
