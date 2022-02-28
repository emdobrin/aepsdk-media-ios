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

@objc(AEPMobileMedia)
public class Media: NSObject, Extension {
    private static let LOG_TAG = MediaConstants.LOG_TAG
    private static let CLASS_NAME = "Media"

    public var runtime: ExtensionRuntime
    public var name = MediaConstants.EXTENSION_NAME
    public var friendlyName = MediaConstants.FRIENDLY_NAME
    public static var extensionVersion = MediaConstants.EXTENSION_VERSION
    public var metadata: [String: String]?

    #if DEBUG
        var trackers: [String: MediaEventTracking]
        var mediaService: MediaService
    #else
        private var trackers: [String: MediaEventTracking]
        private var mediaService: MediaService
    #endif

    // MARK: Extension
    /// Initializes the Media extension and it's dependencies
    public required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        let mediaHitsDatabase = MediaHitsDatabase(databaseName: MediaConstants.DATABASE_NAME)
        let mediaDBService = MediaDBService(mediaHitsDatabase: mediaHitsDatabase)
        self.mediaService = MediaService(mediaDBService: mediaDBService)
        self.trackers = [:]
    }

    /// Invoked when the Media extension has been registered by the `EventHub`
    public func onRegistered() {
        mediaService.readyToProcess(dispatchFn: dispathSessionCreated(eventData:))

        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationResponseEvent)
        registerListener(type: MediaConstants.Media.EVENT_TYPE, source: MediaConstants.Media.EVENT_SOURCE_TRACKER_REQUEST, listener: handleMediaTrackerRequest)
        registerListener(type: MediaConstants.Media.EVENT_TYPE, source: MediaConstants.Media.EVENT_SOURCE_TRACK_MEDIA, listener: handleMediaTrack)
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleSharedStateUpdate)
        registerListener(type: EventType.genericIdentity, source: EventSource.requestReset, listener: handleResetIdentitiesEvent)
        registerListener(type: EventType.edge, source: MediaConstants.Edge.EventSource.SESSION_INFO_RESPONSE, listener: handleMediaEdgeResponseHandle)
    }

    /// Invoked when the Media extension has been unregistered by the `EventHub`, currently a no-op.
    public func onUnregistered() { }

    // Media extension is always ready for processing `Event`
    /// - Parameter event: an `Event`
    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }

    /// Passes Shared State Update events to the MediaService to update the MediaState.
    /// - Parameter:
    ///   - event: The configuration response event
    private func handleSharedStateUpdate(_ event: Event) {
        mediaService.updateMediaState(event: event, getSharedState: runtime.getSharedState(extensionName:event:barrier:))
    }

    /// Processes Configuration Response content events to retrieve the configuration data and privacy status settings.
    /// - Parameter:
    ///   - event: The configuration response event
    private func handleConfigurationResponseEvent(_ event: Event) {
        handleSharedStateUpdate(event)

        if let privacyStatusStr = event.data?[MediaConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? String {
            let privacyStatus = PrivacyStatus(rawValue: privacyStatusStr) ?? PrivacyStatus.unknown
            if privacyStatus == .optedOut {
                Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Privacy status is opted-out. Clearing all tracking sessions")
                trackers.removeAll()
            }
        }
    }

    /// Processes Reset identites event
    /// - Parameter:
    ///   - event: The Reset identities event
    private func handleResetIdentitiesEvent(_ event: Event) {
        Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Clearing all tracking sessions")
        mediaService.abortAllSessions()
        trackers.removeAll()
    }

    /// Handler for media tracker creation events
    /// - Parameter event: an event containing  data for creating tracker
    private func handleMediaTrackerRequest(event: Event) {
        guard let trackerId = event.trackerId, !trackerId.isEmpty else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Public tracker ID is invalid, unable to create internal tracker.")
            return
        }

        let trackerConfig = event.trackerConfig ?? [:]

        Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Creating an internal tracker with tracker id: \(trackerId).")
        trackers[trackerId] = MediaEventTracker(hitProcessor: mediaService, config: trackerConfig)
    }

    /// Handler for media track events
    /// - Parameter event: an event containing  media event data for processing
    private func handleMediaTrack(event: Event) {
        guard let trackerId = event.trackerId, !trackerId.isEmpty else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Public tracker ID is invalid, unable to get internal tracker.")
            return
        }

        guard let tracker = trackers[trackerId] else {
            Log.error(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - Unable to find internal tracker for the given tracker ID: (\(trackerId)).")
            return
        }

        tracker.track(event: event)
    }
    
    private func handleMediaEdgeResponseHandle(event: Event) {
        // todo: implement me
        // pass event data and request id for this event handle
        guard let _ = event.data else {
            return
        }
        let edgeSessionId = event.edgeSessionId
        let requestEventId = event.requestEventId
        guard let edgeSessionId = edgeSessionId else {
            Log.debug(label: Self.LOG_TAG, "[\(Self.CLASS_NAME)<\(#function)>] - media:session event received without sessionid")
            return
        }
        
        mediaService.updateSessionInfo(requestEventId: requestEventId, backendSessionId: edgeSessionId)
        
    }

    private func dispathSessionCreated(eventData: [String: Any]) {
        let event = Event(name: MediaConstants.Media.EVENT_NAME_SESSION_CREATED,
                          type: MediaConstants.Media.EVENT_TYPE,
                          source: MediaConstants.Media.EVENT_SOURCE_SESSION_CREATED,
                          data: eventData)
        dispatch(event: event)
    }
}
