import Foundation
import Combine

// MARK: - Протокол для API сервиса
protocol APIServiceProtocol {
    func fetchStocks() -> AnyPublisher<[Stock], Error>
    func fetchStockHistory(symbol: String) -> AnyPublisher<StockHistory, Error>
    func searchStocks(query: String) -> AnyPublisher<[Stock], Error>
}

// MARK: - Реализация API сервиса с FCS API
class APIService: APIServiceProtocol {
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let apiKey = "xBuMQaGoFcZvchwqymIDMilj2cWXSo7" // Вставь сюда свой ключ
    
    // Основные символы для загрузки
    private let defaultSymbols = ["AAPL", "GOOGL", "MSFT", "AMZN", "TSLA", "META", "NFLX", "NVDA"]
    
    // MARK: - Модели FCS API (исправленные под реальный формат)
    struct FCSQuoteResponse: Codable {
        let status: Bool
        let code: Int
        let msg: String
        let response: [FCSQuote]?  // Изменено с data на response
    }
    
    struct FCSQuote: Codable {
        let s: String        // symbol
        let c: String        // current price (как строка!)
        let ch: String?      // change (как строка)
        let cp: String?      // change percent (как строка с %)
        let name: String?    // company name
        let ccy: String?     // currency
        let vo: String?      // volume (как строка)
        
        enum CodingKeys: String, CodingKey {
            case s, c, ch, cp, name, ccy, vo
        }
    }
    
    // MARK: - Получение списка акций
    
