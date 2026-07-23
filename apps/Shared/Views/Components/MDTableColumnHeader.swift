#if os(macOS)
import Foundation
import SwiftUI

struct MDTableFilterOption: Identifiable, Equatable {
    let id: String
    let label: String
    let count: Int
}

enum MDTableFilterCodec {
    static func selection(in storage: String, for key: String) -> Set<String> {
        Set(decoded(storage)[key] ?? [])
    }

    static func updating(
        _ values: Set<String>,
        in storage: String,
        for key: String
    ) -> String {
        var value = decoded(storage)
        if values.isEmpty {
            value.removeValue(forKey: key)
        } else {
            value[key] = values.sorted()
        }
        return encoded(value)
    }

    static func clearing(_ key: String, in storage: String) -> String {
        updating([], in: storage, for: key)
    }

    static func removeAll(from storage: String) -> String {
        ""
    }

    private static func decoded(_ storage: String) -> [String: [String]] {
        guard let data = storage.data(using: .utf8), !data.isEmpty else { return [:] }
        return (try? JSONDecoder().decode([String: [String]].self, from: data)) ?? [:]
    }

    private static func encoded(_ value: [String: [String]]) -> String {
        guard !value.isEmpty,
              let data = try? JSONEncoder().encode(value),
              let result = String(data: data, encoding: .utf8) else {
            return ""
        }
        return result
    }
}

@MainActor
func mdTableFilterSelection(
    storage: Binding<String>,
    key: String
) -> Binding<Set<String>> {
    Binding(
        get: { MDTableFilterCodec.selection(in: storage.wrappedValue, for: key) },
        set: { values in
            storage.wrappedValue = MDTableFilterCodec.updating(
                values,
                in: storage.wrappedValue,
                for: key
            )
        }
    )
}

func mdTableFilterOptions<Row>(
    _ rows: [Row],
    key: (Row) -> String,
    label: (Row) -> String
) -> [MDTableFilterOption] {
    var grouped: [String: MDTableFilterOption] = [:]
    for row in rows {
        let optionKey = key(row)
        let optionLabel = label(row)
        if let existing = grouped[optionKey] {
            grouped[optionKey] = MDTableFilterOption(
                id: optionKey,
                label: existing.label,
                count: existing.count + 1
            )
        } else {
            grouped[optionKey] = MDTableFilterOption(id: optionKey, label: optionLabel, count: 1)
        }
    }
    return grouped.values.sorted {
        $0.label.localizedStandardCompare($1.label) == .orderedAscending
    }
}

@MainActor
struct MDTableColumnHeader: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .leading
    let isSorted: Bool
    let ascending: Bool
    let options: [MDTableFilterOption]
    @Binding var selectedValues: Set<String>
    var textFilter: Binding<String>?
    let onSort: () -> Void

    @State private var showingFilter = false
    @Environment(\.colorScheme) private var colorScheme

    private var trimmedTextFilter: String {
        textFilter?.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isFiltered: Bool {
        !selectedValues.isEmpty || !trimmedTextFilter.isEmpty
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 3) {
            Button(action: onSort) {
                HStack(spacing: 4) {
                    Text(title)
                        .mdFont(.compactStrong)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Image(systemName: sortSymbol)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(isSorted ? theme.accent : theme.secondaryText.opacity(0.55))
                        .frame(width: 9)
                }
                .frame(maxWidth: .infinity, alignment: alignment)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(sortHelp)

            Button {
                showingFilter.toggle()
            } label: {
                Image(systemName: isFiltered
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isFiltered ? theme.accent : theme.secondaryText)
                    .frame(width: 16, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("筛选\(title)")
            .popover(isPresented: $showingFilter, arrowEdge: .bottom) {
                filterPopover(theme: theme)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: width)
    }

    private var sortSymbol: String {
        guard isSorted else { return "arrow.up.arrow.down" }
        return ascending ? "chevron.up" : "chevron.down"
    }

    private var sortHelp: String {
        guard isSorted else { return "按\(title)升序排列" }
        return ascending ? "按\(title)降序排列" : "按\(title)升序排列"
    }

    private func filterPopover(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("筛选 · \(title)")
                    .mdFont(.bodyStrong)
                Spacer()
                if isFiltered {
                    Button {
                        selectedValues.removeAll()
                        textFilter?.wrappedValue = ""
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(MDIconButtonStyle())
                    .help("清除此列筛选")
                }
            }

            Rectangle().fill(theme.separator).frame(height: 1)

            if let textFilter {
                TextField("输入关键字", text: textFilter)
                    .textFieldStyle(.roundedBorder)
                    .mdFont(.compact)
            }

            if options.isEmpty {
                if textFilter == nil {
                    Text("暂无可选项")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(options) { option in
                            optionRow(option, theme: theme)
                        }
                    }
                }
                .frame(maxHeight: 270)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(theme.raisedSurface)
    }

    private func optionRow(_ option: MDTableFilterOption, theme: MDTheme) -> some View {
        let selected = selectedValues.contains(option.id)
        return Button {
            if selected {
                selectedValues.remove(option.id)
            } else {
                selectedValues.insert(option.id)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                    .frame(width: 16)
                Text(option.label)
                    .mdFont(.compact)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(option.count)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 29, alignment: .leading)
            .background(
                selected ? theme.accent.opacity(colorScheme == .dark ? 0.15 : 0.09) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
