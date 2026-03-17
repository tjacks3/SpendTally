// ============================================================
// FILE:   CameraPickerView.swift
// ADD TO: SpendTally/Views/Expense/CameraPickerView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Expense" folder inside "Views" in
//      the Xcode Project Navigator
//   2. New File from Template → Swift File
//   3. Name it "CameraPickerView"
//   4. Paste this entire file, replacing the generated stub
//
// ALSO: You can now DELETE ReceiptScannerView.swift.
//   • CameraPickerView handles camera only
//   • PhotosPicker (built into SwiftUI) handles the library
//   Right-click ReceiptScannerView.swift → Delete → Move to Trash
//
// PERMISSION REQUIRED:
//   The camera needs an entry in Info.plist or Xcode will
//   crash at runtime with a purple "missing usage description"
//   error. Add it like this:
//
//   In Xcode: select the SpendTally project in the navigator
//   → SpendTally target → Info tab → click the + on any row
//   → type "Privacy - Camera Usage Description"
//   → set value to: "SpendTally uses the camera to scan receipts."
//
//   That string is shown to the user in the iOS permission
//   alert — make it friendly and specific.
//
// WHY THIS FILE EXISTS:
//   SwiftUI's PhotosPicker (iOS 16+) handles photo library
//   access without any permission prompt. But there is no
//   SwiftUI-native camera picker yet, so we still need to
//   wrap UIImagePickerController for camera use. This file
//   does that wrapping in the simplest possible way.
// ============================================================

import SwiftUI
import UIKit

// UIViewControllerRepresentable is the bridge that lets you
// use any UIKit view controller inside a SwiftUI view.
// Here we're wrapping UIImagePickerController (the system
// camera UI) so we can present it as a SwiftUI .sheet.
struct CameraPickerView: UIViewControllerRepresentable {

    // When the user takes a photo this closure is called with
    // the resulting UIImage. The caller decides what to do
    // with it (in our case, run OCR and store it).
    let onImageCaptured: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    // Step 1: SwiftUI calls this once to create the UIKit controller.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera          // camera, not library
        picker.allowsEditing = false         // raw photo, no crop UI
        picker.delegate = context.coordinator
        return picker
    }

    // Step 2: SwiftUI calls this when state changes and the
    // controller might need updating. We don't need to do
    // anything here because the camera UI manages itself.
    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    // Step 3: SwiftUI asks for a Coordinator — an object that
    // can act as the UIKit delegate and call back into SwiftUI.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    // The Coordinator is a plain class that adopts the UIKit
    // delegate protocols. It holds a reference to the parent
    // CameraPickerView so it can call our closure.
    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {

        private let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        // Called when the user taps "Use Photo" after taking a shot.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // .originalImage is the full-resolution photo.
            // .editedImage would be the cropped version if allowsEditing were true.
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        // Called when the user taps "Cancel".
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
