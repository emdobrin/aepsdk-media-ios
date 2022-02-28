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
import AEPCore

class EdgeMediaReportHelper {

    private static let LOG_TAG = MediaConstants.LOG_TAG
    private static let CLASS_NAME = "EdgeMediaReportHelper"

    private init() {}

    ///Generates the payload for `MediaHit` in `MediaRealTimeSession`
    ///- Parameters:
    ///   - state: Current Media state
    ///   - hit: Media hit to be send
    ///- Returns: The payload for Media hit
    private static func generateHitReport(state: MediaState, hit: MediaHit) -> [String: Any]? {
        let updatedHit = updateMediaHit(state: state, mediaHit: hit)
        return updatedHit.asDictionary()
    }
    
    static func generateEdgeEventData(state: MediaState, hit: MediaHit, urlPath: String, sessionId: String?) -> [String: Any]? {
        guard var hitReport = generateHitReport(state: state, hit: hit),
            let eventType = hitReport[MediaConstants.Edge.MediaEventType.EVENT_TYPE] as? String else {
            return nil
        }
        hitReport.removeValue(forKey: MediaConstants.Edge.MediaEventType.EVENT_TYPE)
        
        let xdmEventType = EdgeMediaHelper.eventTypeMappingToXDM[eventType]
        var eventData: [String: Any] = [:]
        eventData["xdm"] = ["eventType": xdmEventType,
                            "timestamp": Date(timeIntervalSince1970: TimeInterval(hit.timestamp) / 1000).getISO8601Date()] // TODO: use XDMMediaExperienceEvent
        eventData["data"] = hitReport
        eventData[MediaConstants.Edge.EventData.EDGE_PATH] = urlPath
        if let sessionId = sessionId {
            eventData[MediaConstants.Edge.EventData.QUERY_PARAMS] = ["sessionid", sessionId]
        }
        
        return eventData
    }

    ///Adds the additional parameters in the `MediaHit` params.
    ///- Parameters:
    ///   - state: Current `MediaState`
    ///   - mediaHit: The MediaHit object to be updated
    ///- Returns: Updated MediaHit object
    static func updateMediaHit(state: MediaState, mediaHit: MediaHit) -> MediaHit {

        if mediaHit.eventType == MediaConstants.MediaCollection.EventType.SESSION_START {
            var params = mediaHit.params ?? [String: Any]()
            
            if !params.keys.contains(MediaConstants.MediaCollection.Session.MEDIA_CHANNEL), let mediaChannel = state.mediaChannel {
                params[MediaConstants.MediaCollection.Session.MEDIA_CHANNEL] = mediaChannel
            }

            if let mediaPlayerName = state.mediaPlayerName {
                params[MediaConstants.MediaCollection.Session.MEDIA_PLAYER_NAME] = mediaPlayerName
            }

            if let appVersion = state.mediaAppVersion, !appVersion.isEmpty {
                params[MediaConstants.MediaCollection.Session.SDK_VERSION] = appVersion
            }

            params[MediaConstants.MediaCollection.Session.MEDIA_VERSION] = MediaConstants.MediaCollection.MEDIA_VERSION

            // Remove debugParams from MediaHit
            params.removeValue(forKey: MediaConstants.Tracker.SESSION_ID)

            return MediaHit(eventType: mediaHit.eventType, playhead: mediaHit.playhead, ts: mediaHit.timestamp, params: params, customMetadata: mediaHit.metadata, qoeData: mediaHit.qoeData)

        }

        if mediaHit.eventType == MediaConstants.MediaCollection.EventType.AD_START {
            var params = mediaHit.params ?? [String: Any]()
            if let mediaPlayerName = state.mediaPlayerName {
                params[MediaConstants.MediaCollection.Ad.PLAYER_NAME] = mediaPlayerName
            }
            return MediaHit(eventType: mediaHit.eventType, playhead: mediaHit.playhead, ts: mediaHit.timestamp, params: params, customMetadata: mediaHit.metadata, qoeData: mediaHit.qoeData)
        }

        return mediaHit
    }

    static func extractDebugInfo(hit: MediaHit) -> [String: Any] {
        var ret = [String: Any]()
        if hit.eventType == MediaConstants.MediaCollection.EventType.SESSION_START {
            ret[MediaConstants.Tracker.SESSION_ID] = hit.params?[MediaConstants.Tracker.SESSION_ID] as? String
        }
        return ret
    }

    static func extractDebugInfo(hits: [MediaHit]) -> [String: Any] {
        let hit = hits.first { hit in return hit.eventType == MediaConstants.MediaCollection.EventType.SESSION_START }
        if let hit = hit {
            return extractDebugInfo(hit: hit)
        } else {
            return [String: Any]()
        }
    }
}
