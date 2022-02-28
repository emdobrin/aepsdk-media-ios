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

struct XDMMediaExperienceEvent: Encodable {
    init() {}
    var media: XDMMediaInfo?
    var eventType: String?
}

struct XDMMediaInfo: Encodable {
    init() {}
    var mediaTimed: XDMMediaTimed?
}

struct XDMMediaTimed: Encodable {
    init() {}
    var primaryAssetReference: XDMPrimaryAssetReference?
    var primaryAssetViewDetails: XDMPrimaryAssetViewDetails?
}

struct XDMPrimaryAssetReference: Encodable {
    init() {}
    var _id: String? // media.asset ? TODO: should this be media.id
    var showType: String? // media.type
    var streamFormat: String? // media.format
    var streamType: String? // media.streamType
    // var show: iptc4xmpExt? - iptc4xmpExt:Series.iptc4xmpExt:Name = media.show
    //var dc:title = media.name
}

struct XDMPrimaryAssetViewDetails: Encodable {
    init() {}
    var vhlVersion: String?
    var playerSDKVersion: XDMPlayerSDKVersion?
    var broadcastChannel: String? // media.channel
    var playerName: String? // media.playerName
}

struct XDMPlayerSDKVersion: Encodable {
    init() {}
    var version: String? // media.sdkVersion
}
