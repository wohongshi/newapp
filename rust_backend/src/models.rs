use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Product {
    pub id: String,
    pub barcode: String,
    pub name: String,
    pub brand: String,
    pub category: String,
    pub price: f64,
    pub cost: f64,
    pub stock: i32,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CartItem {
    pub product_id: String,
    pub barcode: String,
    pub name: String,
    pub brand: String,
    pub price: f64,
    pub cost: f64,
    pub quantity: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaleRecord {
    pub id: String,
    pub items: Vec<SaleItem>,
    pub total: f64,
    pub original_total: f64,
    pub discount: f64,
    pub payment_method: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaleItem {
    pub product_id: String,
    pub name: String,
    pub brand: String,
    pub price: f64,
    pub original_price: f64,
    pub quantity: i32,
    pub subtotal: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PricingRule {
    pub id: String,
    pub name: String,
    pub enabled: bool,
    pub priority: i32,
    pub conditions: Vec<RuleCondition>,
    pub action: RuleAction,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleCondition {
    pub field: String,      // "quantity", "brand", "price", "category", "total_quantity"
    pub operator: String,   // "gte", "lte", "eq", "neq", "contains", "in"
    pub value: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleAction {
    pub action_type: String, // "fixed_price", "percent_discount", "amount_discount", "bogo"
    pub value: f64,
    pub apply_to: String,    // "item", "all_matching", "cart"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckoutResult {
    pub items: Vec<ProcessedItem>,
    pub original_total: f64,
    pub final_total: f64,
    pub total_discount: f64,
    pub applied_rules: Vec<AppliedRule>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessedItem {
    pub product_id: String,
    pub name: String,
    pub brand: String,
    pub original_price: f64,
    pub final_price: f64,
    pub quantity: i32,
    pub original_subtotal: f64,
    pub final_subtotal: f64,
    pub discount: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppliedRule {
    pub rule_id: String,
    pub rule_name: String,
    pub discount_amount: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RevenueStats {
    pub period: String,
    pub total_revenue: f64,
    pub total_cost: f64,
    pub total_profit: f64,
    pub profit_margin: f64,
    pub total_transactions: i32,
    pub total_items_sold: i32,
    pub average_transaction: f64,
    pub daily_data: Vec<DailyData>,
    pub brand_breakdown: Vec<BrandStats>,
    pub category_breakdown: Vec<CategoryStats>,
    pub top_products: Vec<ProductStats>,
    pub rule_savings: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DailyData {
    pub date: String,
    pub revenue: f64,
    pub profit: f64,
    pub transactions: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrandStats {
    pub brand: String,
    pub revenue: f64,
    pub quantity: i32,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryStats {
    pub category: String,
    pub revenue: f64,
    pub quantity: i32,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProductStats {
    pub name: String,
    pub brand: String,
    pub revenue: f64,
    pub quantity: i32,
    pub profit: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupResult {
    pub success: bool,
    pub message: String,
    pub file_path: Option<String>,
    pub file_size: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportResult {
    pub success: bool,
    pub message: String,
    pub file_path: Option<String>,
    pub count: usize,
}
