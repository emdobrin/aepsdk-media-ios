/*
 Copyright 2022 Adobe. All rights reserved.
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
import AEPCore

class EdgeMediaRealTimeSession: MediaSession {

    private static let LOG_TAG = MediaConstants.LOG_TAG
    private static let CLASS_NAME = "EdgeMediaRealTimeSession"

    private static let DURATION_BETWEEN_HITS_ON_FAILURE = 60 // Retry duration in case of failure
    private static let MAX_ALLOWED_DURATION_BETWEEN_HITS_MS: Int64 = 60  * 1000 // 60 sec
    private static let MAX_ALLOWED_FAILURE = 3 //The maximum number of times SDK retries to send hit on failure, after that drop the hit.

    #if DEBUG
        var hits: [MediaHit] = []
    #else
        private var hits: [MediaHit] = []
    #endif

    private var mcSessionId: String?
    private var isSendingSessionRequest: Bool = false
    private var lastHitTS: Int64 = 0
    // this will be used when we have failed to send the request so starting at 1
    private var sessionStartRetryCount = 1
    private var edgeRequestId: String? // used to tie the session id once the Edge Response is received
    var retryDuration = DURATION_BETWEEN_HITS_ON_FAILURE

    override func handleQueueMediaHit(hit: MediaHit) {
        if !isSessionActive {
            return
        }

        Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - [Session (\(id))] Queuing hit with event type (\(hit.eventType))")
        hits.append(hit)
        trySendHit()
    }
    
    override func notifySessionUpdate(requestEventId: String, backendSessionId: String) {
        self.dispatchQueue.async {
            if requestEventId != self.edgeRequestId {
                return
            }
            
            self.isSendingSessionRequest = false
            
            // todo: handle error - see handleEdgeErrorResponse
            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - [Session (\(self.id) Created MediaEdge session \(backendSessionId)")
            self.mcSessionId = backendSessionId

            // var eventData = debugInfo // todo: fix me
            var eventData: [String: Any] = [:]
            eventData[MediaConstants.Tracker.BACKEND_SESSION_ID] = backendSessionId
            self.dispathFn?(eventData)

            self.handleProcessingSuccess()
        }
    }

    override func handleSessionEnd() {
        Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - [Session (\(id))] End")
        trySendHit()
    }

    override func handleSessionAbort() {
        Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - [Session (\(id))] Abort")
        hits.removeAll()
        sessionEndHandler?()
    }

    override func handleMediaStateUpdate() {
        Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - [Session (\(id))] Handling media state update")
        trySendHit()
    }

    ///Sends the first `MediaHit` from the collected hits to Media Collection Server
    private func trySendHit() {
        // todo: check consent for low level events (but not for the others?)

        guard !isSendingSessionRequest else {
            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - [Session (\(id)] Exiting as it is currently sending a hit")
            return
        }

        guard !hits.isEmpty, let hit = hits.first else {
            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - [Session (\(id)] Exiting as there is no queued hits")
            return
        }

        let eventType = hit.eventType
        let isSessionStartHit = (eventType == MediaConstants.MediaCollection.EventType.SESSION_START)

        if !isSessionStartHit && (mcSessionId ?? "").isEmpty {
            Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] -  [Session (\(id)] Dropping hit (\(eventType)), media collection session id is unavailable.")
            sendNextHit()
            return
        }

        logHitDelay(hit: hit)

        guard let urlPath = generateURLPathForHit(hit) else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] -  [Session (\(id)] Dropping hit with unknown type (\(eventType)), unable to create url path")
            sendNextHit()
            return
        }
        guard let edgeEventData = EdgeMediaReportHelper.generateEdgeEventData(state: state, hit: hit, urlPath: urlPath, sessionId: mcSessionId), !edgeEventData.isEmpty else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] -  [Session (\(id)] Dropping hit (\(eventType)), unable to generate event data for edge hit")
            sendNextHit()
            return
        }
        let debugInfo = EdgeMediaReportHelper.extractDebugInfo(hit: hit)

        if isSessionStartHit {
            isSendingSessionRequest = true // wait for session id before moving forward
        }

        Log.trace(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] -  [Session (\(id)] Send Edge request (\(eventType)) with data \(edgeEventData)")
        
        let mediaEdgeRequestEvent = Event(name: "Edge request for Media", type: EventType.edge, source: EventSource.requestContent, data: edgeEventData)
        //edgeRequestId = mediaEdgeRequestEvent.id.uuidString // todo: uncomment me
        edgeRequestId = "C21B3A27-B0C3-4E33-B021-400F862D85AC" // for testing
        MobileCore.dispatch(event: mediaEdgeRequestEvent)
        
        if !isSessionStartHit {
            handleProcessingSuccess() // keep processing events
        }
    }
    
    func handleEdgeErrorResponse() {
        // todo: implement me
    }

    ///Handles if hit is successfully send to the Media Collection Server
    private func handleProcessingSuccess() {
        sendNextHit()
    }

    ///Handles if there is an error in sending hit to the Media Collection Server
    private func handleProcessingError(sessionStart: Bool) {
        if !sessionStart || sessionStartRetryCount >= EdgeMediaRealTimeSession.MAX_ALLOWED_FAILURE {
            sendNextHit()
            return
        }

        if sessionStartRetryCount < EdgeMediaRealTimeSession.MAX_ALLOWED_FAILURE {
            sessionStartRetryCount += 1
            dispatchQueue.asyncAfter(deadline: .now() + .seconds(retryDuration)) { [weak self] in
                self?.trySendHit()
            }
        }
    }

    ///Initiates sending the next hit after a hit is successfully send OR error occurred in sending the hit, greater than or equals to MAX_ALLOWED_FAILURE times. It also handles the condition if there is not pending hit and session has been ended.
    private func sendNextHit() {
        if !hits.isEmpty {
            hits.removeFirst()
        }

        if hits.isEmpty && !isSessionActive {
            sessionEndHandler?()
            return
        }

        trySendHit()
    }

    private func logHitDelay(hit: MediaHit) {
        if hit.eventType == MediaConstants.MediaCollection.EventType.SESSION_START {
            lastHitTS = hit.timestamp
        }

        let currHitTS = hit.timestamp
        let diff = currHitTS - lastHitTS
        if diff >= EdgeMediaRealTimeSession.MAX_ALLOWED_DURATION_BETWEEN_HITS_MS {
            Log.warning(label: Self.LOG_TAG, "trySendHit - (\(hit.eventType)) TS difference from previous hit is \(diff) greater than 60 seconds.")
        }
        lastHitTS = currHitTS
    }
    
    private func generateURLPathForHit(_ hit: MediaHit) -> String? {
        var urlPath: String = MediaConstants.Edge.Path.VIDEO_ANALYTICS
        switch hit.eventType {
        case MediaConstants.MediaCollection.EventType.SESSION_START:
            urlPath += MediaConstants.Edge.Path.SESSION_START
            break
        case MediaConstants.MediaCollection.EventType.CHAPTER_START:
            urlPath += MediaConstants.Edge.Path.CHAPTER_START
            break
        case MediaConstants.MediaCollection.EventType.CHAPTER_COMPLETE:
            urlPath += MediaConstants.Edge.Path.CHAPTER_COMPLETE
            break
        case MediaConstants.MediaCollection.EventType.AD_START:
            urlPath += MediaConstants.Edge.Path.AD_START
            break
        case MediaConstants.MediaCollection.EventType.AD_COMPLETE:
            urlPath += MediaConstants.Edge.Path.AD_COMPLETE
            break
        // todo: handle all events
        default:
            return nil
        }
        
        return urlPath
    }
}
