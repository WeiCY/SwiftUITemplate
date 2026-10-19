import XCTest
import CYAppCore
@testable import CYAppUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

private actor ControlledImageLoader: CYImageLoaderProtocol {
    private var pending: [URL: CheckedContinuation<Data, Error>] = [:]
    func loadImage(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { pending[url] = $0 }
    }
    func isPending(_ url: URL) -> Bool { pending[url] != nil }
    func finish(_ url: URL, result: Result<Data, Error>) { pending.removeValue(forKey: url)?.resume(with: result) }
    nonisolated func prefetch(urls: [URL]) {}
    nonisolated func clearCache() {}
}

@MainActor
final class RemoteImageRegressionTests: XCTestCase {
    private var imageData: Data {
        #if canImport(UIKit)
        return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }.pngData()!
        #else
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        return bitmap.representation(using: .png, properties: [:])!
        #endif
    }

    func testNewURLClearsOldImageAndFailedReplacementShowsError() async {
        let state = CYRemoteImageLoadState()
        let loader = ControlledImageLoader()
        let first = URL(string: "https://example.test/first")!
        let next = URL(string: "https://example.test/next")!
        let initial = Task { await state.load(url: first, imageLoader: loader, maxRetries: 0, retryDelay: 0) }
        while !(await loader.isPending(first)) { await Task.yield() }
        await loader.finish(first, result: .success(imageData))
        await initial.value
        XCTAssertNotNil(state.loadedImage)
        let replacement = Task { await state.load(url: next, imageLoader: loader, maxRetries: 0, retryDelay: 0) }
        while !(await loader.isPending(next)) { await Task.yield() }
        XCTAssertNil(state.loadedImage)
        await loader.finish(next, result: .failure(URLError(.cannotLoadFromNetwork)))
        await replacement.value
        XCTAssertNil(state.loadedImage)
        XCTAssertNotNil(state.error)
        await state.load(url: nil, imageLoader: loader, maxRetries: 0, retryDelay: 0)
        XCTAssertNil(state.loadedImage)
        XCTAssertNil(state.error)
    }

    func testLateOldResponseCannotOverwriteCurrentResource() async {
        let state = CYRemoteImageLoadState()
        let loader = ControlledImageLoader()
        let oldURL = URL(string: "https://example.test/old")!
        let newURL = URL(string: "https://example.test/new")!
        let old = Task { await state.load(url: oldURL, imageLoader: loader, maxRetries: 0, retryDelay: 0) }
        while !(await loader.isPending(oldURL)) { await Task.yield() }
        let current = Task { await state.load(url: newURL, imageLoader: loader, maxRetries: 0, retryDelay: 0) }
        while !(await loader.isPending(newURL)) { await Task.yield() }
        await loader.finish(newURL, result: .failure(URLError(.badServerResponse)))
        await current.value
        await loader.finish(oldURL, result: .success(imageData))
        await old.value
        XCTAssertNil(state.loadedImage)
        XCTAssertNotNil(state.error)
    }
    func testFailureCanRetryAndCancellationDoesNotRetry() async {
        let state = CYRemoteImageLoadState()
        let loader = ControlledImageLoader()
        let url = URL(string: "https://example.test/retry")!
        let load = Task { await state.load(url: url, imageLoader: loader, maxRetries: 1, retryDelay: 0) }
        while !(await loader.isPending(url)) { await Task.yield() }
        await loader.finish(url, result: .failure(URLError(.badServerResponse)))
        while !(await loader.isPending(url)) { await Task.yield() }
        await loader.finish(url, result: .success(imageData))
        await load.value
        XCTAssertNotNil(state.loadedImage)
        XCTAssertNil(state.error)

        let cancelled = Task { await state.load(url: url, imageLoader: loader, maxRetries: 3, retryDelay: 0) }
        while !(await loader.isPending(url)) { await Task.yield() }
        await loader.finish(url, result: .failure(ImageLoaderError.loadFailed(CancellationError())))
        await cancelled.value
        XCTAssertNil(state.error)
        let retried = await loader.isPending(url)
        XCTAssertFalse(retried)
    }

}
