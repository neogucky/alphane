//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

struct ItemSubtitleSearchView: View {

    @Default(.accentColor)
    private var accentColor

    @ObservedObject
    var viewModel: ItemSubtitlesViewModel

    @Router
    private var router

    @State
    private var isPerfectMatch = false
    @State
    private var selectedSubtitles: Set<String> = []

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .initial, .content:
                contentView
            case .error:
                viewModel.error.map {
                    ErrorView(error: $0)
                }
            }
        }
        .navigationTitle(L10n.search)
        .toolbarTitleDisplayMode(.inline)
        .onReceive(viewModel.events) { event in
            switch event {
            case .deleted:
                break
            case .uploaded:
                router.dismiss()
            }
        }
        .errorMessage($viewModel.error)
        .navigationBarCloseButton {
            router.dismiss()
        }
        .topBarTrailing {}
        .onChange(of: isPerfectMatch) {
            viewModel.search(isPerfectMatch: isPerfectMatch)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        tvOSContent
    }

    #if os(tvOS)
    private var tvOSContent: some View {
        TVManagementPage(title: L10n.subtitles) {
            if viewModel.background.states.isNotEmpty {
                ProgressView().scaleEffect(0.65).frame(width: 28, height: 28)
            }
            Button(L10n.save, action: save)
                .disabled(selectedSubtitles.isEmpty || viewModel.background.is(.updating))
        } content: {
            HStack(spacing: 48) {
                CulturePicker(L10n.language, threeLetterISOLanguageName: $viewModel.language)
                Toggle(L10n.perfectMatch, isOn: $isPerfectMatch)
            }
            .padding(16)
            .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .disabled(viewModel.background.is(.updating))

            if viewModel.results.isEmpty {
                if viewModel.background.is(.searching) {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    TVManagementNote(text: L10n.none)
                }
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.results) { subtitle in
                        SearchResultRow(subtitle: subtitle) {
                            guard let id = subtitle.id else { return }

                            selectedSubtitles.toggle(value: id)
                        }
                        .isSelected(subtitle.id.map { selectedSubtitles.contains($0) } == true)
                        .disabled(subtitle.id == nil || viewModel.background.is(.updating))
                    }
                }
            }
        }
        .onExitCommand { router.dismiss() }
    }
    #endif

    private var legacyContent: some View {
        Form(systemImage: "textformat") {

            Section(L10n.options) {
                CulturePicker(L10n.language, threeLetterISOLanguageName: $viewModel.language)

                Toggle(L10n.perfectMatch, isOn: $isPerfectMatch)
            }

            Section(L10n.search) {

                if viewModel.results.isEmpty {
                    if viewModel.background.is(.searching) {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text(L10n.none)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    ForEach(viewModel.results) { subtitle in
                        SearchResultRow(subtitle: subtitle) {
                            guard let subtitleID = subtitle.id else { return }

                            selectedSubtitles.toggle(value: subtitleID)
                        }
                        .isSelected(subtitle.id.map { selectedSubtitles.contains($0) } == true)
                    }
                }
            }
        }
    }

    private func save() {
        guard selectedSubtitles.isNotEmpty else { return }

        viewModel.set(selectedSubtitles)
    }
}
