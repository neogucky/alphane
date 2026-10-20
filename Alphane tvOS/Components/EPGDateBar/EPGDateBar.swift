//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct EPGDateBar: View {
    @FocusState
    private var focusedDate: Date?
    @ObservedObject
    var viewModel: EPGViewModel

    private var selectedDate: Date {
        max(viewModel.startDate, Calendar.current.startOfDay(for: .now))
    }

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.availableDates, id: \.self) { date in
                DatePill(date: date) { viewModel.setDate(date: date) }
                    .isSelected(isSelected(date))
                    .focused($focusedDate, equals: date)
            }
        }
        .activeSelectionFocus(
            $focusedDate,
            selection: viewModel.availableDates.first { isSelected($0) }
        )
    }
}