    func fetchStocks() -> AnyPublisher<[Stock], Error> {
        print("🟡 Загружаю через FCS API")
        
        let symbolsString = defaultSymbols.joined(separator: ",")
        let urlString = "https://fcsapi.com/api-v3/stock/latest?symbol=\(symbolsString)&access_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Ответ FCS: \(jsonString.prefix(200))...")
                }
            })
            .decode(type: FCSQuoteResponse.self, decoder: decoder)
            .map { response -> [Stock] in
                guard let quotes = response.response else {
                    print("❌ Нет данных в ответе")
                    return []
                }
                
                print("📊 Получено \(quotes.count) записей от FCS")
                
                // Группируем по символам
                var seenSymbols = Set<String>()
                var uniqueStocks: [Stock] = []
                
                for quote in quotes {
                    if !seenSymbols.contains(quote.s) {
                        seenSymbols.insert(quote.s)
                        
                        guard let price = Double(quote.c) else {
                            print("❌ Не могу конвертировать цену: \(quote.s) - \(quote.c)")
                            continue
                        }
                        
                        let change = quote.ch.flatMap { Double($0) } ?? 0
                        let changePercentString = quote.cp?.replacingOccurrences(of: "%", with: "")
                        let changePercent = changePercentString.flatMap { Double($0) } ?? 0
                        let volume = quote.vo.flatMap { Int($0) } ?? 0
                        
                        let stock = Stock(
                            symbol: quote.s,
                            name: quote.name ?? quote.s,
                            currency: quote.ccy ?? "USD",
                            currentPrice: price,
                            change: change,
                            changePercent: changePercent,
                            volume: volume,
                            marketCap: nil
                        )
                        
                        uniqueStocks.append(stock)
                    }
                }
                
                print("✅ Уникальных акций: \(uniqueStocks.count)")
                return uniqueStocks
            }
            .catch { error -> AnyPublisher<[Stock], Error> in
                print("❌ FCS API ошибка: \(error.localizedDescription)")
                print("🔄 Использую тестовые данные")
                
                // Тестовые данные
                let mockStocks = [
                    Stock(symbol: "AAPL", name: "Apple Inc.", currency: "USD", currentPrice: 175.50, change: 2.30, changePercent: 1.33, volume: 55000000, marketCap: 2800000000000),
                    Stock(symbol: "GOOGL", name: "Alphabet Inc.", currency: "USD", currentPrice: 142.80, change: -1.20, changePercent: -0.83, volume: 22000000, marketCap: 1800000000000),
                    Stock(symbol: "MSFT", name: "Microsoft Corp.", currency: "USD", currentPrice: 378.85, change: 3.45, changePercent: 0.92, volume: 18000000, marketCap: 2800000000000),
                    Stock(symbol: "AMZN", name: "Amazon.com Inc.", currency: "USD", currentPrice: 178.12, change: 1.67, changePercent: 0.95, volume: 25000000, marketCap: 1850000000000),
                    Stock(symbol: "TSLA", name: "Tesla Inc.", currency: "USD", currentPrice: 172.63, change: -4.32, changePercent: -2.44, volume: 98000000, marketCap: 550000000000)
                ]
                return Just(mockStocks)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Получение исторических данных
    
    func fetchStockHistory(symbol: String) -> AnyPublisher<StockHistory, Error> {
        print("🟡 Загружаю историю через FCS для \(symbol)")
        
        let urlString = "https://fcsapi.com/api-v3/stock/history?symbol=\(symbol)&period=1d&access_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        struct FCSHistoryResponse: Codable {
            let status: Bool
            let code: Int
            let msg: String
            let response: [String: FCSHistoryPoint]?  // Изменено на response
        }
        
        struct FCSHistoryPoint: Codable {
            let o: String  // open как строка
            let h: String  // high как строка
            let l: String  // low как строка
            let c: String  // close как строка
            let v: String? // volume как строка
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: FCSHistoryResponse.self, decoder: decoder)
            .tryMap { response -> StockHistory in
                guard let data = response.response else {
                    throw URLError(.cannotParseResponse)
                }
                
                var historicalData: [HistoricalData] = []
                let formatter = ISO8601DateFormatter()
                
                // Сортируем по ключам (датам)
                let sortedKeys = data.keys.sorted()
                
                for key in sortedKeys {
                    guard let point = data[key],
                          let close = Double(point.c),
                          let timestamp = Double(key) else { continue }
                    
                    let date = Date(timeIntervalSince1970: timestamp)
                    let dateString = formatter.string(from: date)
                    
                    let open = Double(point.o) ?? close
                    let high = Double(point.h) ?? close
                    let low = Double(point.l) ?? close
                    let volume = point.v.flatMap { Int($0) } ?? 0
                    
                    historicalData.append(HistoricalData(
                        date: dateString,
                        open: open,
                        high: high,
                        low: low,
                        close: close,
                        volume: volume
                    ))
                }
                
                return StockHistory(symbol: symbol, historical: historicalData)
            }
            .catch { error -> AnyPublisher<StockHistory, Error> in
                print("❌ Ошибка истории: \(error.localizedDescription)")
                print("🔄 Создаю тестовые данные для \(symbol)")
                
                // Тестовые данные (как в Yahoo версии)
                var mockHistorical: [HistoricalData] = []
                let calendar = Calendar.current
                let today = Date()
                
                var basePrice: Double = 150.0
                switch symbol {
                case "AAPL": basePrice = 175.0
                case "GOOGL": basePrice = 140.0
                case "MSFT": basePrice = 380.0
                case "AMZN": basePrice = 178.0
                case "TSLA": basePrice = 170.0
                default: basePrice = 150.0
                }
                
                for i in 0..<30 {
                    if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                        let formatter = ISO8601DateFormatter()
                        let dateString = formatter.string(from: date)
                        
                        let trend = Double(i) * 0.2
                        let randomWalk = Double.random(in: -8...8)
                        let price = basePrice - trend + randomWalk
                        
                        mockHistorical.append(HistoricalData(
                            date: dateString,
                            open: price,
                            high: price + Double.random(in: 1...4),
                            low: price - Double.random(in: 1...4),
                            close: price,
                            volume: Int.random(in: 1000000...10000000)
                        ))
                    }
                }
                
                mockHistorical.sort { $0.date < $1.date }
                return Just(StockHistory(symbol: symbol, historical: mockHistorical))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func searchStocks(query: String) -> AnyPublisher<[Stock], Error> {
        print("🟡 Поиск: \(query)")
        
        let urlString = "https://fcsapi.com/api-v3/stock/search?symbol=\(query)&access_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: FCSQuoteResponse.self, decoder: decoder)
            .map { response -> [Stock] in
                guard let quotes = response.response else { return [] }
                
                return quotes.compactMap { quote -> Stock? in
                    guard let price = Double(quote.c) else { return nil }
                    
                    let change = quote.ch.flatMap { Double($0) } ?? 0
                    let changePercentString = quote.cp?.replacingOccurrences(of: "%", with: "")
                    let changePercent = changePercentString.flatMap { Double($0) } ?? 0
                    let volume = quote.vo.flatMap { Int($0) } ?? 0
                    
                    return Stock(
                        symbol: quote.s,
                        name: quote.name ?? quote.s,
                        currency: quote.ccy ?? "USD",
                        currentPrice: price,
                        change: change,
                        changePercent: changePercent,
                        volume: volume,
                        marketCap: nil
                    )
                }
            }
            .catch { error -> AnyPublisher<[Stock], Error> in
                print("❌ Ошибка поиска: \(error)")
                return Just([])
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
