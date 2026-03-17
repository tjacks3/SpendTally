// ============================================================
// FILE:   EditExpenseView.swift
// ADD TO: SpendTally/Views/Expense/EditExpenseView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Expense" folder inside "Views" in
//      the Xcode Project Navigator
//   2. New File from Template → Swift File
//   3. Name it "EditExpenseView"
//   4. Paste this entire file, replacing the generated stub
//
// CONTAINS:
//   • EditExpenseView  — sheet-based editor for an existing Expense
//   • ReceiptFullScreenView — full-screen, pinch-zoomable receipt viewer
// ============================================================

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - EditExpenseView

/// Presents a Form that lets the user change an existing expense's
/// amount, note, date, and receipt photo.
///
/// Because Expense is a SwiftData @Model, we use @Bindable so that
/// changes to `expense.note` and `expense.date` write directly through
/// to the persistent store the moment the user edits them.
/// The amount needs a local String buffer (`amountText`) because
/// TextField only works with String — we flush it to `expense.amount`
/// when the user taps "Done".
struct EditExpenseView: View {

    // @Bindable lets us create two-way bindings to any @Model property.
    @Bindable var expense: Expense

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // ── Amount field buffer ──────────────────────────────────────────────────
    // We can't bind a TextField directly to a Double, so we keep a String
    // copy and sync it to expense.amount on save.
    @State private var amountText: String = ""

    // ── Photo picker ─────────────────────────────────────────────────────────
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingCamera      = false

    // ── Receipt full-screen viewer ────────────────────────────────────────────
    @State private var showingFullScreen  = false

