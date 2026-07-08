use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::Mutex;

mod models;
mod database;
mod pricing;
mod stats;

use database::Database;

static DB: Mutex<Option<Database>> = Mutex::new(None);

/// Initialize database at given path
#[no_mangle]
pub extern "C" fn init_db(path: *const c_char) -> *mut c_char {
    let c_str = unsafe { CStr::from_ptr(path) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(e) => return to_cstring(format!(r#"{{"error":"{}"}}"#, e)),
    };

    let db = match Database::new(path_str) {
        Ok(d) => d,
        Err(e) => return to_cstring(format!(r#"{{"error":"{}"}}"#, e)),
    };

    if let Ok(mut guard) = DB.lock() {
        *guard = Some(db);
    }

    to_cstring(r#"{"ok":true}"#.to_string())
}

/// Process checkout: evaluate pricing rules and create sale
#[no_mangle]
pub extern "C" fn process_checkout(items_json: *const c_char, rules_json: *const c_char) -> *mut c_char {
    let items_str = unsafe { CStr::from_ptr(items_json) }.to_str().unwrap_or("[]");
    let rules_str = unsafe { CStr::from_ptr(rules_json) }.to_str().unwrap_or("[]");

    let items: Vec<models::CartItem> = serde_json::from_str(items_str).unwrap_or_default();
    let rules: Vec<models::PricingRule> = serde_json::from_str(rules_str).unwrap_or_default();

    let result = pricing::process_cart(&items, &rules);
    let json = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    to_cstring(json)
}

/// Calculate revenue statistics
#[no_mangle]
pub extern "C" fn calc_revenue(sales_json: *const c_char, period: *const c_char) -> *mut c_char {
    let sales_str = unsafe { CStr::from_ptr(sales_json) }.to_str().unwrap_or("[]");
    let period_str = unsafe { CStr::from_ptr(period) }.to_str().unwrap_or("day");

    let sales: Vec<models::SaleRecord> = serde_json::from_str(sales_str).unwrap_or_default();
    let result = stats::calculate_revenue(&sales, period_str);
    let json = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    to_cstring(json)
}

/// Create backup of database
#[no_mangle]
pub extern "C" fn create_backup(db_path: *const c_char, backup_path: *const c_char) -> *mut c_char {
    let db_str = unsafe { CStr::from_ptr(db_path) }.to_str().unwrap_or("");
    let bk_str = unsafe { CStr::from_ptr(backup_path) }.to_str().unwrap_or("");

    let result = database::create_backup(db_str, bk_str);
    let json = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    to_cstring(json)
}

/// Restore database from backup
#[no_mangle]
pub extern "C" fn restore_backup(backup_path: *const c_char, db_path: *const c_char) -> *mut c_char {
    let bk_str = unsafe { CStr::from_ptr(backup_path) }.to_str().unwrap_or("");
    let db_str = unsafe { CStr::from_ptr(db_path) }.to_str().unwrap_or("");

    let result = database::restore_backup(bk_str, db_str);
    let json = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    to_cstring(json)
}

/// Export products to CSV
#[no_mangle]
pub extern "C" fn export_csv(products_json: *const c_char, path: *const c_char) -> *mut c_char {
    let prod_str = unsafe { CStr::from_ptr(products_json) }.to_str().unwrap_or("[]");
    let path_str = unsafe { CStr::from_ptr(path) }.to_str().unwrap_or("");

    let products: Vec<models::Product> = serde_json::from_str(prod_str).unwrap_or_default();
    let result = database::export_products_csv(&products, path_str);
    let json = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    to_cstring(json)
}

/// Free string allocated by Rust
#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { drop(CString::from_raw(s)); }
    }
}

fn to_cstring(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}
