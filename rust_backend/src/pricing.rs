use crate::models::*;

/// Process cart items against pricing rules
pub fn process_cart(items: &[CartItem], rules: &[PricingRule]) -> CheckoutResult {
    let mut processed: Vec<ProcessedItem> = items.iter().map(|item| {
        ProcessedItem {
            product_id: item.product_id.clone(),
            name: item.name.clone(),
            brand: item.brand.clone(),
            original_price: item.price,
            final_price: item.price,
            quantity: item.quantity,
            original_subtotal: item.price * item.quantity as f64,
            final_subtotal: item.price * item.quantity as f64,
            discount: 0.0,
        }
    }).collect();

    let mut applied_rules: Vec<AppliedRule> = Vec::new();

    // Sort rules by priority (higher first)
    let mut sorted_rules: Vec<&PricingRule> = rules.iter().filter(|r| r.enabled).collect();
    sorted_rules.sort_by(|a, b| b.priority.cmp(&a.priority));

    for rule in &sorted_rules {
        match rule.action.apply_to.as_str() {
            "item" => {
                for item in processed.iter_mut() {
                    if evaluate_item_conditions(item, &rule.conditions, items) {
                        let discount = apply_rule_action(
                            &rule.action,
                            item.final_price,
                            item.quantity,
                        );
                        if discount > 0.0 {
                            item.final_price = (item.final_price - discount).max(0.0);
                            item.final_subtotal = item.final_price * item.quantity as f64;
                            item.discount = item.original_subtotal - item.final_subtotal;

                            if !applied_rules.iter().any(|r| r.rule_id == rule.id) {
                                applied_rules.push(AppliedRule {
                                    rule_id: rule.id.clone(),
                                    rule_name: rule.name.clone(),
                                    discount_amount: discount * item.quantity as f64,
                                });
                            } else {
                                if let Some(ar) = applied_rules.iter_mut().find(|r| r.rule_id == rule.id) {
                                    ar.discount_amount += discount * item.quantity as f64;
                                }
                            }
                        }
                    }
                }
            }
            "all_matching" => {
                let matching: Vec<usize> = processed.iter().enumerate()
                    .filter(|(_, item)| evaluate_item_conditions(item, &rule.conditions, items))
                    .map(|(i, _)| i)
                    .collect();

                if !matching.is_empty() {
                    for &idx in &matching {
                        let item = &mut processed[idx];
                        let discount = apply_rule_action(&rule.action, item.final_price, item.quantity);
                        if discount > 0.0 {
                            item.final_price = (item.final_price - discount).max(0.0);
                            item.final_subtotal = item.final_price * item.quantity as f64;
                            item.discount = item.original_subtotal - item.final_subtotal;
                        }
                    }

                    let total_discount: f64 = matching.iter().map(|&i| processed[i].discount).sum();
                    applied_rules.push(AppliedRule {
                        rule_id: rule.id.clone(),
                        rule_name: rule.name.clone(),
                        discount_amount: total_discount,
                    });
                }
            }
            "cart" => {
                let total_qty: i32 = items.iter().map(|i| i.quantity).sum();
                let total_amount: f64 = items.iter().map(|i| i.price * i.quantity as f64).sum();

                if evaluate_cart_conditions(&rule.conditions, total_qty, total_amount) {
                    let cart_discount = apply_rule_action(&rule.action, total_amount, total_qty);
                    if cart_discount > 0.0 {
                        // Distribute discount proportionally
                        let ratio = if total_amount > 0.0 { cart_discount / total_amount } else { 0.0 };
                        for item in processed.iter_mut() {
                            let item_discount = item.final_subtotal * ratio;
                            item.final_subtotal -= item_discount;
                            item.final_price = if item.quantity > 0 {
                                item.final_subtotal / item.quantity as f64
                            } else {
                                0.0
                            };
                            item.discount = item.original_subtotal - item.final_subtotal;
                        }
                        applied_rules.push(AppliedRule {
                            rule_id: rule.id.clone(),
                            rule_name: rule.name.clone(),
                            discount_amount: cart_discount,
                        });
                    }
                }
            }
            _ => {}
        }
    }

    let original_total: f64 = processed.iter().map(|i| i.original_subtotal).sum();
    let final_total: f64 = processed.iter().map(|i| i.final_subtotal).sum();
    let total_discount = original_total - final_total;

    CheckoutResult {
        items: processed,
        original_total: round2(original_total),
        final_total: round2(final_total),
        total_discount: round2(total_discount),
        applied_rules,
    }
}

