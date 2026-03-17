// ============================================================
// FILE:   AddExpenseView.swift
// ADD TO: SpendTally/Views/Expense/AddExpenseView.swift
//
// ACTION: REPLACE EXISTING FILE
//   1. Open SpendTally/Views/Expense/AddExpenseView.swift
//   2. Select all (Cmd+A) and delete
//   3. Paste this entire file in
//
// WHAT CHANGED vs. the previous version:
//   • Photo library now uses SwiftUI's PhotosPicker (iOS 16+)
//     instead of UIImagePickerController. No permission prompt,
//     no extra boilerplate, no separate sheet needed.
//   • Camera still uses CameraPickerView (a UIKit wrapper) —
//     SwiftUI doesn't have a native camera picker yet.
//   • selectedPhotoItem drives the PhotosPicker. When it
//     changes, .onChange loads the image bytes and hands
//     the UIImage to the ViewModel.
//   • Receipt preview is cleaner: full-width card with an
//     OCR loading overlay and a "Change" shortcut button.
//   • All beginner notes are inline as comments.
// ============================================================

import SwiftUI
import SwiftData
import PhotosUI     // required for PhotosPicker and PhotosPickerItem

struct AddExpenseView: View {

    let budget: Budget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var vm = ExpenseViewModel()

    // ── PhotosPicker state ───────────────────────────────────────────────────
    // PhotosPickerItem is a lightweight token — it doesn't hold image data
    // yet. The actual bytes are loaded asynchronously in the .onChange below.
    // Keeping it as @State here (not in the ViewModel) is intentional: it's
    // a UI concern, not a business-logic concern.
    @State private var selectedPhotoItem: PhotosPickerItem?

    // ── Camera sheet state ───────────────────────────────────────────────────
    @State private var showingCamera = false

