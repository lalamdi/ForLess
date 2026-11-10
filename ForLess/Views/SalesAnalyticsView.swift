//
//  SalesAnalyticsView.swift
//  ForLess
//
//  Created by Leen Almeadadi on 10/11/2026.
//

//  Business "Sales & analytics" screen, opened from the Profile tab.
//  Switch between Weekly, Monthly and All time to see total sales, orders,
//  average order, meals saved and best sellers.
//  Weekly has a bar for each day of this week, Monthly has a bar for each month,
//  and All time has a line that shows how total sales grew (no dates).
//  Only orders that were picked up are counted, by the day they were ordered.
//

import SwiftUI
import Charts

struct SalesAnalyticsView: View {
    let orders: [Order]            // all orders of the store
    let deals: [String: Deal]      // dealId -> deal (for the best sellers' pictures)

    enum Period: String, CaseIterable {
        case week = "Weekly"
        case month = "Monthly"
        case all = "All time"
    }

    /// One bar of the chart.
    struct Bar {
        let label: String
        let value: Double
    }

    /// One point of the growth line: total sales after this many orders.
    struct GrowthPoint: Identifiable {
        let id: Int
        let total: Double
    }

    @State private var period: Period = .week
    private let calendar = Calendar.current

    // MARK: - Numbers

    private var doneOrders: [Order] {
        orders.filter { $0.status == .pickedUp }
    }

    /// Picked up orders between two dates (nil means no limit).
    private func ordersBetween(_ from: Date?, _ to: Date?) -> [Order] {
        doneOrders.filter { order in
            if let from, order.createdAt < from { return false }
            if let to, order.createdAt >= to { return false }
            return true
        }
    }

    private func sales(of list: [Order]) -> Double {
        list.reduce(0) { $0 + $1.total }
    }

    /// Where the chosen period starts (nil = all time).
    private var periodStart: Date? {
        switch period {
        case .week:
            // the start of the current week
            return calendar.dateInterval(of: .weekOfYear, for: Date())?.start
                ?? calendar.startOfDay(for: Date())
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
        case .all:
            return nil
        }
    }

    private var periodOrders: [Order] {
        ordersBetween(periodStart, nil)
    }

    private var totalSales: Double {
        sales(of: periodOrders)
    }

    private var mealsSaved: Int {
        periodOrders.reduce(0) { total, order in
            total + order.items.reduce(0) { $0 + $1.quantity }
        }
    }

    private var averageOrder: Double {
        periodOrders.isEmpty ? 0 : totalSales / Double(periodOrders.count)
    }

    /// "18% vs last week" compared with the period before (not for All time).
    private var change: (text: String, isUp: Bool)? {
        guard let start = periodStart else { return nil }
        let previousStart: Date?
        switch period {
        case .week: previousStart = calendar.date(byAdding: .day, value: -7, to: start)
        case .month: previousStart = calendar.date(byAdding: .month, value: -1, to: start)
        case .all: previousStart = nil
        }
        guard let previousStart else { return nil }

        let before = sales(of: ordersBetween(previousStart, start))
        guard before > 0 else { return nil }

        let percent = Int(((totalSales - before) / before * 100).rounded())
        let word = period == .week ? "last week" : "last month"
        let arrow = percent >= 0 ? "↑" : "↓"
        return ("\(arrow) \(abs(percent))% vs \(word)", percent >= 0)
    }

    /// Bars of the chart: days for Weekly, months for Monthly (none for All time).
    private var bars: [Bar] {
        switch period {
        case .week:
            // the 7 days of the current week
            let weekStart = periodStart ?? calendar.startOfDay(for: Date())
            return (0..<7).map { index in
                let day = calendar.date(byAdding: .day, value: index, to: weekStart) ?? weekStart
                let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                return Bar(label: day.formatted(.dateTime.weekday(.abbreviated)),
                           value: sales(of: ordersBetween(day, next)))
            }

        case .month:
            // From the first order's month to this month (at least 3 bars, at most 6)
            let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
            let firstDate = doneOrders.map { $0.createdAt }.min() ?? Date()
            let firstMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: firstDate)) ?? thisMonth
            let oldest = calendar.date(byAdding: .month, value: -5, to: thisMonth) ?? thisMonth
            let newest = calendar.date(byAdding: .month, value: -2, to: thisMonth) ?? thisMonth

            var month = min(max(firstMonth, oldest), newest)
            var result: [Bar] = []
            while month <= thisMonth {
                let next = calendar.date(byAdding: .month, value: 1, to: month) ?? thisMonth.addingTimeInterval(1)
                result.append(Bar(label: month.formatted(.dateTime.month(.abbreviated)),
                                  value: sales(of: ordersBetween(month, next))))
                month = next
            }
            return result

