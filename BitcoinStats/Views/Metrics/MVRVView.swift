import SwiftUI
import Charts

struct MVRVView: View {

    @State private var viewModel = MVRVViewModel()

    var body: some View {
        mvrvContent
            .navigationTitle("MVRV Ratio")
            .task(id: viewModel.selectedTimeRange) {
                await viewModel.load()
            }
    }

    // MARK: - Subviews

    private var mvrvContent: some View {
        VStack(spacing: 0) {
            chartArea
        }
    }

    private var chartArea: some View {
        if viewModel.isLoading && viewModel.history.isEmpty {
            ProgressView("Loading MVRV data…")
                .frame(maxWidth: .infinity)
                .frame(height: 280)
        } else if let error = viewModel.error, viewModel.history.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
                .frame(height: 280)
        } else {
            Chart {
                ForEach(viewModel.history) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("MVRV", point.value)
                    )
                    .foregroundStyle(Color.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let mvrv = value.as(Double.self) {
                            Text(String(format: "%.2f", mvrv))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 280)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .id(viewModel.selectedTimeRange)
        }
    }
}

struct MVRVView_Previews: PreviewProvider {
    static var previews: some View {
        MVRVView()
    }
}
