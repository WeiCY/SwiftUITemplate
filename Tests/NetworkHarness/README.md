# Linux network validation adapters

Run `CY_SWIFT=/path/to/swift python3 scripts/test-network-linux.py` from the repository.
The script symlinks production sources and selected native XCTest files into an ignored
Swift package. It runs real Alamofire 5.12.0 and FoundationNetworking. These adapters
supply only Apple platform services unavailable on Linux: the OS lock, logger and
localized string lookup. They are never included in the distributed package.

This is a focused regression harness, not a supported Linux product or a substitute
for `swift test` on macOS. Its explicit exclusion for the Linux Foundation multipart
InputStream trap leaves the original Apple test intact. See
`docs/NETWORK_VALIDATION_2026-10-23.md` for exact coverage and unverified areas.
