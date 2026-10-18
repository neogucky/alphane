# Platform scope

Alphane maintains and releases the Apple TV app, using the `Alphane tvOS` scheme. This builds the app and its Top Shelf extension; `Alphane tvOS Tests` covers regressions. CI and TestFlight automation target tvOS only.

The repository is **not yet a tvOS-only source tree**. Audit on 2026-10-18 found:

- The inherited `Alphane iOS` Xcode target and shared `Alphane.xcscheme` still exist.
- `Alphane/` contains 138 tracked files of inherited iOS-specific source/resources. The tvOS target uses its own `Alphane tvOS/` group and shared code.
- 76 `Shared` Swift files contain `#if os(iOS)` branches; `PlatformView` also retains an iOS presentation API.
- `AlphaneMacros` and `PreferencesView` still declare iOS alongside tvOS as supported package platforms. These declarations do not cause an iOS app build.
- The hand-written Fastlane build helper retains iPhone SDK/platform fallbacks. Generated Fastlane API bindings also mention iOS; those are tooling definitions, not app support.
- Issue templates still offer iOS, and inherited documentation/availability checks contain platform references.

These leftovers are outside the maintained build/release scope. Their presence does not mean the iOS app builds or retains Alphane's current behavior. Removing the target/source tree is a separate cleanup; do not blindly delete shared code, package compatibility, third-party bindings, licensing or platform availability guards.

Future Swiftfin merges follow the selective technical-update policy in [AGENTS.md](../AGENTS.md). Do not re-enable iOS releases or import iOS-only changes by default.
