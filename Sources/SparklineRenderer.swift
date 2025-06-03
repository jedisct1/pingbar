import Foundation

struct SparklineRenderer {
    
    static func renderSparkline(pings: [Int]) -> String {
        let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        guard let min = pings.min(), let max = pings.max(), max > min else {
            return String(repeating: blocks[0], count: pings.count)
        }
        let range = max - min
        return pings.map { ping in
            let idx = Int(Double(ping - min) / Double(range) * Double(blocks.count - 1))
            return blocks[idx]
        }.joined()
    }
}