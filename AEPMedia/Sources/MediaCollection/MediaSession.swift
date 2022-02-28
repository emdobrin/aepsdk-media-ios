/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation
import AEPServices

class MediaSession {
    private static let LOG_TAG = MediaConstants.LOG_TAG
    private static let CLASS_NAME = "MediaSession"

    let id: String
    let state: MediaState
    let dispatchQueue: DispatchQueue
    let dispathFn: (([String: Any]) -> Void)?
    var isSessionActive: Bool
    var sessionEndHandler: (() -> Void)?

    ///Initializer for `MediaSession`
    ///- Parameters:
    ///    - id: Unique `MediaSession id`
    ///    - mediaState: `MediaState` object
    ///    - dispatchQueue: `DispatchQueue` used for handling response after processing `MediaHit`
    ///    - dispathFn: a function which when invoked dispatches sessionCreated Event
    init(id: String, state: MediaState, dispatchQueue: DispatchQueue, dispathFn: (([String: Any]) -> Void)?) {
        self.id = id
        self.state = state
        self.dispatchQueue = dispatchQueue
        self.dispathFn = dispathFn
        isSessionActive = true
    }

    ///Queues the `MediaHit`
    /// - Parameter hit: `MediaHit` to be queued.
    func queue(hit: MediaHit) {
        guard isSessionActive else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Failed to queue hit. Media Session (\(id)) is inactive.")
            return
        }

        handleQueueMediaHit(hit: hit)
    }

    ///Ends the session
    ///- Parameter onsessionEnd: An optional closure that will be executed after successfully ending the session.
    func end(onSessionEnd sessionEndHandler: (() -> Void)? = nil) {
        guard isSessionActive else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Failed to end session. Media Session (\(id)) is inactive")
            return
        }

        self.sessionEndHandler = sessionEndHandler
        isSessionActive = false
        handleSessionEnd()
    }

    ///Aborts the session.
    ///- Parameter onSessionEnd: An optional closure that will be executed after successfully aborting the session.
    func abort(onSessionEnd sessionEndHandler: (() -> Void)? = nil) {
        guard isSessionActive else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Failed to abort session. Media Session (\(id)) is inactive")
            return
        }

        self.sessionEndHandler = sessionEndHandler
        isSessionActive = false
        handleSessionAbort()
    }

    /// Notifies MediaState updates
    func handleMediaStateUpdate() {
        Log.warning(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - This function should be handled by the implementing class.")
    }
    
    /// Overwrite this function for real time processing
    /// Update with session id from server
    func notifySessionUpdate(requestEventId: String, backendSessionId: String) {
        // noop by default
    }

    ///Includes the business logic for ending session. Implemented by more concrete classes of MediaSession: `MedialRealTimeSession` and `MediaOfflineSession`.
    func handleSessionEnd() {
        Log.warning(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - This function should be handled by the implementing class.")
    }

    ///Includes the business logic for aborting session. Implemented by more concrete classes of MediaSession: `MedialRealTimeSession` and `MediaOfflineSession`.
    func handleSessionAbort() {
        Log.warning(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - This function should be handled by the implementing class.")
    }

    ///Includes the business logic for queuing `MediaHit`. Implemented by more concrete classes of MediaSession: `MedialRealTimeSession` and `MediaOfflineSession`.
    /// - Parameter hit: `MediaHit` to be queued.
    func handleQueueMediaHit(hit: MediaHit) {
        Log.warning(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - This function should be handled by the implementing class.")
    }
}
