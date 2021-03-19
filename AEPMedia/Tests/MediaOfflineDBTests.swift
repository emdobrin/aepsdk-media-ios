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

import XCTest
@testable import AEPCore
@testable import AEPMedia
import AEPServices

class MediaOfflineDBTests: XCTestCase {
    
    private var offlineDb: MediaOfflineDB!
    private let databaseFilePath = FileManager.SearchPathDirectory.cachesDirectory
    private let fileName = "MediaOfflineDBTests"
    private let params = ["key": "value", "true": true] as [String: Any]
    private let metadata = ["isUserLoggedIn": "false", "tvStation": "SampleTVStation"] as [String: String]
    private let qoeData = ["qoe.startuptime": 0, "qoe.fps": 24, "qoe.droppedframes": 10, "qoe.bitrate": 60000] as [String: Any]
    
    override func setUp() {
        MediaOfflineDBTests.removeDbFileIfExists(fileName)
        let dispatchQueue = DispatchQueue.init(label: fileName)
        offlineDb = MediaOfflineDB(databaseName: fileName, databaseFilePath: databaseFilePath, serialQueue: dispatchQueue)
    }
    
    override func tearDown() {}
    
    internal static func removeDbFileIfExists(_ fileName: String) {
        let fileURL = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try! FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func getHitFromDataEntity(entity: DataEntity) -> MediaHit? {
        var hit: MediaHit?
        if let data = entity.data, let retrievedHit = try? JSONDecoder().decode(MediaHit.self, from: data) {
            hit = retrievedHit
        }
        return hit
    }
    
    func testCreateDbWithInvalidDatabaseName() throws {
        // setup
        let dispatchQueue = DispatchQueue.init(label: fileName)
        offlineDb = MediaOfflineDB(databaseName: "", databaseFilePath: databaseFilePath, serialQueue: dispatchQueue)
        // verify
        XCTAssertNil(offlineDb)
    }
    
    func testDbAdd() throws {
        // setup and test
        let sessionId = UUID().uuidString
        var addedHits: [MediaHit] = []
        for i in 1 ... 3 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.0, ts: Double(i) * 100.0, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: sessionId, dataEntity: entity)
            addedHits.append(mediaHit)
        }
        // verify
        XCTAssertEqual(3, offlineDb.count())
        guard let entities = offlineDb.getEntitiesFor(sessionId: sessionId) else {
            XCTFail("Failed to retrieve entities from the database")
            return
        }
        var index = 0
        for entityTuple in entities {
            let retrievedHit = getHitFromDataEntity(entity: entityTuple.entity)
            XCTAssertEqual(sessionId, entityTuple.sessionId)
            XCTAssertEqual(retrievedHit, addedHits[index])
            index += 1
        }
    }
    
    func testDbAddWithNonWholeNumbers() throws {
        // setup and test
        let sessionId = UUID().uuidString
        var addedHits: [MediaHit] = []
        for i in 1 ... 3 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.123456789, ts: Date().timeIntervalSince1970, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: sessionId, dataEntity: entity)
            addedHits.append(mediaHit)
        }
        // verify that non whole number playhead and timestamp values are valid
        XCTAssertEqual(3, offlineDb.count())
        guard let entities = offlineDb.getEntitiesFor(sessionId: sessionId) else {
            XCTFail("Failed to retrieve entities from the database")
            return
        }
        var index = 0
        for entityTuple in entities {
            let retrievedHit = getHitFromDataEntity(entity: entityTuple.entity)
            XCTAssertEqual(sessionId, entityTuple.sessionId)
            XCTAssertEqual(retrievedHit, addedHits[index])
            index += 1
        }
    }
    
    func testDbClear() throws {
        // setup and test
        let sessionId = UUID().uuidString
        for i in 1 ... 10 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.0, ts: Double(i) * 100.0, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: sessionId, dataEntity: entity)
        }
        // verify
        XCTAssertEqual(10, offlineDb.count())
        XCTAssertTrue(offlineDb.clear())
        XCTAssertEqual(0, offlineDb.count())
    }
    
    func testDbDeleteForSessionId() throws {
        // setup and test
        let sessionId = UUID().uuidString
        var addedHits: [MediaHit] = []
        for i in 1 ... 10 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.0, ts: Double(i) * 100.0, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: sessionId, dataEntity: entity)
            addedHits.append(mediaHit)
        }
        XCTAssertEqual(10, offlineDb.count())
        let anotherSessionId = UUID().uuidString
        for i in 11 ... 20 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.0, ts: Double(i) * 100.0, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: anotherSessionId, dataEntity: entity)
        }
        // verify
        XCTAssertEqual(20, offlineDb.count())
        XCTAssertTrue(offlineDb.deleteEntitiesFor(sessionId: anotherSessionId))
        XCTAssertEqual(10, offlineDb.count())
        guard let entities = offlineDb.getEntitiesFor(sessionId: sessionId) else {
            XCTFail("Failed to retrieve entities from the database")
            return
        }
        var index = 0
        for entityTuple in entities {
            let retrievedHit = getHitFromDataEntity(entity: entityTuple.entity)
            XCTAssertEqual(sessionId, entityTuple.sessionId)
            XCTAssertEqual(retrievedHit, addedHits[index])
            index += 1
        }
    }
    
    func testDbPeekWithArgument() throws {
        // setup and test
        let sessionId = UUID().uuidString
        var addedHits: [MediaHit] = []
        for i in 1 ... 10 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.0, ts: Double(i) * 100.0, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: sessionId, dataEntity: entity)
            addedHits.append(mediaHit)
        }
        // verify
        XCTAssertEqual(10, offlineDb.count())
        guard let entities = offlineDb.peek(n: 5) else {
            XCTFail("Failed to retrieve entities from the database")
            return
        }
        var index = 0
        for entityTuple in entities {
            let retrievedHit = getHitFromDataEntity(entity: entityTuple.entity)
            XCTAssertEqual(sessionId, entityTuple.sessionId)
            XCTAssertEqual(retrievedHit, addedHits[index])
            index += 1
        }
    }
    
    func testDbPeekWithInvalidArgument() throws {
        // setup and test
        let sessionId = UUID().uuidString
        var addedHits: [MediaHit] = []
        for i in 1 ... 10 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.0, ts: Double(i) * 100.0, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: sessionId, dataEntity: entity)
            addedHits.append(mediaHit)
        }
        // verify
        XCTAssertEqual(10, offlineDb.count())
        XCTAssertNil( offlineDb.peek(n: -5))
    }
    
    func testDbPeek() throws {
        // setup and test
        let sessionId = UUID().uuidString
        var addedHits: [MediaHit] = []
        for i in 1 ... 5 {
            let eventId = UUID().uuidString
            let mediaHit = MediaHit(eventType: MediaConstants.Media.EVENT_TYPE, playhead: Double(i) * 50.0, ts: Double(i) * 100.0, params: params, customMetadata: metadata, qoeData: qoeData)
            let data = try JSONEncoder().encode(mediaHit)
            let entity = DataEntity(uniqueIdentifier: eventId, timestamp: Date(), data: data)
            _ = offlineDb.add(sessionId: sessionId, dataEntity: entity)
            addedHits.append(mediaHit)
        }
        // verify
        XCTAssertEqual(5, offlineDb.count())
        guard let entityTuple = offlineDb.peek() else {
            XCTFail("Failed to retrieve entity from the database")
            return
        }
        let retrievedHit = getHitFromDataEntity(entity: entityTuple.entity)
        XCTAssertEqual(sessionId, entityTuple.sessionId)
        XCTAssertEqual(retrievedHit, addedHits[0])
    }
}
