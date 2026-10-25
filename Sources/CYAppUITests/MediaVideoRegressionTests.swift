#if canImport(UIKit) && canImport(PhotosUI)
import XCTest
@testable import CYAppUI

@MainActor
final class MediaVideoRegressionTests: XCTestCase {
    func testImportedVideoSurvivesProviderFileRemovalAndCleansUp() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        let data = Data("video fixture".utf8)
        try data.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        var copiedURL: URL?
        do {
            let file = try CYMediaVideoFile.copy(from: source)
            let item = CYMediaItem(videoFile: file)
            copiedURL = item.videoURL
            try FileManager.default.removeItem(at: source)
            XCTAssertTrue(item.isVideo)
            let loaded = await item.loadData()
            XCTAssertEqual(loaded, data)
            XCTAssertNotEqual(item.videoURL, source)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(copiedURL).path))
    }

    func testCallerOwnedVideoIsNotDeleted() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        try Data("video".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        do {
            let item = CYMediaItem(videoURL: source)
            XCTAssertTrue(item.isVideo)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testVideoDataLimitAndExactBoundary() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bytes = Data(repeating: 42, count: 9)
        try bytes.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let item = CYMediaItem(videoURL: source)
        do {
            _ = try await item.loadVideoData(maximumBytes: 8)
            XCTFail("Oversized video must fail")
        } catch let error as CocoaError {
            XCTAssertEqual(error.code, .fileReadTooLarge)
        }
        let exact = try await item.loadVideoData(maximumBytes: 9)
        XCTAssertEqual(exact, bytes)
    }

    func testPrecancelledVideoReadReturnsCancellation() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let item = CYMediaItem(videoURL: source)
        let task = Task { try await item.loadVideoData() }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled read must not touch the nonexistent file")
        } catch is CancellationError {
            // Expected; a filesystem error would mean cancellation was ignored.
        }
    }

}
#endif
