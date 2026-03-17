// ============================================================
// FILE:   ReceiptOCRService.swift
// ADD TO: SpendTally/Utilities/ReceiptOCRService.swift
//
// ACTION: NEW FILE — create this file in Xcode:
//   1. Right-click the "Utilities" folder in the Xcode
//      Project Navigator (left sidebar)
//   2. Choose "New File from Template..."
//   3. Pick "Swift File", name it "ReceiptOCRService"
//   4. Replace all generated content with this file
//
// NOTE:   You can also DELETE OCRManager.swift once this
//         file is in place — ReceiptOCRService fully
//         replaces it. Right-click OCRManager.swift →
//         "Delete" → "Move to Trash".
// ============================================================

import Vision
import UIKit

// MARK: - Result type

/// Carries back everything the OCR engine found so the UI can show confidence.
struct OCRResult {
    
    /// The best dollar amount we detected (nil if nothing was found).
    let amount: Double?
    
    /// How we arrived at the amount — useful for debugging and UI messaging.
    let strategy: DetectionStrategy
    
    /// Every dollar amount found anywhere on the receipt, largest first.
    let allAmounts: [Double]
    
    /// Raw text lines Vision extracted (useful for debugging / future features).
    let rawLines: [String]
    
    enum DetectionStrategy {
        /// Found an amount on a line that contained a "total" keyword.
        case totalKeyword(keyword: String)
        
        /// No keyword match — used the largest currency value on the receipt.
        case largestAmount
        
        /// No currency values were found at all.
        case notFound
    }
    
    /// A human-readable summary of how the amount was found.
    var strategyDescription: String {
        switch strategy {
        case .totalKeyword(let kw):
            return "Detected from \"\(kw)\" line"
        case .largestAmount:
            return "Detected as largest amount on receipt"
        case .notFound:
            return "No total detected"
        }
    }
}

// MARK: - Service

/// Extracts a dollar total from a receipt photo using on-device Vision OCR.
///
/// All work happens off the main thread; call sites should `await` on a
/// background task and deliver results back to `@MainActor` themselves.
struct ReceiptOCRService {
    
    // MARK: - Public API
    
    /// Analyse `image` and return a full `OCRResult`.
    /// Never throws — failures are represented as `OCRResult` with `amount == nil`.
    static func recognise(image: UIImage) async -> OCRResult {
        guard let cgImage = image.cgImage else {
            return OCRResult(amount: nil, strategy: .notFound, allAmounts: [], rawLines: [])
        }
        
        let lines = await extractTextLines(from: cgImage)
        return parse(lines: lines)
    }
    
    // MARK: - Step 1 – Vision text extraction
    
    /// Runs `VNRecognizeTextRequest` and returns the top candidate for every
    /// text block, in document order (top-to-bottom, left-to-right).
    private static func extractTextLines(from cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    print("[ReceiptOCRService] Vision error: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // topCandidates(1) → the single highest-confidence hypothesis per block.
                let lines = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines)
            }
            
            // .accurate uses a neural-network model; slower but far better on
            // small receipt fonts than the fast (.fast) rule-based model.
            request.recognitionLevel = .accurate
            
            // Disable language correction — it garbles currency symbols & numbers.
            request.usesLanguageCorrection = false
            
            // Hints help the engine skip unlikely character classes.
            // We're not setting customWords here because Vision handles digits well.
            
            let handler = VNImageRequestHandler(cgImage: cgImage,
                                                options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[ReceiptOCRService] Handler error: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Step 2 – Parsing
    
    /// Searches the raw OCR lines for a dollar total using a tiered strategy.
    static func parse(lines: [String]) -> OCRResult {
        
        // ── Currency regex ──────────────────────────────────────────────────
        // Matches: $24.99  24.99  $1,024.50  1024.50
        // Group 1 = integer part (with optional commas)
        // Group 2 = two-digit decimal
        let currencyPattern = /\$?\s*(\d{1,3}(?:,\d{3})*|\d+)\.(\d{2})\b/
        
        // ── Total keyword tiers ─────────────────────────────────────────────
        // Higher tiers = stronger signal → we prefer them over lower tiers.
        let keywordTiers: [[String]] = [
            // Tier 1 – almost certainly the grand total
            ["grand total", "total due", "amount due", "balance due",
             "total amount due", "please pay", "pay this amount"],
            
            // Tier 2 – very likely the total
            ["total", "net total", "order total", "sale total",
             "transaction total", "charge total"],
            
            // Tier 3 – sometimes the total, sometimes not (subtotal, tax, etc.)
            ["subtotal", "sub-total", "sub total", "amount"],
        ]
        
        var allAmounts: [Double] = []       // every amount found on the receipt
        var keywordMatches: [(amount: Double, keyword: String, tier: Int)] = []
        
        for (lineIndex, line) in lines.enumerated() {
            let lower = line.lowercased()
            
            // Pull every currency amount from this line.
            let lineAmounts = extractAmounts(from: line, using: currencyPattern)
            allAmounts.append(contentsOf: lineAmounts)
            
            // Check if this line contains a keyword from any tier.
            for (tierIndex, tier) in keywordTiers.enumerated() {
                guard let matchedKeyword = tier.first(where: { lower.contains($0) }) else {
                    continue
                }
                
                // Amounts can appear on the same line OR on the very next line
                // (some receipt printers put the value below the label).
                var candidates: [Double] = lineAmounts
                
                if lineAmounts.isEmpty, lineIndex + 1 < lines.count {
                    let nextLine = lines[lineIndex + 1]
                    let nextAmounts = extractAmounts(from: nextLine, using: currencyPattern)
                    candidates.append(contentsOf: nextAmounts)
                    allAmounts.append(contentsOf: nextAmounts)
                }
                
                for amount in candidates {
                    keywordMatches.append((amount, matchedKeyword, tierIndex))
                }
            }
        }
        
        // ── Selection strategy ───────────────────────────────────────────────
        
        // Sort keyword matches: lowest tier index first (strongest signal), then
        // highest amount (prefer grand total over line-item subtotals).
        let sortedMatches = keywordMatches.sorted {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            return $0.amount > $1.amount
        }
        
        // De-duplicate allAmounts, sort descending.
        let uniqueAmounts = Array(Set(allAmounts)).sorted(by: >)
        
        if let best = sortedMatches.first {
            return OCRResult(
                amount: best.amount,
                strategy: .totalKeyword(keyword: best.keyword),
                allAmounts: uniqueAmounts,
                rawLines: lines
            )
        }
        
        if let largest = uniqueAmounts.first {
            return OCRResult(
                amount: largest,
                strategy: .largestAmount,
                allAmounts: uniqueAmounts,
                rawLines: lines
            )
        }
        
        return OCRResult(amount: nil, strategy: .notFound, allAmounts: [], rawLines: lines)
    }
    
    // MARK: - Helpers
    
    /// Extracts all dollar amounts from a single text line.
    private static func extractAmounts(
        from line: String,
        using pattern: Regex<(Substring, Substring, Substring)>
    ) -> [Double] {
        line.matches(of: pattern).compactMap { match in
            let raw = match.output.0
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: "")
            return Double(raw)
        }
    }
}
