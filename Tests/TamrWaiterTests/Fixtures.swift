import Foundation

/// A shared fixture from `packages/sdk-contract/fixtures`, copied here by `pnpm sdk:generate`.
func fixture(_ name: String) throws -> [String: Any] {
    let url = try XCTUnwrapURL(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
}

private func XCTUnwrapURL(_ url: URL?) throws -> URL {
    guard let url else { throw CocoaError(.fileNoSuchFile) }
    return url
}
