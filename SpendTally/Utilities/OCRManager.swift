import Vision
import UIKit

/// A utility that extracts a dollar total from a receipt image using on-device OCR.
/// It's a struct with static methods — no need to instantiate it.
struct OCRManager {
    
    /// Analyzes a receipt image and returns the detected total amount, or nil.
    /// This function is `async` so it can be awaited without blocking the UI.
    static func extractTotal(from image: UIImage) async -> Double? {
        guard let cgImage = image.cgImage else { return nil }
        
        // withCheckedContinuation bridges Vision's callback-based API into async/await.
        return await withCheckedContinuation { continuation in
            
            // VNRecognizeTextRequest is the Vision "job" that reads text.
            let request = VNRecognizeTextRequest { request, error in
                
                if let error = error {
                    print("OCR error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Cast results to the expected type.
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Extract the top text candidate from each observation.
                // topCandidates(1) gives us the single best guess for each text block.
                let lines: [String] = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }
                
                let total = findBestTotal(in: lines)
                continuation.resume(returning: total)
            }
            
            // .accurate is slower but better for receipts with small print.
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false  // disable for numbers/symbols
            
            // VNImageRequestHandler performs the request on the image.
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Private Parsing Logic
    
    /// Searches OCR text lines for the most likely receipt total.
    private static func findBestTotal(in lines: [String]) -> Double? {
        // Regex that matches amounts like: $24.99, 24.99, $1,024.50
        let amountPattern = /\$?(\d{1,3}(?:,\d{3})*|\d+)\.(\d{2})/
        
        // Keywords that usually appear near the total line on a receipt.
        let totalKeywords = ["total", "amount due", "balance due", "grand total", "subtotal"]
        
        var allAmounts: [Double] = []
        var totalLineAmount: Double? = nil
        
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            
            // Check if this line contains a "total" keyword.
            let isTotalLine = totalKeywords.contains { lower.contains($0) }
            
            // Check this line AND the next line for a dollar amount.
            // Receipts sometimes put the amount on the line after "Total".
            let linesToCheck = isTotalLine
                ? [line] + (i + 1 < lines.count ? [lines[i + 1]] : [])
                : [line]
            
            for checkLine in linesToCheck {
                if let match = checkLine.firstMatch(of: amountPattern) {
                    // Remove commas and $ to get a clean number string.
                    let raw = String(match.output.0)
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    
                    if let amount = Double(raw) {
                        if isTotalLine && totalLineAmount == nil {
                            // Prioritize amounts found on "total" lines.
                            totalLineAmount = amount
                        }
                        allAmounts.append(amount)
                    }
                }
            }
        }
        
        // Strategy: prefer a "total" keyword match; otherwise use the largest amount.
        // The largest amount on a receipt is usually the grand total.
        return totalLineAmount ?? allAmounts.max()
    }
}
