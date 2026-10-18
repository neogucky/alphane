// Documentation-only compositor. Run on macOS with Xcode's Swift toolchain.
// The UI is reconstructed from the app's tvOS view sources; no app or server state is changed.
import AppKit
import CryptoKit
import SwiftUI

struct Media: Decodable, Identifiable {
    let id: String
    let title: String
    let year: Int
    let type: String
    let genres: [String]
    let overview: String
    let runtimeSeconds: Int?
    let resumeSeconds: Int?
    let backdrop: String?
}

struct Episode: Decodable, Identifiable {
    let id: String
    let seriesID: String
    let title: String
    let season: Int
    let episode: Int
    let year: Int
    let runtimeSeconds: Int
    let resumeSeconds: Int?
    let overview: String
    let frame: String?
    var artworkPath: String { frame.map { "frames/\($0)" } ?? "covers/\(seriesID).png" }
    var locator: String { "S\(season):E\(episode)" }
    var runtime: String { "\(runtimeSeconds / 60)m" }
}

struct Catalog: Decodable {
    let featuredSeries: String
    let items: [Media]
    let episodes: [Episode]
    let screens: Screens
}

struct Screens: Decodable {
    let home: HomePlan
    let discovery: DiscoveryPlan
}
struct HomePlan: Decodable {
    let featuredEpisode: String
    let `continue`: [String]
}
struct DiscoveryPlan: Decodable { let rows: [DiscoveryRow] }
struct DiscoveryRow: Decodable { let title: String; let ids: [String] }

let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().standardizedFileURL
let outputDirectory = directory.deletingLastPathComponent()
let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: directory.appendingPathComponent("catalog.json")))
let themeBackground = Color(red: 24 / 255, green: 26 / 255, blue: 29 / 255)
let surface = Color(red: 40 / 255, green: 43 / 255, blue: 48 / 255)
let secondary = Color.white.opacity(0.8)
let screenWidth: CGFloat = 1920
let screenHeight: CGFloat = 1080
let edge: CGFloat = 60
let posterWidth: CGFloat = (1920 - 120 - 4 * 40) / 5
let posterHeight = posterWidth * 9 / 16

enum PreviewColorTheme: String, CaseIterable {
    case noAccent, aqua, amber

    var title: String {
        switch self {
        case .noAccent: "No accent"
        case .aqua: "Aqua"
        case .amber: "Amber"
        }
    }

    // Match AlphaneColorTheme.noAccent / .cold / .warm.
    var accent: Color {
        switch self {
        case .noAccent: .white
        case .aqua: Color(red: 106 / 255, green: 214 / 255, blue: 202 / 255)
        case .amber: Color(red: 225 / 255, green: 180 / 255, blue: 113 / 255)
        }
    }
}

private struct PreviewColorThemeKey: EnvironmentKey {
    static let defaultValue = PreviewColorTheme.noAccent
}

extension EnvironmentValues {
    var previewColorTheme: PreviewColorTheme {
        get { self[PreviewColorThemeKey.self] }
        set { self[PreviewColorThemeKey.self] = newValue }
    }
}

func media(_ id: String) -> Media { catalog.items.first { $0.id == id }! }
func episode(_ number: Int) -> Episode { catalog.episodes.first { $0.seriesID == catalog.featuredSeries && $0.episode == number }! }
func duration(_ seconds: Int) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: TimeInterval(seconds))!
}
func timestamp(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
func artwork(_ relativePath: String) -> Image {
    let path = directory.appendingPathComponent(relativePath).path
    guard let image = NSImage(contentsOfFile: path) else { fatalError("Missing artwork: \(path)") }
    return Image(nsImage: image)
}

struct Canvas<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        ZStack(alignment: .topLeading) {
            themeBackground
            content()
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .topLeading)
        .clipped()
        .environment(\.colorScheme, .dark)
    }
}

struct Cover: View {
    @Environment(\.previewColorTheme) private var colorTheme