    // ── Keyboard focus ───────────────────────────────────────────────────────
    @FocusState private var amountFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                noteSection
                dateSection
                receiptSection
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.addExpense(to: budget, context: modelContext)
                        dismiss()
                    }
                    .disabled(!vm.isFormValid || vm.isProcessingOCR)
                }
            }

            // ── Camera sheet ─────────────────────────────────────────────────
            // Only presented when the user taps "Camera". CameraPickerView
            // wraps UIImagePickerController so we get the system camera UI.
            .sheet(isPresented: $showingCamera) {
                CameraPickerView { image in
                    vm.handleReceiptImage(image)
                    amountFocused = false
                }
                .ignoresSafeArea()
            }

            // ── PhotosPicker image loader ────────────────────────────────────
            // When the user picks a photo, selectedPhotoItem changes.
            // We load its raw Data, convert to UIImage, and hand it to the
            // ViewModel. loadTransferable is async so it runs in a Task
            // without blocking the UI.
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        vm.handleReceiptImage(image)
                        amountFocused = false
                    }
                }
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        Section {

            // Main amount row
            HStack(spacing: 4) {
                Text("$")
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $vm.amount)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)

                if vm.isProcessingOCR {
                    ProgressView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.isProcessingOCR)

            // OCR result badge — only shown after a scan has run
            if let message = vm.ocrStatusMessage {
                Label {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(vm.ocrStatusColor)
                } icon: {
                    Image(systemName: ocrStatusIcon)
                        .font(.caption)
                        .foregroundStyle(vm.ocrStatusColor)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Alternative amounts row — shown when Vision found several numbers
            if vm.ocrDidRun && !vm.alternativeAmounts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Other amounts found on receipt:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    // Horizontal chip row — tap any chip to use that amount
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.alternativeAmounts.prefix(6), id: \.self) { alt in
                                Button {
                                    vm.selectAlternativeAmount(alt)
                                } label: {
                                    Text(alt, format: .currency(code: "USD"))
                                        .font(.caption.monospacedDigit())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

        } header: {
            Text("Amount")
        } footer: {
            if !vm.ocrDidRun && vm.receiptImage == nil {
                Text("Attach a receipt photo below to auto-detect the total.")
                    .font(.caption)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.ocrStatusMessage)
        .animation(.easeInOut(duration: 0.25), value: vm.alternativeAmounts.count)
    }

    private var ocrStatusIcon: String {
        switch vm.ocrResult?.strategy {
        case .totalKeyword:  return "checkmark.circle"
        case .largestAmount: return "wand.and.sparkles"
        case .notFound:      return "exclamationmark.triangle"
        case nil:            return "questionmark.circle"
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        Section("Note (optional)") {
            TextField("What was this for?", text: $vm.note)
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        Section("Date") {
            DatePicker("Date", selection: $vm.date, displayedComponents: .date)
                .labelsHidden()
        }
    }

    // MARK: - Receipt Section

    private var receiptSection: some View {
        Section {
            if let image = vm.receiptImage {
                receiptPreview(image: image)
            } else {
                receiptPickerButtons
            }
        } header: {
            Text("Receipt")
        } footer: {
            Text("We'll scan the receipt and fill in the total automatically. You can edit the amount before saving.")
        }
    }

    // MARK: - Receipt Preview

    // Shown after the user picks or takes a photo.
    @ViewBuilder
    private func receiptPreview(image: UIImage) -> some View {

        // The image card — full section width, rounded corners
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Frosted overlay + spinner while OCR is running
            if vm.isProcessingOCR {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)

                VStack(spacing: 10) {
                    ProgressView()
                        .tint(.primary)
                    Text("Reading receipt…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Remove default Form row insets so the image card is edge-to-edge
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

        // Action buttons below the image preview
        HStack {

            // PhotosPicker on the "Change" button — tapping opens the system
            // photo library so the user can swap the receipt photo inline,
            // without dismissing and reopening the form.
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Change Photo", systemImage: "photo.badge.arrow.down")
                    .font(.subheadline)
            }

            Spacer()

            // Clear the receipt — note we also nil out selectedPhotoItem so
            // picking the same photo again will still trigger .onChange.
            Button(role: .destructive) {
                withAnimation {
                    vm.receiptImage = nil
                    selectedPhotoItem = nil
                }
            } label: {
                Label("Remove", systemImage: "trash")
                    .font(.subheadline)
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
    }

    // MARK: - Receipt Picker Buttons

    // Shown when no photo has been selected yet.
    private var receiptPickerButtons: some View {
        HStack(spacing: 12) {

            // ── Camera button ────────────────────────────────────────────────
            // Tapping this sets showingCamera = true, which presents the
            // CameraPickerView sheet. On Simulator, camera is unavailable so
            // the button is shown but won't do anything useful — test on a
            // real device for camera functionality.
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showingCamera = true
                }
                // On Simulator: no-op. Encourage user to use "Photo Library".
            } label: {
                pickerButtonLabel(
                    title: "Camera",
                    icon: "camera.fill",
                    // Grey out the button on Simulator to signal it's unavailable
                    available: UIImagePickerController.isSourceTypeAvailable(.camera)
                )
            }
            .buttonStyle(.plain)

            // ── Library button ───────────────────────────────────────────────
            // PhotosPicker is the modern replacement for UIImagePickerController
            // photo library access. Key advantages:
            //   • NO permission prompt — the system picker is sandboxed, so iOS
            //     only grants access to the specific photos the user selects.
            //   • No extra Info.plist keys needed for library-only access.
            //   • Fully SwiftUI — no UIViewControllerRepresentable wrapper.
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,          // photos only, not videos
                photoLibrary: .shared()
            ) {
                pickerButtonLabel(title: "Photo Library", icon: "photo.on.rectangle.angled")
            }
            .buttonStyle(.plain)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    // Shared label used by both picker buttons
    private func pickerButtonLabel(
        title: String,
        icon: String,
        available: Bool = true
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(available ? Color.accentColor : Color.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(available ? Color.primary : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(available ? 0.08 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
