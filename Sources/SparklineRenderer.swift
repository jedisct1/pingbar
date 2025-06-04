import Foundation

struct SparklineRenderer {
    
    static func renderSparkline(pings: [Int]) -> String {
        // Enhanced block characters for better visual distinction
        let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        
        guard !pings.isEmpty else { return "" }
        guard let min = pings.min(), let max = pings.max(), max > min else {
            return String(repeating: blocks[0], count: Swift.min(pings.count, 20))
        }
        
        let range = max - min
        let limitedPings = Array(pings.suffix(20)) // Show last 20 pings for better readability
        
        return limitedPings.map { ping in
            let normalized = Double(ping - min) / Double(range)
            let idx = Int(normalized * Double(blocks.count - 1))
            return blocks[Swift.max(0, Swift.min(idx, blocks.count - 1))]
        }.joined()
    }
    
    // Add color-coded sparkline for different ping ranges
    static func renderColorCodedSparkline(pings: [Int], threshold: Int = 200) -> String {
        guard !pings.isEmpty else { return "" }
        
        let limitedPings = Array(pings.suffix(20))
        
        return limitedPings.map { ping in
            switch ping {
            case 0..<50:
                return "🟢" // Excellent
            case 50..<100:
                return "🟡" // Good  
            case 100..<threshold:
                return "🟠" // Warning
            default:
                return "🔴" // Poor
            }
        }.joined()
    }
}