    let path: String
    var width: CGFloat = posterWidth
    var height: CGFloat = posterHeight
    var focused = false
    var progress: Double? = nil
    var remaining: String? = nil
    var body: some View {
        artwork(path)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .overlay(alignment: .bottomLeading) {
                if let progress, let remaining {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(remaining)
                            .font(.system(size: 23, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.72), in: Capsule())
                            .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
                            .padding(.horizontal, 10)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(colorTheme.accent.opacity(0.3))
                                Capsule().fill(colorTheme.accent).frame(width: geometry.size.width * progress)
                            }
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 5)
                    }
                    .padding(.bottom, 5)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: width / 30))
            .overlay {
                if focused {
                    RoundedRectangle(cornerRadius: width / 30)
                        .inset(by: -3)
                        .stroke(.white, lineWidth: 6)
                        .shadow(color: .black.opacity(0.8), radius: 2)
                }
            }
    }
}

struct Poster: View {
    let id: String
    var focused = false
    var showsProgress = false
    private var episodeItem: Episode? { catalog.episodes.first { $0.id == id } }
    private var runtime: Int? { episodeItem?.runtimeSeconds ?? catalog.items.first { $0.id == id }?.runtimeSeconds }
    private var resume: Int? { episodeItem?.resumeSeconds ?? catalog.items.first { $0.id == id }?.resumeSeconds }
    private var progress: Double? {
        guard showsProgress, let runtime, let resume else { return nil }
        return Double(resume) / Double(runtime)
    }
    private var remaining: String? {
        guard showsProgress, let runtime, let resume else { return nil }
        return duration(runtime - resume)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Cover(path: episodeItem?.artworkPath ?? "covers/\(id).png", focused: focused, progress: progress, remaining: remaining)
            if let episodeItem {
                VStack(alignment: .leading, spacing: 2) {
                    Text(episodeItem.title).font(.system(size: 23))
                    Text(episodeItem.locator).font(.system(size: 20, weight: .medium)).foregroundStyle(secondary)
                }
            } else {
                Text(media(id).title)
                    .font(.system(size: 23))
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .foregroundStyle(Color.white.opacity(focused ? 1 : 0.8))
        .frame(width: posterWidth, alignment: .topLeading)
    }
}

struct NavigationHeader: View {
    var body: some View {
        HStack(spacing: 20) {
            ForEach(["Home", "TV Shows", "Movies", "Search", "Media", "Settings"], id: \.self) { title in
                Text(title)
                    .font(.system(size: 26, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
                    .foregroundStyle(title == "Home" ? Color.black : secondary)
                    .background {
                        if title == "Home" { Capsule().fill(.white.opacity(0.8)) }
                    }
            }
        }
        .frame(width: screenWidth, height: 80)
    }
}

struct HomePreview: View {
    @Environment(\.previewColorTheme) private var colorTheme

    var body: some View {
        Canvas {
            artwork(media(catalog.featuredSeries).backdrop!)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: screenWidth, height: screenHeight).clipped()
                .overlay {
                    LinearGradient(stops: [.init(color: themeBackground.opacity(0.85), location: 0), .init(color: themeBackground.opacity(0.72), location: 0.4), .init(color: .clear, location: 0.75)], startPoint: .leading, endPoint: .trailing)
                }
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.5), .init(color: themeBackground.opacity(0.8), location: 0.82), .init(color: themeBackground, location: 1)], startPoint: .top, endPoint: .bottom)
                }
            NavigationHeader()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    if colorTheme != .noAccent {
                        RoundedRectangle(cornerRadius: 2).fill(colorTheme.accent).frame(width: 3, height: 18)
                    }
                    Text("Continue").font(.system(size: 23, weight: .semibold)).foregroundStyle(secondary)
                }
                Text(media(catalog.featuredSeries).title)
                    .font(.system(size: 54, weight: .bold))
                    .lineLimit(2, reservesSpace: true)
                Text("\(episode(3).title) · \(episode(3).locator) · \(duration(episode(3).runtimeSeconds))")
                    .font(.system(size: 29)).foregroundStyle(secondary)
                Text(episode(3).overview)
                    .font(.system(size: 23)).foregroundStyle(secondary)
                    .lineLimit(3, reservesSpace: true)
            }
            .foregroundStyle(.white)
            .frame(width: 900, alignment: .leading)
            .offset(x: edge, y: 359)
            HStack(alignment: .top, spacing: 40) {
                ForEach(catalog.screens.home.continue, id: \.self) { id in
                    Poster(id: id, focused: id == catalog.screens.home.featuredEpisode, showsProgress: true)
                }
            }
            .frame(width: screenWidth - edge * 2, alignment: .leading)
            .offset(x: edge, y: 755)
        }
    }
}

