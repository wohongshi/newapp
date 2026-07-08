use rusqlite::{Connection, params};
use std::fs;
use std::path::Path;
use chrono::Utc;
use zip::write::{FileOptions, ZipWriter};
use zip::read::ZipArchive;
use crate::models::*;

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn new(path: &str) -> Result<Self, String> {
        let conn = Connection::open(path).map_err(|e| e.to_string())?;

        conn.execute_batch("
            CREATE TABLE IF NOT EXISTS products (
                id TEXT PRIMARY KEY,
                barcode TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                brand TEXT DEFAULT '',
                category TEXT DEFAULT '',
                price REAL NOT NULL DEFAULT 0,
                cost REAL NOT NULL DEFAULT 0,
                stock INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sales (
                id TEXT PRIMARY KEY,
                total REAL NOT NULL,
                original_total REAL NOT NULL,
                discount REAL NOT NULL DEFAULT 0,
                payment_method TEXT DEFAULT 'cash',
                created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sale_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sale_id TEXT NOT NULL,
                product_id TEXT NOT NULL,
                name TEXT NOT NULL,
                brand TEXT DEFAULT '',
                price REAL NOT NULL,
                original_price REAL NOT NULL,
                quantity INTEGER NOT NULL,
                subtotal REAL NOT NULL,
                FOREIGN KEY (sale_id) REFERENCES sales(id)
            );

            CREATE TABLE IF NOT EXISTS pricing_rules (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                enabled INTEGER NOT NULL DEFAULT 1,
                priority INTEGER NOT NULL DEFAULT 0,
                rules_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
            CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand);
            CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
            CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(created_at);
            CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);
        ").map_err(|e| e.to_string())?;

        Ok(Database { conn })
    }
}

pub fn create_backup(db_path: &str, backup_path: &str) -> BackupResult {
    let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
    let backup_file = format!("{}/backup_{}.zip", backup_path, timestamp);

    let result = (|| -> Result<(), String> {
        let zip_path = Path::new(&backup_file);
        let file = fs::File::create(zip_path).map_err(|e| e.to_string())?;
        let mut zip = ZipWriter::new(file);
        let options = FileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated)
            .unix_permissions(0o755);

        // Add database file
        let db_data = fs::read(db_path).map_err(|e| e.to_string())?;
        zip.start_file("database.db", options).map_err(|e| e.to_string())?;
        std::io::Write::write_all(&mut zip, &db_data).map_err(|e| e.to_string())?;

        // Add metadata
        let meta = serde_json::json!({
            "version": "1.0",
            "created_at": Utc::now().to_rfc3339(),
            "db_size": db_data.len(),
        });
        zip.start_file("metadata.json", options).map_err(|e| e.to_string())?;
        std::io::Write::write_all(&mut zip, meta.to_string().as_bytes()).map_err(|e| e.to_string())?;

        zip.finish().map_err(|e| e.to_string())?;

        Ok(())
    })();

    match result {
        Ok(()) => {
            let size = fs::metadata(&backup_file).map(|m| m.len()).unwrap_or(0);
            BackupResult {
                success: true,
                message: "备份成功".to_string(),
                file_path: Some(backup_file),
                file_size: Some(size),
            }
        }
        Err(e) => BackupResult {
            success: false,
            message: format!("备份失败: {}", e),
            file_path: None,
            file_size: None,
        },
    }
}

pub fn restore_backup(backup_path: &str, db_path: &str) -> BackupResult {
    let result = (|| -> Result<(), String> {
        let file = fs::File::open(backup_path).map_err(|e| e.to_string())?;
        let mut archive = ZipArchive::new(file).map_err(|e| e.to_string())?;

        // Extract database
        let mut db_file = archive.by_name("database.db").map_err(|e| e.to_string())?;
        let mut db_data = Vec::new();
        std::io::Read::read_to_end(&mut db_file, &mut db_data).map_err(|e| e.to_string())?;

        // Backup current db
        if Path::new(db_path).exists() {
            let backup_old = format!("{}.bak", db_path);
            fs::copy(db_path, &backup_old).map_err(|e| e.to_string())?;
        }

        fs::write(db_path, &db_data).map_err(|e| e.to_string())?;

        Ok(())
    })();

    match result {
        Ok(()) => BackupResult {
            success: true,
            message: "恢复成功".to_string(),
            file_path: Some(backup_path.to_string()),
            file_size: None,
        },
        Err(e) => BackupResult {
            success: false,
            message: format!("恢复失败: {}", e),
            file_path: None,
            file_size: None,
        },
    }
}

pub fn export_products_csv(products: &[Product], path: &str) -> ExportResult {
    let result = (|| -> Result<(), String> {
        let mut wtr = csv::Writer::from_path(path).map_err(|e| e.to_string())?;

        wtr.write_record(&["ID", "条码", "名称", "品牌", "分类", "售价", "成本", "库存"])
            .map_err(|e| e.to_string())?;

        for p in products {
            wtr.write_record(&[
                &p.id,
                &p.barcode,
                &p.name,
                &p.brand,
                &p.category,
                &p.price.to_string(),
                &p.cost.to_string(),
                &p.stock.to_string(),
            ]).map_err(|e| e.to_string())?;
        }

        wtr.flush().map_err(|e| e.to_string())?;
        Ok(())
    })();

    match result {
        Ok(()) => ExportResult {
            success: true,
            message: "导出成功".to_string(),
            file_path: Some(path.to_string()),
            count: products.len(),
        },
        Err(e) => ExportResult {
            success: false,
            message: format!("导出失败: {}", e),
            file_path: None,
            count: 0,
        },
    }
}
