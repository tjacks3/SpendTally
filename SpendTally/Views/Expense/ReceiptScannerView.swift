import SwiftUI
import UIKit

/// Lets the user take a photo or pick from the photo library.
/// After selecting an image, it calls onImageSelected with the UIImage.
struct ReceiptScannerView: UIViewControllerRepresentable {
    
    let sourceType: UIImagePickerController.SourceType  // .camera or .photoLibrary
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - UIViewControllerRepresentable
    
    // Creates the UIKit view controller we're wrapping.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator   // wire up delegate callbacks
        return picker
    }
    
    // Called when the wrapped view needs to update — not needed here.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    // Creates the Coordinator that handles delegate callbacks.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    /// The Coordinator bridges UIKit delegate methods into our Swift closure.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        
        let parent: ReceiptScannerView
        
        init(_ parent: ReceiptScannerView) {
            self.parent = parent
        }
        
        // Called when the user picks or takes a photo.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        // Called when the user cancels.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
