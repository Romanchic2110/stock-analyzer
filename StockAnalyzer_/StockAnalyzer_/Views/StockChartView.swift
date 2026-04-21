import SwiftUI
import DGCharts

struct StockChartView: UIViewRepresentable {
    let data: [HistoricalData]
    let symbol: String
    
    func makeUIView(context: Context) -> LineChartView {
        let chart = LineChartView()
        chart.rightAxis.enabled = false
        chart.leftAxis.labelTextColor = .white
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelTextColor = .white
        chart.legend.textColor = .white
        chart.chartDescription.enabled = false
        chart.pinchZoomEnabled = true
        chart.doubleTapToZoomEnabled = true
        chart.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
        chart.xAxis.gridColor = .darkGray
        chart.leftAxis.gridColor = .darkGray
        
        return chart
    }
    
    func updateUIView(_ uiView: LineChartView, context: Context) {
        let entries = data.enumerated().map { (index, item) -> ChartDataEntry in
            return ChartDataEntry(x: Double(index), y: item.close)
        }
        
        let dataSet = LineChartDataSet(entries: entries, label: symbol)
        dataSet.mode = .cubicBezier
        dataSet.drawCirclesEnabled = false
        dataSet.lineWidth = 2
        dataSet.setColor(.systemBlue)
        dataSet.fillAlpha = 0.3
        dataSet.drawFilledEnabled = true
        dataSet.fillColor = .systemBlue
        dataSet.valueTextColor = .white
        dataSet.highlightColor = .white
        
        let data = LineChartData(dataSet: dataSet)
        uiView.data = data
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject { }
}

