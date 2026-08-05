/**
 * Admin Reports Repository — Read-Only Metrics & Summary Aggregations
 * Source of truth: Blueprint §06.10, Phase 11
 *
 * @module modules/reports/reports.repository
 */

import { query } from '../../config/database.js'

export class ReportsRepository {
  async getDashboardSummary() {
    const vendorsRes = await query(`SELECT * FROM v_vendor_summary`)
    const catalogueRes = await query(`SELECT * FROM v_catalogue_summary`)
    const procurementRes = await query(`SELECT * FROM v_procurement_summary`)
    const inventoryRes = await query(`SELECT * FROM v_inventory_summary`)
    const ordersRes = await query(`SELECT * FROM v_order_delivery_summary`)

    return {
      vendors: vendorsRes.rows[0] || {},
      catalogue: catalogueRes.rows[0] || {},
      procurement: procurementRes.rows[0] || {},
      inventory: inventoryRes.rows[0] || {},
      orders_deliveries: ordersRes.rows[0] || {},
    }
  }

  async getVendorMetrics() {
    const { rows } = await query(
      `SELECT v.id, v.business_name, v.status, COUNT(p.id) AS total_proposals
         FROM vendors v
         LEFT JOIN product_proposals p ON p.vendor_id = v.id
        GROUP BY v.id, v.business_name, v.status
        ORDER BY total_proposals DESC`
    )
    return rows
  }

  async getProcurementMetrics() {
    const { rows } = await query(
      `SELECT po.status, COUNT(*) AS count, COALESCE(SUM(po.total_cost), 0.00) AS total_value
         FROM procurement_orders po
        GROUP BY po.status`
    )
    return rows
  }

  async getInventoryMetrics() {
    const { rows } = await query(
      `SELECT w.name AS warehouse_name, COUNT(l.id) AS total_lots, COALESCE(SUM(l.quantity_on_hand), 0) AS total_on_hand
         FROM warehouses w
         LEFT JOIN inventory_lots l ON l.warehouse_id = w.id
        GROUP BY w.id, w.name`
    )
    return rows
  }

  async getOrderMetrics() {
    const { rows } = await query(
      `SELECT status, COUNT(*) AS count, COALESCE(SUM(total_payable), 0.00) AS total_amount
         FROM orders
        GROUP BY status`
    )
    return rows
  }

  async getSupportMetrics() {
    const { rows } = await query(
      `SELECT status, COUNT(*) AS count FROM support_tickets GROUP BY status`
    )
    return rows
  }

  async getRecallMetrics() {
    const { rows } = await query(
      `SELECT r.id, r.recall_number, r.title, r.status, COUNT(ri.id) AS affected_items
         FROM product_recalls r
         LEFT JOIN recall_items ri ON ri.recall_id = r.id
        GROUP BY r.id, r.recall_number, r.title, r.status`
    )
    return rows
  }
}
