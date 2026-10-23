#!/usr/bin/env python3
"""Focused Linux network regression harness; not an Apple package build.

Symlinks production networking sources without rewriting them. Uses real Alamofire
and FoundationNetworking with explicit test-only OS lock/log/localization adapters.
No application dependency or Package.resolved is changed.
"""
import os
import pathlib
import platform
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
if platform.system() != "Linux":
    raise SystemExit("Use swift test for the full package on macOS.")
swift = os.environ.get("CY_SWIFT", "swift")
work = root / ".build/network-linux"
source_root = work / "Sources"
source_root.mkdir(parents=True, exist_ok=True)


def link(target, paths):
    directory = source_root / target
    directory.mkdir(exist_ok=True)
    for source in paths:
        destination = directory / source.name
        if destination.is_symlink():
            destination.unlink()
        destination.symlink_to(source)


network_core = root / "Sources/CYAppCore/Network"
link("CYAppCore", [p for p in network_core.glob("*.swift") if p.name != "RequestDeduplicator.swift"] + [
    root / "Sources/CYAppCore/Mock/MockNetworkClient.swift",
    root / "Sources/CYAppCore/Constants/AppConstants.swift",
    root / "Tests/NetworkHarness/PlatformSupport.swift",
])
link("os", [root / "Tests/NetworkHarness/OSLock.swift"])
link("CYAppNetwork", list((root / "Sources/CYAppNetwork/Network").glob("*.swift")))
link("NetworkValidationTests", [root / "Sources" / folder / filename for folder, filename in [
    ("CYAppNetworkTests", "NetworkClientTests.swift"),
    ("CYAppNetworkTests", "DirectResponseTests.swift"),
    ("CYAppNetworkTests", "NetworkReliabilityTests.swift"),
    ("CYAppNetworkTests", "CredentialCancellationTests.swift"),
    ("CYAppCoreTests", "MockNetworkReliabilityTests.swift"),
    ("CYAppCoreTests", "NetworkRedactionTests.swift"),
]])
(work / "Package.swift").write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "NetworkValidation", dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.12.0")
], targets: [
    .target(name: "os"),
    .target(name: "CYAppCore", dependencies: ["os"]),
    .target(name: "CYAppNetwork", dependencies: ["CYAppCore", .product(name: "Alamofire", package: "Alamofire")]),
    .testTarget(name: "NetworkValidationTests", dependencies: ["CYAppCore", "CYAppNetwork"], path: "Sources/NetworkValidationTests")
], swiftLanguageModes: [.v6])
''')
cache = work / "cache"
cache.mkdir(exist_ok=True)
environment = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(cache / "clang"))
print("Focused network harness: real transport; Apple UI, OSLog and bundle localization excluded.", flush=True)
# swift-corelibs Foundation 6.3.3 traps in InputStream.streamError during file-part
# encoding. Keep the native test intact and explicitly exclude it only in this harness.
skipped = "DirectResponseTests.testMultipartDirectResponseRecoversOnceAndHonorsEndpointTimeout"
print(f"Excluded on Linux (Foundation InputStream trap): {skipped}", flush=True)
subprocess.run([swift, "test", "--package-path", str(work), "--cache-path", str(cache / "swiftpm"),
                "--skip", skipped],
               env=environment, check=True)