struct DiscoveryPreview: View {
    func row(_ title: String, _ ids: [String], y: CGFloat, focused: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 30) {
            Text(title).font(.system(size: 29, weight: .semibold))
            HStack(alignment: .top, spacing: 40) {
                ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                    Poster(id: id, focused: focused && index == 0)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(width: screenWidth - edge * 2, alignment: .leading)
        .offset(x: edge, y: y)
    }
    var body: some View {
        Canvas {
            // Home's navigation header is fully hidden at this scroll position.
            ForEach(Array(catalog.screens.discovery.rows.enumerated()), id: \.offset) { index, definition in
                row(definition.title, definition.ids, y: CGFloat(80 + index * 360), focused: index == 0)
            }
        }
    }
}

struct ActionPill: View {
    let title: String
    let symbol: String
    var filled = false
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 24))
            Text(title).font(.system(size: 30, weight: .semibold))
        }
        .frame(minWidth: 160)
        .foregroundStyle(filled ? Color.black : secondary)
        .padding(.horizontal, 28)
        .frame(height: 64)
        .background(filled ? Color.white : Color.clear, in: Capsule())
    }
}

struct FinishedPreview: View {
    @Environment(\.previewColorTheme) private var colorTheme

    var body: some View {
        Canvas {
            artwork(media(catalog.featuredSeries).backdrop!)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: screenWidth, height: screenHeight, alignment: .top)
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: themeBackground.opacity(0.02), location: 0.24), .init(color: themeBackground.opacity(0.56), location: 0.52), .init(color: themeBackground.opacity(0.94), location: 0.76), .init(color: themeBackground, location: 1)], startPoint: .top, endPoint: .bottom)
                }
                .overlay { LinearGradient(colors: [themeBackground.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing) }
            HStack(alignment: .bottom, spacing: 72) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(media(catalog.featuredSeries).title).font(.system(size: 22, weight: .medium)).foregroundStyle(secondary)
                    Text(episode(3).title).font(.system(size: 52, weight: .semibold))
                    Text("\(media(catalog.featuredSeries).genres.first!) · \(String(episode(3).year)) · \(duration(episode(3).runtimeSeconds)) · \(episode(3).locator)")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(secondary)
                    Text(episode(3).overview)
                        .font(.system(size: 24)).foregroundStyle(secondary)
                        .lineSpacing(5).lineLimit(3)
                        .padding(.vertical, 8)
                        .frame(maxWidth: 1040, alignment: .leading)
                    HStack(spacing: 20) {
                        Text("HD").padding(.horizontal, 4).padding(.vertical, 1)
                            .foregroundStyle(themeBackground)
                            .background(secondary, in: RoundedRectangle(cornerRadius: 2))
                        Text("CC").padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay { RoundedRectangle(cornerRadius: 2).stroke(secondary, lineWidth: 1) }
                    }.font(.system(size: 18)).foregroundStyle(secondary)
                    HStack(spacing: 28) {
                        HStack(spacing: 20) {
                            ActionPill(title: "Play", symbol: "play.fill")
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(colorTheme.accent.opacity(colorTheme == .noAccent ? 1 : 0.8))
                                .frame(width: 80, height: 48)
                            Image(systemName: "heart").font(.system(size: 28, weight: .medium))
                                .foregroundStyle(secondary).frame(width: 80, height: 48)
                            Image(systemName: "slider.horizontal.3").font(.system(size: 28, weight: .medium))
                                .foregroundStyle(secondary).frame(width: 80, height: 48)
                        }
                        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 28)
                        HStack(spacing: 10) {
                            Text("Seasons")
                            Image(systemName: "chevron.down").font(.system(size: 20))
                        }.font(.system(size: 26, weight: .semibold)).foregroundStyle(secondary)
                    }
                    .padding(.top, 12)
                }
                .foregroundStyle(.white)
                .frame(width: 1368, alignment: .leading)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Next").font(.system(size: 24, weight: .medium))
                    Cover(path: episode(4).artworkPath, width: 360, height: 202.5, focused: true)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(episode(4).title).font(.system(size: 26, weight: .medium))
                        Text("\(episode(4).locator) · \(episode(4).runtime)").font(.system(size: 20))
                    }
                }
                .foregroundStyle(.white)
            }
            .padding(.top, screenHeight * 0.34)
            .padding(.bottom, 150)
            .frame(width: screenWidth - edge * 2)
            .frame(minHeight: screenHeight, alignment: .bottom)
            .offset(x: edge)
            VStack(spacing: 8) {
                Text("Down for more info").font(.system(size: 20, weight: .medium))
                Image(systemName: "chevron.down").font(.system(size: 20, weight: .medium))
            }
            .foregroundStyle(secondary)
            .frame(width: screenWidth)
            .offset(y: 978)
        }
    }
}

