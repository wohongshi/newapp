use std::collections::HashMap;
use chrono::{Utc, NaiveDate, Duration};
use crate::models::*;

pub fn calculate_revenue(sales: &[SaleRecord], period: &str) -> RevenueStats {
    let now = Utc::now().naive_utc().date();
    let filtered = filter_by_period(sales, period, now);

    let total_revenue: f64 = filtered.iter().map(|s| s.total).sum();
    let total_discount: f64 = filtered.iter().map(|s| s.discount).sum();
    let total_transactions = filtered.len() as i32;
    let total_items_sold: i32 = filtered.iter().map(|s| s.items.iter().map(|i| i.quantity).sum::<i32>()).sum();

    // Calculate cost (using price as proxy since we have original_price)
    let total_cost: f64 = filtered.iter().flat_map(|s| &s.items)
        .map(|i| (i.price * 0.6) * i.quantity as f64) // Estimate cost as 60% of price
        .sum();

    let total_profit = total_revenue - total_cost;
    let profit_margin = if total_revenue > 0.0 { total_profit / total_revenue * 100.0 } else { 0.0 };
    let average_transaction = if total_transactions > 0 { total_revenue / total_transactions as f64 } else { 0.0 };

    // Daily breakdown
    let daily_data = compute_daily_data(&filtered, period, now);

    // Brand breakdown
    let brand_map = compute_brand_breakdown(&filtered);
    let brand_breakdown = brand_map_to_stats(&brand_map, total_revenue);

    // Category breakdown (use brand as category proxy)
    let category_map = compute_category_breakdown(&filtered);
    let category_breakdown = category_map_to_stats(&category_map, total_revenue);

    // Top products
    let top_products = compute_top_products(&filtered);

    RevenueStats {
        period: period.to_string(),
        total_revenue: round2(total_revenue),
        total_cost: round2(total_cost),
        total_profit: round2(total_profit),
        profit_margin: round2(profit_margin),
        total_transactions,
        total_items_sold,
        average_transaction: round2(average_transaction),
        daily_data,
        brand_breakdown,
        category_breakdown,
        top_products,
        rule_savings: round2(total_discount),
    }
}

fn filter_by_period(sales: &[SaleRecord], period: &str, now: NaiveDate) -> Vec<SaleRecord> {
    let start_date = match period {
        "day" => now,
        "week" => now - Duration::days(7),
        "month" => now - Duration::days(30),
        "quarter" => now - Duration::days(90),
        "year" => now - Duration::days(365),
        _ => now,
    };

    sales.iter()
        .filter(|s| {
            if let Ok(date) = NaiveDate::parse_from_str(&s.created_at[..10], "%Y-%m-%d") {
                date >= start_date && date <= now
            } else {
                false
            }
        })
        .cloned()
        .collect()
}

fn compute_daily_data(sales: &[SaleRecord], period: &str, now: NaiveDate) -> Vec<DailyData> {
    let mut map: HashMap<String, (f64, f64, i32)> = HashMap::new();

    for sale in sales {
        let date = &sale.created_at[..10];
        let entry = map.entry(date.to_string()).or_insert((0.0, 0.0, 0));
        entry.0 += sale.total;
        entry.1 += sale.total - sale.items.iter().map(|i| (i.price * 0.6) * i.quantity as f64).sum::<f64>();
        entry.2 += 1;
    }

    let days = match period {
        "day" => 1,
        "week" => 7,
        "month" => 30,
        "quarter" => 90,
        "year" => 365,
        _ => 7,
    };

    let mut result = Vec::new();
    for i in (0..days).rev() {
        let date = now - Duration::days(i);
        let date_str = date.format("%Y-%m-%d").to_string();
        let (rev, profit, txn) = map.get(&date_str).copied().unwrap_or((0.0, 0.0, 0));
        result.push(DailyData {
            date: date_str,
            revenue: round2(rev),
            profit: round2(profit),
            transactions: txn,
        });
    }

    result
}

fn compute_brand_breakdown(sales: &[SaleRecord]) -> HashMap<String, (f64, i32)> {
    let mut map: HashMap<String, (f64, i32)> = HashMap::new();
    for sale in sales {
        for item in &sale.items {
            let entry = map.entry(item.brand.clone()).or_insert((0.0, 0));
            entry.0 += item.price * item.quantity as f64;
            entry.1 += item.quantity;
        }
    }
    map
}

fn brand_map_to_stats(map: &HashMap<String, (f64, i32)>, total: f64) -> Vec<BrandStats> {
    let mut stats: Vec<BrandStats> = map.iter().map(|(brand, (rev, qty))| {
        BrandStats {
            brand: brand.clone(),
            revenue: round2(*rev),
            quantity: *qty,
            percentage: if total > 0.0 { round2(rev / total * 100.0) } else { 0.0 },
        }
    }).collect();
    stats.sort_by(|a, b| b.revenue.partial_cmp(&a.revenue).unwrap());
    stats
}

fn compute_category_breakdown(sales: &[SaleRecord]) -> HashMap<String, (f64, i32)> {
    let mut map: HashMap<String, (f64, i32)> = HashMap::new();
    for sale in sales {
        for item in &sale.items {
            // Use brand as category proxy
            let entry = map.entry(item.brand.clone()).or_insert((0.0, 0));
            entry.0 += item.price * item.quantity as f64;
            entry.1 += item.quantity;
        }
    }
    map
}

fn category_map_to_stats(map: &HashMap<String, (f64, i32)>, total: f64) -> Vec<CategoryStats> {
    let mut stats: Vec<CategoryStats> = map.iter().map(|(cat, (rev, qty))| {
        CategoryStats {
            category: cat.clone(),
            revenue: round2(*rev),
            quantity: *qty,
            percentage: if total > 0.0 { round2(rev / total * 100.0) } else { 0.0 },
        }
    }).collect();
    stats.sort_by(|a, b| b.revenue.partial_cmp(&a.revenue).unwrap());
    stats
}

fn compute_top_products(sales: &[SaleRecord]) -> Vec<ProductStats> {
    let mut map: HashMap<String, ProductStats> = HashMap::new();
    for sale in sales {
        for item in &sale.items {
            let entry = map.entry(item.name.clone()).or_insert(ProductStats {
                name: item.name.clone(),
                brand: item.brand.clone(),
                revenue: 0.0,
                quantity: 0,
                profit: 0.0,
            });
            entry.revenue += item.price * item.quantity as f64;
            entry.quantity += item.quantity;
            entry.profit += (item.price - item.price * 0.6) * item.quantity as f64;
        }
    }
    let mut stats: Vec<ProductStats> = map.into_values().collect();
    stats.sort_by(|a, b| b.revenue.partial_cmp(&a.revenue).unwrap());
    stats.into_iter().take(10).collect()
}

fn round2(v: f64) -> f64 {
    (v * 100.0).round() / 100.0
}
