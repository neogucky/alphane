//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVOnboardingView: View {
    @ObservedObject
    var model: TVOnboardingModel
    @FocusState
    private var focus: String?
    @State
    private var previewTheme: AlphaneColorTheme?

    private var displayedTheme: AlphaneColorTheme {
        model.step == .style ? (previewTheme ?? model.theme) : model.theme
    }

    private var displayedColor: Color {
        displayedTheme.color(custom: model.customColor)
    }

    private let steps: [(TVOnboardingModel.Step, String)] = [
        (.style, String(localized: "Style")),
        (.server, String(localized: "Server")),
        (.profile, String(localized: "Profile"))
    ]

    private var title: String {
        switch model.step {
        case .style: String(localized: "Make it yours")
        case .server: String(localized: "Connect your Jellyfin server")
        case .profile: String(localized: "Who's watching?")
        case .complete: ""
        }
    }

    private var subtitle: String {
        switch model.step {
        case .style: String(localized: "Browse styles to preview. Select one to continue.")
        case .server: String(localized: "Enter an address or choose a server on your network.")
        case .profile: model.selectedServer?.name ?? ""
        case .complete: ""
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(.alphaneMark)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
            Text("ALPHANE")
                .font(.system(size: 18, weight: .semibold))
                .tracking(4)
            Spacer()
            HStack(spacing: 22) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    let active = item.0 == model.step
                    let completed = index < (steps.firstIndex { $0.0 == model.step } ?? steps.count)
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(.white.opacity(active ? 1 : 0.08))
                            if completed {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                            } else {
                                Text("\(index + 1)").font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundStyle(active ? AlphaneTheme.background : AlphaneTheme.secondaryText)
                        .frame(width: 28, height: 28)
                        Text(item.1).font(.system(size: 18, weight: active ? .semibold : .regular))
                    }
                    .foregroundStyle(.white.opacity(active ? 1 : 0.8))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(active ? .isSelected : [])
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 42, height: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .foregroundStyle(AlphaneTheme.secondaryText)
        .frame(height: 42)
    }

    private var styleStep: some View {
        HStack(spacing: 90) {
            TVThemeChoices(
                selection: Binding(get: { model.theme }, set: { model.choose($0) }),
                customColor: Binding(get: { model.customColor }, set: { model.chooseCustomColor($0) }),
                focus: $focus,
                onPreview: {
                    previewTheme = $0
                    model.preview($0)
                },
                onConfirm: model.continueFromStyle
            )
            .frame(width: 360)
            .onAppear {
                previewTheme = model.theme
                focus = model.theme == .custom ? "accent" : "theme-" + model.theme.rawValue
            }
            TVOnboardingPreview(theme: displayedTheme, color: displayedColor)
                .frame(maxWidth: 960)
                .accessibilityLabel(String(localized: "Preview of the selected style"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var serverStep: some View {
        VStack(spacing: 8) {
            if !model.servers.isEmpty {
                HStack(spacing: 24) {
                    ForEach(model.servers) { server in
                        Button { model.selectServer(server) } label: {
                            Label(server.name, systemImage: "server.rack")
                                .font(.system(size: 22))
                        }
                        .buttonStyle(.capsule)
                    }
                }
                .padding(.top, 24)
                .focusSection()
            }
            ConnectToServerView(isOnboarding: true, onConnected: { model.selectServer($0) })
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .style: styleStep
        case .server: serverStep
        case .profile: SelectUserView(isOnboarding: true)
        case .complete: ProgressView()
        }
    }

    private var footer: some View {
        HStack {
            if model.step != .style {
                Button(action: model.back) { Label(String(localized: "Back"), systemImage: "chevron.left") }
                    .accessibilityIdentifier("setup-back")
            }
            Spacer()
            if model.step == .profile {
                Label(String(localized: "Sign in to start watching"), systemImage: "lock")
                    .font(.system(size: 18))
                    .foregroundStyle(AlphaneTheme.secondaryText)
            }
        }
        .buttonStyle(.capsule)
        .frame(height: 56)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            header
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 20))
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .lineLimit(2)
            }
            .padding(.top, 24)
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(model.step)
            if model.step != .style {
                footer
            }
        }
        .padding(.horizontal, 72)
        .padding(.vertical, 40)
        .background(AlphaneTheme.background.ignoresSafeArea())
        .tint(displayedColor)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.applyPreview() }
        .if(model.step != .style) { view in
            view.onExitCommand(perform: model.back)
        }
    }
}

/// Fictional artwork and noninteractive controls: no library requests or watch
/// history changes are needed to preview a theme before choosing a server.
struct TVOnboardingPreview: View {
    let theme: AlphaneColorTheme
    let color: Color

    private var actions: some View {
        HStack(spacing: 18) {
            Text("Play")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AlphaneTheme.background)
                .padding(.horizontal, 32)
                .padding(.vertical, 8)
                .background(.white, in: Capsule())
            Image(systemName: "checkmark.circle.fill")
            Image(systemName: "heart.fill")
        }
        .font(.system(size: 23))
        .foregroundStyle(color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color(hex: "677378"), Color(hex: "253A3B"), Color(hex: "12292B")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color(hex: "D9D3B4").opacity(0.7))
                    .frame(width: 62, height: 62)
                    .offset(x: 555, y: -180)
                LandscapeRidge()
                    .fill(Color(hex: "253D3E"))
                    .padding(.top, 74)
                LandscapeRidge()
                    .fill(Color(hex: "162B30"))
                    .scaleEffect(x: -1, y: 0.8, anchor: .bottom)
                    .offset(x: 60, y: 34)
                LinearGradient(
                    colors: [.clear, AlphaneTheme.background.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        if theme != .noAccent {
                            Capsule().fill(color).frame(width: 3, height: 15)
                        }
                        Text("CONTINUE WATCHING").font(.system(size: 12, weight: .semibold)).tracking(2)
                    }
                    Text("The quiet coast").font(.system(size: 30, weight: .medium))
                    Text("A journey beyond the familiar.")
                        .font(.system(size: 17))
                        .foregroundStyle(AlphaneTheme.secondaryText)
                    actions.padding(.top, 8)
                }
                .padding(30)
                .foregroundStyle(.white)
            }
            .frame(height: 305)

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Now playing").font(.system(size: 14))
                    Spacer()
                    Image(systemName: "captions.bubble").font(.system(size: 18))
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.25))
                    Capsule().fill(color).frame(width: 240)
                    Circle().fill(.white).frame(width: 10, height: 10).offset(x: 235)
                }
                .frame(height: 4)
                HStack {
                    Text("24:16")
                    Spacer()
                    Text("−1:12:08")
                }
                .font(.system(size: 13))
                .monospacedDigit()
            }
            .padding(30)
            .foregroundStyle(AlphaneTheme.secondaryText)
            .background(Color.black.opacity(0.18))
        }
        .background(AlphaneTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.1), lineWidth: 1) }
        .allowsHitTesting(false)
    }

    private struct LandscapeRidge: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 0, y: rect.height))
                path.addLines([
                    CGPoint(x: 0, y: rect.height * 0.55),
                    CGPoint(x: rect.width * 0.2, y: rect.height * 0.15),
                    CGPoint(x: rect.width * 0.38, y: rect.height * 0.52),
                    CGPoint(x: rect.width * 0.58, y: rect.height * 0.3),
                    CGPoint(x: rect.width * 0.82, y: 0),
                    CGPoint(x: rect.width, y: rect.height * 0.45),
                    CGPoint(x: rect.width, y: rect.height)
                ])
                path.closeSubpath()
            }
        }
    }
}
