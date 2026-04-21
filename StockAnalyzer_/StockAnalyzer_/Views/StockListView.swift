import SwiftUI
import DGCharts

struct StockListView: View {
    @StateObject private var viewModel = StockViewModel()
    @State private var searchText = ""
    
    var filteredStocks: [Stock] {
        if searchText.isEmpty {
            return viewModel.stocks
        } else {
            return viewModel.stocks.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
                
                ForEach(filteredStocks) { stock in
                    NavigationLink {
                        StockDetailView(stock: stock)
                    } label: {
                        StockRowView(stock: stock)
                    }
                }
            }
            .navigationTitle("Акции")
            .searchable(text: $searchText, placement: .navigationBarDrawer)
            .refreshable {
                viewModel.loadStocks()
            }
        }
        .onAppear {
            viewModel.loadStocks()
        }
    }
}

struct StockRowView: View {
    let stock: Stock
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.symbol)
                    .font(.headline)
                Text(stock.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", stock.currentPrice))
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Image(systemName: stock.change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                    Text(String(format: "%.2f (%.2f%%)", stock.change, stock.changePercent))
                        .font(.caption)
                }
                .foregroundColor(stock.change >= 0 ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    (stock.change >= 0 ? Color.green : Color.red)
                        .opacity(0.2)
                        .cornerRadius(4)
                )
            }
        }
        .padding(.vertical, 4)
    }
}

struct StockDetailView: View {
    let stock: Stock
    @StateObject private var viewModel = StockViewModel()
    @State private var analysisResults: [TechnicalIndicator] = []
    @State private var selectedStrategyIndex = 0
    
    let strategies: [AnalysisStrategy] = [MovingAverageStrategy(), RSIAnalysisStrategy()]
    let strategyNames = ["Скользящие средние", "RSI"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StockInfoCard(stock: stock)
                
                if !viewModel.historicalData.isEmpty {
                    StockChartView(data: viewModel.historicalData, symbol: stock.symbol)
                        .frame(height: 300)
                        .padding()
                    
                    VStack(alignment: .leading) {
                        Text("Стратегия анализа")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("Стратегия", selection: $selectedStrategyIndex) {
                            ForEach(0..<strategyNames.count, id: \.self) { index in
                                Text(strategyNames[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    
                    if !analysisResults.isEmpty {
                        AnalysisResultsView(results: analysisResults)
                    }
                }
            }
        }
        .navigationTitle(stock.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadStockHistory(symbol: stock.symbol)
        }
        // ИСПРАВЛЕНО: используем onChange с конкретным значением, а не массивом
        .onChange(of: viewModel.historicalData.count) { _ in
            analyzeData()
        }
        .onChange(of: selectedStrategyIndex) { _ in
            analyzeData()
        }
    }
    
    private func analyzeData() {
        guard !viewModel.historicalData.isEmpty else { return }
        let strategy = strategies[selectedStrategyIndex]
        analysisResults = strategy.analyze(data: viewModel.historicalData)
    }
}

struct StockInfoCard: View {
    let stock: Stock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(stock.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(stock.symbol)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(String(format: "$%.2f", stock.currentPrice))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: stock.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%.2f (%.2f%%)", stock.change, stock.changePercent))
                    }
                    .font(.subheadline)
                    .foregroundColor(stock.change >= 0 ? .green : .red)
                }
            }
            
            Divider()
            
            HStack {
                Label("Объем: \(formatVolume(stock.volume))", systemImage: "chart.bar")
                Spacer()
                if let marketCap = stock.marketCap {
                    Label("Кап.: \(formatMarketCap(marketCap))", systemImage: "banknote")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private func formatVolume(_ volume: Int) -> String {
        if volume > 1_000_000 {
            return String(format: "%.1fM", Double(volume) / 1_000_000)
        } else if volume > 1_000 {
            return String(format: "%.1fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }
    
    private func formatMarketCap(_ marketCap: Double) -> String {
        if marketCap > 1_000_000_000_000 {
            return String(format: "%.2fT", marketCap / 1_000_000_000_000)
        } else if marketCap > 1_000_000_000 {
            return String(format: "%.2fB", marketCap / 1_000_000_000)
        } else if marketCap > 1_000_000 {
            return String(format: "%.2fM", marketCap / 1_000_000)
        }
        return String(format: "%.0f", marketCap)
    }
}

struct AnalysisResultsView: View {
    let results: [TechnicalIndicator]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Технический анализ")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(results, id: \.name) { indicator in
                HStack {
                    Text(indicator.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f", indicator.value))
                        .font(.subheadline)
                        .monospacedDigit()
                    
                    Text(indicator.signal.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(colorForSignal(indicator.signal).opacity(0.2))
                        )
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private func colorForSignal(_ signal: TechnicalIndicator.SignalType) -> Color {
        switch signal {
        case .buy: return .green
        case .sell: return .red
        case .neutral: return .gray
        }
    }
}
