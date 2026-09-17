import FamilyControls
import SwiftUI

/// Wraps `FamilyActivityPicker` (spec §2.1) in a sheet with explicit
/// save / cancel so a half-finished selection never reaches the scheduler.
struct AppPickerView: View {

    @Environment(\.dismiss) private var dismiss

    let initialSelection: FamilyActivitySelection
    let onSave: (FamilyActivitySelection) -> Void

    @State private var draft: FamilyActivitySelection

    init(
        initialSelection: FamilyActivitySelection,
        onSave: @escaping (FamilyActivitySelection) -> Void
    ) {
        self.initialSelection = initialSelection
        self.onSave = onSave
        _draft = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $draft)
                .navigationTitle("Chọn ứng dụng")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Xong") {
                            onSave(draft)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Text(draft.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.bar)
                }
        }
    }
}
