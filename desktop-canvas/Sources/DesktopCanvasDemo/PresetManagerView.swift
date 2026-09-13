import SwiftUI
import DesktopCanvas

struct PresetManagerView: View {
    @ObservedObject var state: EditorState
    @State private var selectedPreset: String?
    @State private var showSaveSheet = false
    @State private var showOverwriteAlert = false
    @State private var saveName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            presetList
            Divider()
            actionButtons
        }
        .frame(width: 360, height: 420)
        .sheet(isPresented: $showSaveSheet) {
            saveSheet
        }
    }

    private var header: some View {
        HStack {
            Text("Presets")
                .font(.headline)
            Spacer()
            Text("\(state.presetInfos.count) saved")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var presetList: some View {
        Group {
            if state.presetInfos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No saved presets")
                        .foregroundColor(.secondary)
                    Text("Create a layout, then click \"Save As…\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedPreset) {
                    ForEach(state.presetInfos) { info in
                        presetRow(info)
                            .tag(info.name as String?)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func presetRow(_ info: PresetInfo) -> some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(.system(size: 13, weight: .medium))
                Text("\(info.canvasCount) canvas\(info.canvasCount == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(relativeDate(info.modifiedAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Save As\u{2026}") {
                showSaveSheet = true
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Load") {
                guard let name = selectedPreset else { return }
                state.loadPreset(named: name)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPreset == nil)

            Button("Delete") {
                guard let name = selectedPreset else { return }
                state.deletePreset(named: name)
                selectedPreset = nil
            }
            .buttonStyle(.bordered)
            .disabled(selectedPreset == nil)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var saveSheet: some View {
        VStack(spacing: 16) {
            Text("Save Current Layout")
                .font(.headline)

            TextField("Preset name", text: $saveName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { performSave() }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showSaveSheet = false
                    saveName = ""
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    performSave()
                }
                .keyboardShortcut(.return)
                .disabled(saveName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
        .alert("Overwrite?", isPresented: $showOverwriteAlert) {
            Button("Overwrite") {
                state.saveCurrentPreset(named: saveName)
                selectedPreset = saveName
                saveName = ""
                showSaveSheet = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(saveName)\" already exists. Overwrite?")
        }
    }

    private func performSave() {
        let trimmed = saveName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if state.presetExists(named: trimmed) {
            showOverwriteAlert = true
        } else {
            state.saveCurrentPreset(named: trimmed)
            selectedPreset = trimmed
            saveName = ""
            showSaveSheet = false
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}