# Platform scope

Alphane is an Apple TV app. The `Alphane tvOS` scheme builds the app and its Top Shelf extension; `Alphane tvOS Tests` covers regressions. CI, TestFlight, package platform declarations and the handwritten build helpers target tvOS.

The inherited iOS app target, scheme, `Alphane/` source/resources, mobile-only permissions, touch gesture settings and unused mobile management models have been removed. Shared views retain their tvOS implementation without an iOS presentation adapter. Keep code used by tvOS, including profile security, playback preferences, subtitle search and Siri Remote scrubbing.

Some platform names remain intentionally:

- Xcode's `com.apple.ApplicationGroups.iOS` capability identifier also enables tvOS App Groups and Top Shelf sharing.
- The macro package retains macOS support because compiler plugins and their tests run on the build host.
- Server-client identification recognises other clients, including iOS devices; that is Jellyfin interoperability, not an iOS app implementation.
- An inherited device-authentication policy still decodes from saved records but is unavailable as a setting and fails authentication on tvOS. Removing its serialized value must not silently bypass an existing security requirement.
- Generated Fastlane bindings, dependency lockfiles and third-party compatibility declarations can mention other platforms. They do not create an Alphane iOS target or release.
- Swiftfin licensing, attribution and historical audit records remain intact.

Future Swiftfin updates must preserve this scope, reject reintroduced iOS-only code/settings and still use a real merge. See [AGENTS.md](../AGENTS.md).
