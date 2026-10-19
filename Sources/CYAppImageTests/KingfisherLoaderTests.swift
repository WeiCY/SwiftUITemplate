import Foundation
import Synchronization
import Kingfisher
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import CYAppImage

private final class ImageURLProtocol: URLProtocol, @unchecked Sendable {
    struct Handler: Sendable {
        var start: (@Sendable (ImageURLProtocol) -> Void)?
        var stop: (@Sendable () -> Void)?
    }
    static let handler = Mutex(Handler())
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler.withLock { $0.start }?(self) }
    override func stopLoading() { Self.handler.withLock { $0.stop }?() }

    func succeed(_ data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class KingfisherLoaderTests: XCTestCase {
    private func makeLoader() -> (CYKingfisherImageLoader, ImageCache) {
        let downloader = ImageDownloader(name: UUID().uuidString)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageURLProtocol.self]
        downloader.sessionConfiguration = configuration
        let cache = ImageCache(name: UUID().uuidString)
        return (CYKingfisherImageLoader(manager: KingfisherManager(downloader: downloader, cache: cache)), cache)
    }

    override func tearDown() {
        ImageURLProtocol.handler.withLock { $0 = .init() }
        super.tearDown()
    }

    func testCancellationReachesActualDownload() async {
        let started = expectation(description: "download started")
        let stopped = expectation(description: "download stopped")
        ImageURLProtocol.handler.withLock { handler in
            handler.start = { _ in started.fulfill() }
            handler.stop = { stopped.fulfill() }
        }
        let (loader, _) = makeLoader()
        let task = Task { try await loader.loadImage(from: URL(string: "https://fake.test/cancel.png")!) }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        await fulfillment(of: [stopped], timeout: 3)
    }

    func testNetworkReturnsOriginalBytesAndMemoryCacheStillWorks() async throws {
        let pixels = Data([255, 0, 0, 255, 0, 255, 0, 255])
        let image = CGImage(width: 2, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: CGDataProvider(data: pixels as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let buffer = NSMutableData()
        let destination = CGImageDestinationCreateWithData(buffer, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let data = buffer as Data
        let calls = Mutex(0)
        ImageURLProtocol.handler.withLock { handler in
            handler.start = { request in calls.withLock { $0 += 1 }; request.succeed(data) }
        }
        let (loader, cache) = makeLoader()
        defer { cache.clearMemoryCache(); cache.clearDiskCache() }
        let url = URL(string: "https://fake.test/original.png")!
        let result = try await loader.loadImage(from: url)
        XCTAssertEqual(result, data)
        let cached = try await loader.loadImage(from: url)
        XCTAssertFalse(cached.isEmpty)
        XCTAssertEqual(calls.withLock { $0 }, 1)
    }
}
