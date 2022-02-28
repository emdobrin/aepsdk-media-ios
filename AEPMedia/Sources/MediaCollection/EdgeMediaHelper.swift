//
//  EdgeMediaHelper.swift
//  AEPMedia
//
//  Created by Emilia Dobrin on 2/16/22.
//

import Foundation

class EdgeMediaHelper {
    static let eventTypeMappingToXDM = [
        MediaConstants.MediaCollection.EventType.SESSION_START: MediaConstants.Edge.XDMEventType.SESSION_START,
        MediaConstants.MediaCollection.EventType.SESSION_COMPLETE: MediaConstants.Edge.XDMEventType.SESSION_COMPLETE,
        MediaConstants.MediaCollection.EventType.CHAPTER_START: MediaConstants.Edge.XDMEventType.CHAPTER_START,
        MediaConstants.MediaCollection.EventType.CHAPTER_COMPLETE: MediaConstants.Edge.XDMEventType.CHAPTER_COMPLETE,
        MediaConstants.MediaCollection.EventType.AD_START: MediaConstants.Edge.XDMEventType.AD_START,
        MediaConstants.MediaCollection.EventType.AD_COMPLETE: MediaConstants.Edge.XDMEventType.AD_COMPLETE
        // TODO: add the other event types
    ]
}