        case .all:
            return []   // All time has no chart
        }
    }

    /// Small text under "Total sales" that says which period the numbers are for.
    private var periodName: String {
        switch period {
        case .week: return "This week"
        case .month: return "This month"
        case .all: return "All time"
        }
    }

    /// Total sales after each completed order, from the first to the last.
    private var growthPoints: [GrowthPoint] {
        var running = 0.0
        var points = [GrowthPoint(id: 0, total: 0)]
        let sortedOrders = doneOrders.sorted { $0.createdAt < $1.createdAt }
        for (index, order) in sortedOrders.enumerated() {
            running += order.total
            points.append(GrowthPoint(id: index + 1, total: running))
        }
        return points
    }

    /// Items sold in this period, most sold first (top 3).
    private var bestSellers: [(dealId: String, title: String, sold: Int, sales: Double)] {
        var totals: [String: (title: String, sold: Int, sales: Double)] = [:]
        for order in periodOrders {
            for item in order.items {
                let old = totals[item.dealId] ?? (title: item.title, sold: 0, sales: 0)
                totals[item.dealId] = (title: item.title, sold: old.sold + item.quantity, sales: old.sales + item.price * Double(item.quantity))
            }
        }
        let sorted = totals.map { (dealId: $0.key, title: $0.value.title, sold: $0.value.sold, sales: $0.value.sales) }
            .sorted { $0.sold > $1.sold }
        return Array(sorted.prefix(3))
    }

    // MARK: - Screen

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                periodPicker
                salesCard
                statBoxes
                bestSellersCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("Sales & analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pieces of the screen

    /// This week / This month / All time switch.
    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(Period.allCases, id: \.self) { option in
                Button {
                    period = option
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(period == option ? Color.brandText : Color.muted)
                        .background(period == option ? Color.white : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: 0xEFE7E1), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Total sales, the change and the bar chart.
    private var salesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total sales · \(periodName)")
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)
            Text(qar(totalSales))
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(Color.brandText)

            if let change {
                Text(change.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(change.isUp ? Color(hex: 0x1E6B45) : Color(hex: 0xC0392B))
            }

            if period == .all {
                growthChart
                    .padding(.top, 10)
            } else {
                chart
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    /// The tallest bar is dark orange, the others light orange.
    private var chart: some View {
        let highest = max(bars.map { $0.value }.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(bar.value > 0 && bar.value == highest ? Color.brand : Color.brand.opacity(0.35))
                        .frame(height: bar.value > 0 ? max(6, CGFloat(bar.value / highest) * 110) : 4)
                    Text(bar.label)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: 140, alignment: .bottom)
    }

    /// A line that goes up as total sales grow, from the first order to today.
    @ViewBuilder
    private var growthChart: some View {
        if growthPoints.count < 3 {
            Text("Complete a few orders to see how your sales grow.")
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)
        } else {
            VStack(spacing: 6) {
                Chart(growthPoints) { point in
                    AreaMark(x: .value("Order", point.id), y: .value("Sales", point.total))
                        .foregroundStyle(Color.brand.opacity(0.15))
                    LineMark(x: .value("Order", point.id), y: .value("Sales", point.total))
                        .foregroundStyle(Color.brand)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 130)

                HStack {
                    Spacer()
                    Text("Today")
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.muted)
            }
        }
    }

    /// Orders, Average order and Meals saved.
    private var statBoxes: some View {
        HStack(spacing: 10) {
            statBox(value: "\(periodOrders.count)", label: "Orders",
                    textColor: Color.brandDark, background: Color.brandLight)
            statBox(value: qar(averageOrder), label: "Avg order",
                    textColor: Color(hex: 0x1E6B45), background: Color(hex: 0xE7F3EC))
            statBox(value: "\(mealsSaved)", label: "Meals saved",
                    textColor: Color.brandDark, background: Color.brandLight)
        }
    }

    private func statBox(value: String, label: String, textColor: Color, background: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(textColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(background, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Picture of the deal, or a light square with a fork and knife if there is none.
    @ViewBuilder
    private func itemPicture(for dealId: String) -> some View {
        if let urlString = deals[dealId]?.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.brandLight
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandLight)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "fork.knife").foregroundStyle(Color.brand))
        }
    }

    /// The three items sold the most.
    private var bestSellersCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BEST SELLERS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.muted)
                .padding(.bottom, 6)

            if bestSellers.isEmpty {
                Text("No completed orders in this period yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.muted)
                    .padding(.vertical, 8)
            }

            ForEach(Array(bestSellers.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    itemPicture(for: item.dealId)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.ink)
                        Text("\(item.sold) sold")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.muted)
                    }
                    Spacer()
                    Text(qar(item.sales))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ink)
                }
                .padding(.vertical, 10)

                if index < bestSellers.count - 1 {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }
}