struct CinemaControl: View {
    let title: String
    let symbol: String
    var focused = false
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 24, weight: .medium)).frame(height: 30)
            Text(title).font(.system(size: 18, weight: .medium)).frame(height: 24)
        }
        .frame(width: 120, height: 80)
        .foregroundStyle(focused ? Color.black : secondary)
        .background(focused ? Color.white : .clear, in: Capsule())
    }
}

struct VideoPreview: View {
    @Environment(\.previewColorTheme) private var colorTheme

    let progress = Double(episode(3).resumeSeconds!) / Double(episode(3).runtimeSeconds)
    var body: some View {
        Canvas {
            artwork(episode(3).artworkPath)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(width: screenWidth, height: screenHeight).clipped()
                .overlay {
                    // EasedGradient's default smoothstep curve, sampled as in the app.
                    LinearGradient(stops: (0...32).map { index in
                        let t = Double(index) / 32
                        return .init(color: themeBackground.opacity(0.98 * t * t * (3 - 2 * t)), location: CGFloat(t))
                    }, startPoint: .center, endPoint: .bottom)
                }
            HStack(alignment: .bottom, spacing: 48) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(media(catalog.featuredSeries).title).font(.system(size: 22, weight: .medium)).foregroundStyle(secondary)
                    Text(episode(3).title).font(.system(size: 34, weight: .semibold))
                    Text(episode(3).locator).font(.system(size: 18, weight: .medium)).foregroundStyle(secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 20) {
                    CinemaControl(title: "Episodes", symbol: "rectangle.stack")
                    CinemaControl(title: "Audio", symbol: "speaker.wave.2", focused: true)
                    CinemaControl(title: "Subtitles", symbol: "captions.bubble")
                    CinemaControl(title: "More", symbol: "ellipsis")
                }
            }
            .foregroundStyle(.white)
            .frame(width: screenWidth - edge * 2)
            .offset(x: edge, y: 882)
            ZStack(alignment: .leading) {
                Capsule().fill(colorTheme.accent.opacity(0.16))
                Capsule().fill(colorTheme.accent.opacity(0.45)).frame(width: (screenWidth - edge * 2) * progress)
            }
            .frame(width: screenWidth - edge * 2, height: 4)
            .overlay(alignment: .leading) {
                Circle().fill(secondary).frame(width: 16, height: 16)
                    .offset(x: (screenWidth - edge * 2) * progress - 8)
            }
            .offset(x: edge, y: 996)
            HStack(spacing: 8) {
                Text(timestamp(episode(3).resumeSeconds!)).monospacedDigit()
                Image(systemName: "pause.circle")
            }
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(secondary)
            .offset(x: edge + (screenWidth - edge * 2) * progress - 47, y: 1018)
            Text("−\(timestamp(episode(3).runtimeSeconds - episode(3).resumeSeconds!))").font(.system(size: 22, weight: .medium)).monospacedDigit()
                .foregroundStyle(secondary)
                .frame(width: 100, alignment: .trailing)
                .offset(x: screenWidth - edge - 100, y: 1018)
        }
    }
}

let comparisonWidth: CGFloat = 2880
let comparisonHeight: CGFloat = 780

struct ColorSchemesPreview: View {
    private let panelWidth: CGFloat = 896

