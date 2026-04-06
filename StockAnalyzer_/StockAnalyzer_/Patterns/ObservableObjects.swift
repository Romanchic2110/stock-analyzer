import Foundation
import Combine

class StockViewModel: ObservableObject {
    @Published var stocks: [Stock] = []
    @Published var selectedStock: Stock?
    @Published var historicalData: [HistoricalData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: APIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    func loadStocks() {
        isLoading = true
        errorMessage = nil
        print("🟢 ViewModel: начинаем загрузку stocks")
        
        apiService.fetchStocks()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    print("🔴 Ошибка загрузки: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] stocks in
                self?.stocks = stocks
                print("✅ ViewModel: получили \(stocks.count) акций")
            }
            .store(in: &cancellables)
    }
    
    func loadStockHistory(symbol: String) {
        isLoading = true
        print("🟡 ViewModel: загружаю историю для \(symbol)")
        
        apiService.fetchStockHistory(symbol: symbol)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    print("🔴 Ошибка загрузки истории: \(error)")
                }
            } receiveValue: { [weak self] history in
                self?.historicalData = history.historical
                print("✅ ViewModel: получил \(history.historical.count) точек для графика")
            }
            .store(in: &cancellables)
    }
}

// MARK: - Стратегии анализа
protocol AnalysisStrategy {
    func analyze(data: [HistoricalData]) -> [TechnicalIndicator]
}

class MovingAverageStrategy: AnalysisStrategy {
    func analyze(data: [HistoricalData]) -> [TechnicalIndicator] {
        guard data.count >= 20 else { return [] }
        
        let closes = data.map { $0.close }
        let ma20 = calculateMA(prices: closes, period: 20)
        let ma50 = calculateMA(prices: closes, period: min(50, closes.count))
        
        var indicators: [TechnicalIndicator] = []
        
        if let lastMA20 = ma20.last, let lastMA50 = ma50.last {
            if lastMA20 > lastMA50 {
                indicators.append(TechnicalIndicator(
                    name: "MA Cross",
                    value: lastMA20 - lastMA50,
                    signal: .buy
                ))
            } else {
                indicators.append(TechnicalIndicator(
                    name: "MA Cross",
                    value: lastMA50 - lastMA20,
                    signal: .sell
                ))
            }
        }
        
        return indicators
    }
    
    private func calculateMA(prices: [Double], period: Int) -> [Double] {
        guard prices.count >= period else { return [] }
        
        var result: [Double] = []
        for i in period - 1..<prices.count {
            let sum = prices[i - period + 1...i].reduce(0, +)
            result.append(sum / Double(period))
        }
        return result
    }
}

class RSIAnalysisStrategy: AnalysisStrategy {
    func analyze(data: [HistoricalData]) -> [TechnicalIndicator] {
        guard data.count >= 15 else { return [] }
        
        let closes = data.map { $0.close }
        let rsi = calculateRSI(prices: closes, period: 14)
        
        guard let lastRSI = rsi.last else { return [] }
        
        let signal: TechnicalIndicator.SignalType
        if lastRSI < 30 {
            signal = .buy
        } else if lastRSI > 70 {
            signal = .sell
        } else {
            signal = .neutral
        }
        
        return [TechnicalIndicator(name: "RSI", value: lastRSI, signal: signal)]
    }
    
    private func calculateRSI(prices: [Double], period: Int) -> [Double] {
        guard prices.count > period else { return [] }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<prices.count {
            let diff = prices[i] - prices[i - 1]
            gains.append(max(diff, 0))
            losses.append(max(-diff, 0))
        }
        
        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
        
        var rsiValues: [Double] = []
        
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            
            let rs = avgLoss == 0 ? 100 : avgGain / avgLoss
            let rsi = 100 - (100 / (1 + rs))
            rsiValues.append(rsi)
        }
        
        return rsiValues
    }
}
