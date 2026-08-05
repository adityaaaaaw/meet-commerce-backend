/**
 * Inventory Repository — Data Access Layer for Inventory Lots, Ledger & FEFO Queries
 * Source of truth: Blueprint §06.5, Phase 6
 *
 * @module modules/inventory/inventory.repository
 */

import { query } from '../../config/database.js'

export class InventoryRepository {
  // ─── LOTS ───────────────────────────────────────────
  async findLotByBatch(warehouseId, productId, batchNumber) {
    const { rows } = await query(
      `SELECT * FROM inventory_lots
        WHERE warehouse_id = $1 AND product_id = $2 AND batch_number = $3
        LIMIT 1`,
      [warehouseId, productId, batchNumber]
    )
    return rows[0] || null
  }

  async findLotById(lotId) {
    const { rows } = await query(`SELECT * FROM inventory_lots WHERE id = $1 LIMIT 1`, [lotId])
    return rows[0] || null
  }

  async createLot({ warehouse_id, product_id, batch_id = null, batch_number, expiry_date, quantity }) {
    const { rows } = await query(
      `INSERT INTO inventory_lots (warehouse_id, product_id, batch_id, batch_number, expiry_date, quantity_on_hand)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (warehouse_id, product_id, batch_number)
       DO UPDATE SET quantity_on_hand = inventory_lots.quantity_on_hand + EXCLUDED.quantity_on_hand, updated_at = NOW()
       RETURNING *`,
      [warehouse_id, product_id, batch_id, batch_number, expiry_date, quantity]
    )
    return rows[0]
  }

  /**
   * Find available non-expired inventory lots ordered by FEFO (First Expiry First Out)
   * @param {string} warehouseId
   * @param {string} productId
   * @returns {Promise<Array>}
   */
  async findAvailableLotsFefo(warehouseId, productId) {
    const { rows } = await query(
      `SELECT * FROM inventory_lots
        WHERE warehouse_id = $1
          AND product_id = $2
          AND expiry_date > CURRENT_DATE
          AND (quantity_on_hand - quantity_reserved) > 0
        ORDER BY expiry_date ASC, created_at ASC`,
      [warehouseId, productId]
    )
    return rows
  }

  async updateLotQuantities(lotId, onHandChange, reservedChange) {
    const { rows } = await query(
      `UPDATE inventory_lots
          SET quantity_on_hand = quantity_on_hand + $2,
              quantity_reserved = quantity_reserved + $3
        WHERE id = $1
        RETURNING *`,
      [lotId, onHandChange, reservedChange]
    )
    return rows[0]
  }

  // ─── LEDGER (APPEND-ONLY) ───────────────────────────
  async writeLedgerEntry({ lot_id, warehouse_id, product_id, movement_type, quantity_change, balance_after, reference_type = null, reference_id = null, actor_id = null }) {
    const { rows } = await query(
      `INSERT INTO stock_ledger_entries (lot_id, warehouse_id, product_id, movement_type, quantity_change, balance_after, reference_type, reference_id, actor_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [lot_id, warehouse_id, product_id, movement_type, quantity_change, balance_after, reference_type, reference_id, actor_id]
    )
    return rows[0]
  }

  async getLedgerEntries(warehouseId, productId = null) {
    const conditions = ['warehouse_id = $1']
    const params = [warehouseId]

    if (productId) {
      conditions.push('product_id = $2')
      params.push(productId)
    }

    const { rows } = await query(
      `SELECT e.*, l.batch_number, p.name AS product_name
         FROM stock_ledger_entries e
         JOIN inventory_lots l ON l.id = e.lot_id
         JOIN products p ON p.id = e.product_id
        WHERE ${conditions.join(' AND ')}
        ORDER BY e.created_at DESC`,
      params
    )
    return rows
  }

  // ─── RESERVATIONS ───────────────────────────────────
  async findReservationsByKey(reservationKey) {
    const { rows } = await query(
      `SELECT * FROM stock_reservations WHERE reservation_key = $1 AND status = 'RESERVED'`,
      [reservationKey]
    )
    return rows
  }

  async createReservation({ reservation_key, warehouse_id, product_id, lot_id, quantity_reserved, expires_at }) {
    const { rows } = await query(
      `INSERT INTO stock_reservations (reservation_key, warehouse_id, product_id, lot_id, quantity_reserved, status, expires_at)
       VALUES ($1, $2, $3, $4, $5, 'RESERVED', $6)
       RETURNING *`,
      [reservation_key, warehouse_id, product_id, lot_id, quantity_reserved, expires_at]
    )
    return rows[0]
  }

  async updateReservationStatus(reservationId, status) {
    const { rows } = await query(
      `UPDATE stock_reservations SET status = $2 WHERE id = $1 RETURNING *`,
      [reservationId, status]
    )
    return rows[0]
  }

  // ─── ADJUSTMENTS ────────────────────────────────────
  async createAdjustment(lotId, quantityChange, reason, actorId = null) {
    const { rows } = await query(
      `INSERT INTO stock_adjustments (lot_id, quantity_change, reason, actor_id)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [lotId, quantityChange, reason, actorId]
    )
    return rows[0]
  }

  async listLots(warehouseId, productId = null) {
    const conditions = ['warehouse_id = $1']
    const params = [warehouseId]

    if (productId) {
      conditions.push('product_id = $2')
      params.push(productId)
    }

    const { rows } = await query(
      `SELECT l.*, p.name AS product_name
         FROM inventory_lots l
         JOIN products p ON p.id = l.product_id
        WHERE ${conditions.join(' AND ')}
        ORDER BY l.expiry_date ASC`,
      params
    )
    return rows
  }
}