fn evaluate_item_conditions(item: &ProcessedItem, conditions: &[RuleCondition], all_items: &[CartItem]) -> bool {
    for cond in conditions {
        let matches = match cond.field.as_str() {
            "quantity" => {
                let val = cond.value.as_i64().unwrap_or(0) as i32;
                match cond.operator.as_str() {
                    "gte" => item.quantity >= val,
                    "lte" => item.quantity <= val,
                    "eq" => item.quantity == val,
                    "gt" => item.quantity > val,
                    "lt" => item.quantity < val,
                    _ => false,
                }
            }
            "brand" => {
                let val = cond.value.as_str().unwrap_or("");
                match cond.operator.as_str() {
                    "eq" => item.brand == val,
                    "neq" => item.brand != val,
                    "contains" => item.brand.contains(val),
                    _ => false,
                }
            }
            "price" => {
                let val = cond.value.as_f64().unwrap_or(0.0);
                match cond.operator.as_str() {
                    "gte" => item.original_price >= val,
                    "lte" => item.original_price <= val,
                    "gt" => item.original_price > val,
                    "lt" => item.original_price < val,
                    _ => false,
                }
            }
            "product_id" => {
                let val = cond.value.as_str().unwrap_or("");
                match cond.operator.as_str() {
                    "eq" => item.product_id == val,
                    "neq" => item.product_id != val,
                    _ => false,
                }
            }
            "total_quantity" => {
                let total_qty: i32 = all_items.iter().map(|i| i.quantity).sum();
                let val = cond.value.as_i64().unwrap_or(0) as i32;
                match cond.operator.as_str() {
                    "gte" => total_qty >= val,
                    "lte" => total_qty <= val,
                    "eq" => total_qty == val,
                    "gt" => total_qty > val,
                    "lt" => total_qty < val,
                    _ => false,
                }
            }
            _ => false,
        };
        if !matches {
            return false;
        }
    }
    true
}

fn evaluate_cart_conditions(conditions: &[RuleCondition], total_qty: i32, total_amount: f64) -> bool {
    for cond in conditions {
        let matches = match cond.field.as_str() {
            "total_quantity" => {
                let val = cond.value.as_i64().unwrap_or(0) as i32;
                match cond.operator.as_str() {
                    "gte" => total_qty >= val,
                    "lte" => total_qty <= val,
                    "eq" => total_qty == val,
                    _ => false,
                }
            }
            "total_amount" => {
                let val = cond.value.as_f64().unwrap_or(0.0);
                match cond.operator.as_str() {
                    "gte" => total_amount >= val,
                    "lte" => total_amount <= val,
                    _ => false,
                }
            }
            _ => false,
        };
        if !matches {
            return false;
        }
    }
    true
}

fn apply_rule_action(action: &RuleAction, current_price: f64, quantity: i32) -> f64 {
    match action.action_type.as_str() {
        "fixed_price" => {
            // Set price to action.value, discount is the difference
            (current_price - action.value).max(0.0)
        }
        "percent_discount" => {
            current_price * action.value / 100.0
        }
        "amount_discount" => {
            action.value.min(current_price)
        }
        "bogo" => {
            // Buy one get one free: for every 2 items, 1 is free
            let free_count = quantity / 2;
            if free_count > 0 {
                current_price * free_count as f64 / quantity as f64
            } else {
                0.0
            }
        }
        _ => 0.0,
    }
}

fn round2(v: f64) -> f64 {
    (v * 100.0).round() / 100.0
}
