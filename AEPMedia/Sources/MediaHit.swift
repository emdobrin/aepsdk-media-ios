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

struct MediaHit: Codable {
    /// Media Hit type
    private (set) var eventType: String

    /// Media Hit parameters
    private (set) var params: [String: Any]?

    /// Media Hit metadata
    private (set) var metadata: [String: String]?

    /// Media Hit QoE data
    private (set) var qoeData: [String: Any]?

    /// Media Hit playhead
    private (set) var playhead: Double = 0

    /// Media Hit timestamp
    private (set) var timestamp: Int64 = 0

    enum CodingKeys: String, CodingKey {
        case eventType = "eventType"
        case params = "params"
        case metadata = "customMetadata"
        case qoeData = "qoeData"
        case playerTime = "playerTime"
    }

    init(eventType: String, playhead: Double, ts: Int64, params: [String: Any]? = nil, customMetadata: [String: String]? = nil, qoeData: [String: Any]? = nil) {
        self.eventType = eventType
        self.params = params
        self.metadata = customMetadata
        self.qoeData = qoeData
        self.playhead = playhead
        self.timestamp = ts
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.eventType = try values.decode(String.self, forKey: .eventType)

        if let anyCodableParams = try? values.decode([String: AnyCodable].self, forKey: .params) {
            self.params = anyCodableParams.asDictionary()
        }
        if let metadata = try? values.decode([String: String].self, forKey: .metadata) {
            self.metadata = metadata
        }
        if let anyCodableQoeData = try? values.decode([String: AnyCodable].self, forKey: .qoeData) {
            self.qoeData = anyCodableQoeData.asDictionary()
        }

        if let playerTime = try? values.decode([String: AnyCodable].self, forKey: .playerTime) {
            self.timestamp = Int64(readNumber(playerTime[MediaConstants.MediaCollection.PlayerTime.TS]))
            self.playhead = Double(readNumber(playerTime[MediaConstants.MediaCollection.PlayerTime.PLAYHEAD]))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)

        if let params = params, !params.isEmpty {
            try container.encode(AnyCodable.from(dictionary: params), forKey: .params)
        }
        if let metadata = metadata, !metadata.isEmpty {
            try container.encode(metadata, forKey: .metadata)
        }
        if let qoeData = qoeData, !qoeData.isEmpty {
            try container.encode(AnyCodable.from(dictionary: qoeData), forKey: .qoeData)
        }
        let playerTime: [String: Any] = [
            MediaConstants.MediaCollection.PlayerTime.TS: timestamp,
            MediaConstants.MediaCollection.PlayerTime.PLAYHEAD: playhead
        ]
        try container.encode(AnyCodable.from(dictionary: playerTime), forKey: .playerTime)
    }
    
    func asDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }
        
        return try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] ?? nil
    }

    private func readNumber(_ val: AnyCodable?) -> Double {
        guard let val = val else {
            return 0
        }

        if let val = val.doubleValue {
            return Double(val)
        } else if let val = val.longValue {
            return Double(val)
        } else if let val = val.intValue {
            return Double(val)
        } else {
            return 0
        }
    }
}
