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
import AEPCore

// extension for the `Event`, provides some convenience methods
extension Event {
    
    var requestEventId: String {
        return data?[MediaConstants.Edge.EventData.REQUEST_EVENT_ID] as? String ?? ""
    }
    
    var edgeSessionId: String? {
        guard let payload = data?[MediaConstants.Edge.EventData.PAYLOAD] as? [[String: Any]] else {
            return nil
            }
            
        return payload[0][MediaConstants.Edge.EventData.SESSION_ID] as? String ?? nil
    }
}