    // ── OCR feedback ─────────────────────────────────────────────────────────
    @State private var isProcessingOCR   = false
    @State private var ocrMessage:  String?
    @State private var ocrColor:    Color  = .secondary
    @State private var ocrIcon:     String = "checkmark.circle"

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                noteSection
                dateSection
                receiptSection
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitAmount()
                        dismiss()
                    }
                    .disabled(!isAmountValid || isProcessingOCR)
                }
            }
            // Seed the amount text field from the stored Double when the view
            // first appears.
            .onAppear {
                amountText = String(format: "%.2f", expense.amount)
            }
            // Camera sheet — only used on real devices. On Simulator the
            // "Camera" button is greyed-out, so this sheet is never triggered.
            .sheet(isPresented: $showingCamera) {
                CameraPickerView { image in
                    handleReceipt(image)
                }
                .ignoresSafeArea()
            }
            // PhotosPicker image loader — fires when the user picks a photo
            // from the system library.
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data  = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        handleReceipt(image)
                    }
                }
            }
        }
    }

    // MARK: - Validation

    private var isAmountValid: Bool {
        guard let v = Double(amountText) else { return false }
        return v > 0
    }

    private func commitAmount() {
        if let v = Double(amountText), v > 0 {
            expense.amount = v
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        Section {
            HStack(spacing: 4) {
                Text("$")
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)

                if isProcessingOCR {
                    ProgressView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isProcessingOCR)

            // OCR result label — visible after a receipt scan
            if let message = ocrMessage {
                Label {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(ocrColor)
                } icon: {
                    Image(systemName: ocrIcon)
                        .font(.caption)
                        .foregroundStyle(ocrColor)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: ocrMessage)
            }

        } header: {
            Text("Amount")
        }
    }

    // MARK: - Note Section

    // $expense.note writes directly to SwiftData because of @Bindable.
    private var noteSection: some View {
        Section("Note") {
            TextField("What was this for?", text: $expense.note)
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        Section("Date") {
            DatePicker(
                "Date",
                selection: $expense.date,
                displayedComponents: .date
            )
            .labelsHidden()
        }
    }

    // MARK: - Receipt Section

    private var receiptSection: some View {
        Section {
            // Show the preview card if there's stored image data …
            if let data  = expense.receiptImageData,
               let image = UIImage(data: data) {
                receiptPreviewCard(image: image)
            } else {
                // … otherwise show the camera / library picker buttons.
                receiptPickerButtons
            }
        } header: {
            Text("Receipt")
        } footer: {
            if expense.receiptImageData == nil {
                Text("Attach a receipt to re-scan for the total.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Receipt Preview Card

    /// A full-width card showing the receipt thumbnail with:
    ///  • A "tap to view full screen" affordance (expand icon badge)
    ///  • An OCR loading overlay while re-scanning
    ///  • "Change Photo" and "Remove" buttons beneath
    @ViewBuilder
    private func receiptPreviewCard(image: UIImage) -> some View {

        // Tapping the image opens the full-screen viewer.
        Button {
            showingFullScreen = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Frosted scanning overlay
                if isProcessingOCR {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)

                    VStack(spacing: 10) {
                        ProgressView().tint(.primary)
                        Text("Reading receipt…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Expand badge (top-right corner of the image)
                if !isProcessingOCR {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2.bold())
                        .padding(6)
                        .background(.ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
        // The full-screen viewer is presented as a .fullScreenCover so the
        // receipt fills the entire screen — better for reading receipt details.
        .fullScreenCover(isPresented: $showingFullScreen) {
            ReceiptFullScreenView(image: image)
        }

        // ── Action buttons row ────────────────────────────────────────────────
        HStack {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Change Photo", systemImage: "photo.badge.arrow.down")
                    .font(.subheadline)
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation {
                    expense.receiptImageData = nil
                    selectedPhotoItem = nil
                    ocrMessage = nil
                }
            } label: {
                Label("Remove", systemImage: "trash")
                    .font(.subheadline)
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
    }

    // MARK: - Receipt Picker Buttons

    /// Shown when the expense has no receipt attached yet.
    private var receiptPickerButtons: some View {
        HStack(spacing: 12) {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showingCamera = true
                }
            } label: {
                pickerButtonLabel(
                    title: "Camera",
                    icon: "camera.fill",
                    available: UIImagePickerController.isSourceTypeAvailable(.camera)
                )
            }
            .buttonStyle(.plain)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                pickerButtonLabel(title: "Photo Library",
                                  icon: "photo.on.rectangle.angled")
            }
            .buttonStyle(.plain)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

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

    // MARK: - OCR Helper

    /// Persists the picked image, then kicks off an OCR scan in the background.
    private func handleReceipt(_ image: UIImage) {
        // Store compressed JPEG bytes on the expense immediately so the
        // thumbnail renders even before OCR finishes.
        expense.receiptImageData = image.jpegData(compressionQuality: 0.6)
        selectedPhotoItem = nil
        isProcessingOCR = true
        ocrMessage = nil

        Task {
            let result = await ReceiptOCRService.recognise(image: image)

            await MainActor.run {
                // Only overwrite the amount field if OCR found something.
                if let detected = result.amount {
                    amountText = String(format: "%.2f", detected)
                }

                // Update feedback badge
                switch result.strategy {
                case .totalKeyword(let kw):
                    ocrMessage = "Detected from \"\(kw)\" line"
                    ocrColor   = .green
                    ocrIcon    = "checkmark.circle"
                case .largestAmount:
                    ocrMessage = "No \"total\" label found — using largest amount"
                    ocrColor   = .orange
                    ocrIcon    = "wand.and.sparkles"
                case .notFound:
                    ocrMessage = "Couldn't detect a total — please enter manually"
                    ocrColor   = .secondary
                    ocrIcon    = "exclamationmark.triangle"
                }

                isProcessingOCR = false
            }
        }
    }
}

// MARK: - ReceiptFullScreenView

/// A full-screen, pinch-zoomable receipt viewer.
/// Presented via .fullScreenCover from EditExpenseView (and could be
/// reused anywhere else a receipt preview is needed).
struct ReceiptFullScreenView: View {

    let image: UIImage

    @Environment(\.dismiss) private var dismiss

    // Tracks the current magnification from the pinch gesture.
    @State private var scale:       CGFloat = 1.0
    // Stores the committed scale between gestures so they don't reset.
    @State private var baseScale:   CGFloat = 1.0

    // Tracks the current drag offset.
    @State private var offset:      CGSize = .zero
    @State private var baseOffset:  CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        ZStack {
            // Deep black background — provides maximum contrast for receipts.
            Color.black
                .ignoresSafeArea()

            // The receipt image, scalable and draggable.
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                // ── Pinch to zoom ──────────────────────────────────────────
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            // Clamp scale so it stays within [minScale, maxScale].
                            let candidate = baseScale * value
                            scale = min(max(candidate, minScale), maxScale)
                        }
                        .onEnded { _ in
                            baseScale = scale
                            // Snap back to 1× if the user pinched below minimum.
                            if scale <= minScale {
                                withAnimation(.spring(response: 0.35)) {
                                    scale      = 1.0
                                    baseScale  = 1.0
                                    offset     = .zero
                                    baseOffset = .zero
                                }
                            }
                        }
                )
                // ── Drag (only meaningful when zoomed in) ──────────────────
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1.0 else { return }
                            offset = CGSize(
                                width:  baseOffset.width  + value.translation.width,
                                height: baseOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            baseOffset = offset
                        }
                )
                // ── Double-tap to toggle zoom ──────────────────────────────
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.35)) {
                        if scale > 1.0 {
                            scale      = 1.0
                            baseScale  = 1.0
                            offset     = .zero
                            baseOffset = .zero
                        } else {
                            scale     = 2.5
                            baseScale = 2.5
                        }
                    }
                }

            // ── Close button ───────────────────────────────────────────────
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            // Rendering mode gives the symbol a white fill with
                            // a translucent dark ring — readable on any receipt.
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.4))
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                }
                Spacer()

                // Usage hint — fades after the user has had a moment to see it.
                Text("Pinch or double-tap to zoom")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 24)
            }
        }
        // Reset pan/zoom whenever this cover is re-presented.
        .onAppear {
            scale      = 1.0
            baseScale  = 1.0
            offset     = .zero
            baseOffset = .zero
        }
    }
}
