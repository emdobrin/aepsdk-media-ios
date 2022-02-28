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
import AEPCore
import AEPServices

class MediaService: MediaProcessor {

    private static let LOG_TAG = MediaConstants.LOG_TAG
    private static let CLASS_NAME = "MediaService"

    private let dependencies = [
        MediaConstants.Configuration.SHARED_STATE_NAME,
        MediaConstants.Identity.SHARED_STATE_NAME,
        MediaConstants.Analytics.SHARED_STATE_NAME,
        MediaConstants.Assurance.SHARED_STATE_NAME
    ]
    private let dispatchQueue = DispatchQueue(label: "MediaService.DispatchQueue")
    private let mediaState: MediaState
    private let mediaDBService: MediaDBService
    #if DEBUG
        var mediaSessions: [String: MediaSession] = [:]
    #else
        private var mediaSessions: [String: MediaSession] = [:]
    #endif
    
    private var dispatchFn: (([String: Any]) -> Void)?

    init(mediaDBService: MediaDBService) {
        self.mediaState = MediaState()
        self.mediaDBService = mediaDBService
    }

    ///Read persisted offline session from DB and create `MediaSession` objects for them and initiate the reporting of `MediaSessions.`
    private func initPersistedSessions() {
        let persistedSessionIds = mediaDBService.getPersistedSessionIds()
        persistedSessionIds.forEach { sessionId in
            let mediaOfflineSession = MediaOfflineSession(id: sessionId, state: mediaState, dispatchQueue: dispatchQueue, mediaDBService: mediaDBService, dispathFn: self.dispatchFn)
            mediaSessions[sessionId] = mediaOfflineSession
            mediaOfflineSession.end {
                self.mediaSessions.removeValue(forKey: sessionId)
            }
        }
    }

    func readyToProcess(dispatchFn: @escaping ([String: Any]) -> Void) {
        self.dispatchFn = dispatchFn
        dispatchQueue.async {
            self.initPersistedSessions()
        }
    }

    func createSession(config: [String: Any]) -> String? {
        dispatchQueue.sync {
            guard mediaState.privacyStatus != .optedOut else {
                Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Could not start new media session. Privacy is opted out.")
                return nil
            }

            let isDownloaded = config[MediaConstants.TrackerConfig.DOWNLOADED_CONTENT] as? Bool ?? false
            let sessionId = UUID().uuidString
            var session: MediaSession
            if isDownloaded {
                session = MediaOfflineSession(id: sessionId, state: mediaState, dispatchQueue: dispatchQueue, mediaDBService: mediaDBService, dispathFn: dispatchFn)
            } else {
                session = EdgeMediaRealTimeSession(id: sessionId, state: mediaState, dispatchQueue: dispatchQueue, dispathFn: dispatchFn)
            }

            mediaSessions[sessionId] = session
            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Created a new session (\(sessionId))")
            return sessionId
        }
    }
    
    func updateSessionInfo(requestEventId: String, backendSessionId: String) {
        dispatchQueue.async {
            self.mediaSessions.forEach { sessionId, _ in self.mediaSessions[sessionId]?.notifySessionUpdate(requestEventId: requestEventId, backendSessionId: backendSessionId) }
        }
    }

    /// Queues the `MediaHit` hit in session `sessionId`
    ///- Parameters:
    ///    - sessionId: UniqueId of session to which `MediaHit` belongs.
    ///    - hit: `Object` of type `MediaHit`
    func processHit(sessionId: String, hit: MediaHit) {
        dispatchQueue.async {
            guard self.mediaSessions.keys.contains(sessionId) else {
                Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Can not process session (\(sessionId)). SessionId is invalid.")
                return
            }

            let session = self.mediaSessions[sessionId]
            session?.queue(hit: hit)
            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Successfully queued hit (\(hit.eventType) for Session (\(sessionId)).")
        }
    }

    /// Ends the session `sessionId`.
    ///
    /// - Parameter sessionId: Unique session id for session to end.
    func endSession(sessionId: String) {
        dispatchQueue.async {
            guard self.mediaSessions.keys.contains(sessionId) else {
                Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Can not end media session (\(sessionId)). Invalid session id.")
                return
            }

            self.mediaSessions[sessionId]?.end {
                self.mediaSessions.removeValue(forKey: sessionId)
                Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Successfully ended media session (\(sessionId))")
            }

            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Scheduled end for media session (\(sessionId))")
        }
    }

    /// Abort the session `sessionId`.
    ///
    /// - Parameter sessionId: Unique sessionId of session to be aborted.
    private func abort(sessionId: String) {
        guard mediaSessions.keys.contains(sessionId) else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Can not abort media session (\(sessionId)). SessionId is invalid.")
            return
        }

        mediaSessions[sessionId]?.abort {
            self.mediaSessions.removeValue(forKey: sessionId)
            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Successfully aborted media session (\(sessionId)).")
        }

        Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Scheduled abort for media session (\(sessionId).")
    }

    /// Notify MediaState updates
    /// - Parameter sessionId: Unique sessionId of session
    private func notifyMediaStateUpdate(sessionId: String) {
        guard mediaSessions.keys.contains(sessionId) else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Can not notify states changes for media session (\(sessionId)). SessionId is invalid.")
            return
        }

        mediaSessions[sessionId]?.handleMediaStateUpdate()
    }

    // todo: update me - these dependencies are no longer needed
    func updateMediaState(event: Event, getSharedState: (String, Event, Bool) -> SharedStateResult?) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = getSharedState(extensionName, event, true)?.value
        }
        dispatchQueue.async {
            self.mediaState.update(dataMap: sharedStates)
            if self.mediaState.privacyStatus == .optedOut {
                self.abortAllSessions()
            } else {
                self.mediaSessions.forEach { sessionId, _ in self.notifyMediaStateUpdate(sessionId: sessionId) }
            }
        }
    }

    func abortAllSessions() {
        dispatchQueue.async {
            self.mediaSessions.forEach { sessionId, _ in self.abort(sessionId: sessionId) }
        }
    }
}
