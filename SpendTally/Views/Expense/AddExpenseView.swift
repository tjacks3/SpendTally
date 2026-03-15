import SwiftUI
import SwiftData

struct AddExpenseView: View {
    
    let budget: Budget
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var vm = ExpenseViewModel()
    
    // Controls which image source to show (camera vs. library)
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: Amount Section
                Section("Amount") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $vm.amount)
                            .keyboardType(.decimalPad)
                        
                        // Show spinner while OCR runs
                        if vm.isProcessingOCR {
                            ProgressView()
                        }
                    }
                    
                    // Error message if OCR couldn't find a total
                    if let error = vm.ocrErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                // MARK: Note Section
                Section("Note (optional)") {
                    TextField("What was this for?", text: $vm.note)
                }
                
                // MARK: Date Section
                Section("Date") {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)
                        .labelsHidden()
                }
                
                // MARK: Receipt Section
                Section("Receipt") {
                    // If a receipt image is already selected, show it
                    if let image = vm.receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Button(role: .destructive) {
                            vm.receiptImage = nil
                        } label: {
                            Label("Remove Receipt", systemImage: "trash")
                        }
                    } else {
                        // Show buttons to take a photo or pick from library
                        HStack(spacing: 16) {
                            receiptButton(
                                title: "Camera",
                                icon: "camera",
                                action: {
                                    // Only available on real device, not simulator
                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        showingCamera = true
                                    } else {
                                        showingPhotoLibrary = true
                                    }
                                }
                            )
                            receiptButton(
                                title: "Library",
                                icon: "photo.on.rectangle",
                                action: { showingPhotoLibrary = true }
                            )
                        }
                    }
                }
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
            // Camera sheet
            .sheet(isPresented: $showingCamera) {
                ReceiptScannerView(sourceType: .camera) { image in
                    vm.handleReceiptImage(image)
                }
                .ignoresSafeArea()
            }
            // Photo library sheet
            .sheet(isPresented: $showingPhotoLibrary) {
                ReceiptScannerView(sourceType: .photoLibrary) { image in
                    vm.handleReceiptImage(image)
                }
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func receiptButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
