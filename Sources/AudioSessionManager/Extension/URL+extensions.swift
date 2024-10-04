//
//  URL+extensions.swift
//  AudioSessionManager
//
//  Created by Thibaud David on 04/10/2024.
//

import Foundation

extension URL {
    public var isFileURLOrNilScheme: Bool { isFileURL || (scheme == nil) }
}