    var body: some View {
        ZStack(alignment: .topLeading) {
            themeBackground
            HStack(alignment: .top, spacing: 32) {
                ForEach(PreviewColorTheme.allCases, id: \.self) { theme in
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 16) {
                            Circle().fill(theme.accent).frame(width: 16, height: 16)
                            Text(theme.title).font(.system(size: 38, weight: .semibold))
                            if theme == .noAccent {
                                Text("Default").font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(secondary)
                            }
                        }
                        .frame(height: 50, alignment: .leading)
                        HomePreview()
                            .environment(\.previewColorTheme, theme)
                            .scaleEffect(panelWidth / screenWidth, anchor: .topLeading)
                            .frame(width: panelWidth, height: panelWidth * 9 / 16, alignment: .topLeading)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15), lineWidth: 1) }
                    }
                    .frame(width: panelWidth)
                }
            }
            .foregroundStyle(.white)
            .offset(x: 64, y: 56)
            Text("multiple color schemes selectable")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(secondary)
                .frame(width: comparisonWidth)
                .offset(y: comparisonHeight - 80)
        }
        .frame(width: comparisonWidth, height: comparisonHeight, alignment: .topLeading)
        .clipped()
        .environment(\.colorScheme, .dark)
    }
}

@MainActor func save<V: View>(_ view: V, filename: String, width: CGFloat = screenWidth, height: CGFloat = screenHeight) throws {
    let renderer = ImageRenderer(content: view)
    renderer.proposedSize = ProposedViewSize(width: width, height: height)
    renderer.scale = 1
    renderer.isOpaque = true
    guard let image = renderer.cgImage else { fatalError("Could not render \(filename)") }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode \(filename)") }
    try png.write(to: outputDirectory.appendingPathComponent(filename))
    print("Saved \(filename): \(image.width) × \(image.height)")
}

func assetMetadata(path: String, id: String, generator: String) throws -> [String: Any] {
    let data = try Data(contentsOf: directory.appendingPathComponent(path))
    guard let bitmap = NSBitmapImageRep(data: data) else { fatalError("Invalid image: \(path)") }
    return [
        "id": id, "path": path, "generator": generator,
        "width": bitmap.pixelsWide, "height": bitmap.pixelsHigh,
        "bytes": data.count,
        "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    ]
}

func writeAssetManifest() throws {
    let promptData = try Data(contentsOf: directory.appendingPathComponent("prompts.json"))
    let promptSet = try JSONSerialization.jsonObject(with: promptData) as! [String: Any]
    let prompts = promptSet["assets"] as! [[String: Any]]
    let generated = try prompts.map { spec in
        try assetMetadata(path: spec["destination"] as! String, id: spec["id"] as! String, generator: "built-in image_gen")
    }
    let previews = try ["home", "dynamic-sections", "video-finished", "video-ui", "color-schemes"].map { id in
        try assetMetadata(path: "../\(id).png", id: id, generator: "render_previews.swift / SwiftUI ImageRenderer")
    }
    let manifest: [String: Any] = [
        "pathsRelativeTo": "readme/preview_video_mocks",
        "promptSet": "prompts.json",
        "catalog": "catalog.json",
        "artworkGeneratedOn": "2026-10-12",
        "initialLayoutReferenceCommit": "197123acb757a6643b0bcb672fff1fd3916da847",
        "layoutReferenceCommit": "4998af095e2f1eadd47ad16eff9748f6630e85b9",
        "previewsUpdatedOn": "2026-10-18",
        "defaultColorTheme": PreviewColorTheme.noAccent.rawValue,
        "comparisonColorThemes": PreviewColorTheme.allCases.map(\.rawValue),
        "media": generated, "previews": previews
    ]
    var data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    data.append(0x0A)
    try data.write(to: directory.appendingPathComponent("assets.json"))
    print("Updated assets.json: \(generated.count) media assets and \(previews.count) previews")
}

try MainActor.assumeIsolated {
    // Fail before writing output if any of the approved media is missing.
    for item in catalog.items { _ = artwork("covers/\(item.id).png") }
    for item in catalog.items { if let backdrop = item.backdrop { _ = artwork(backdrop) } }
    for item in catalog.episodes { _ = artwork(item.artworkPath) }
    try save(HomePreview(), filename: "home.png")
    try save(DiscoveryPreview(), filename: "dynamic-sections.png")
    try save(FinishedPreview(), filename: "video-finished.png")
    try save(VideoPreview(), filename: "video-ui.png")
    try save(ColorSchemesPreview(), filename: "color-schemes.png", width: comparisonWidth, height: comparisonHeight)
    try writeAssetManifest()
}
