import Foundation

// MARK: - Модель данных для акции
struct Stock: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    let name: String
    let currency: String
    var currentPrice: Double
    var change: Double
    var changePercent: Double
    var volume: Int
    var marketCap: Double?
}

// MARK: - Исторические данные для графика
struct StockHistory: Codable {
    let symbol: String
    let historical: [HistoricalData]
}

struct HistoricalData: Identifiable, Codable {
    let id = UUID()
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

// MARK: - Технические индикаторы
struct TechnicalIndicator {
    let name: String
    let value: Double
    let signal: SignalType
    
    enum SignalType: String {
        case buy = "Покупка"
        case sell = "Продажа"
        case neutral = "Нейтрально"
    }
}
