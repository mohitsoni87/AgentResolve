"""PostgreSQL access for existing orders (read + cancel)."""

from __future__ import annotations

import os
from datetime import date
from typing import Any

import psycopg
from psycopg.rows import dict_row

DEFAULT_DATABASE_URL = (
    "postgresql://agentresolve:agentresolve@localhost:5432/agentresolve"
)

MODIFIABLE_STATUSES = ("pending", "confirmed", "processing")
CANCELLABLE_STATUSES = MODIFIABLE_STATUSES


def get_connection() -> psycopg.Connection:
    url = os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL)
    return psycopg.connect(url, row_factory=dict_row)


def search_orders(
    *,
    user_id: str | None = None,
    order_id: str | None = None,
    email: str | None = None,
    product_name: str | None = None,
    order_date: date | str | None = None,
    status: str | None = None,
    limit: int = 20,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Search orders and return matching order headers + line items."""
    conditions = ["1=1"]
    params: dict[str, Any] = {"limit": limit}

    if user_id:
        conditions.append("o.user_id::text = %(user_id)s")
        params["user_id"] = user_id
    if order_id:
        conditions.append("o.order_id = %(order_id)s")
        params["order_id"] = order_id
    if email:
        conditions.append("u.email ILIKE %(email)s")
        params["email"] = email
    if status:
        conditions.append("o.status = %(status)s")
        params["status"] = status
    if order_date:
        conditions.append("o.order_date = %(order_date)s")
        params["order_date"] = order_date
    if product_name:
        conditions.append("p.name ILIKE %(product_name)s")
        params["product_name"] = f"%{product_name}%"

    where_clause = " AND ".join(conditions)
    join_line_items = (
        "LEFT JOIN orders.order_items oi ON oi.order_id = o.id"
        " LEFT JOIN orders.products p ON p.id = oi.product_id"
        if product_name
        else ""
    )

    orders_sql = f"""
        SELECT DISTINCT
            o.order_id,
            o.status,
            o.order_date,
            o.placed_at,
            o.currency,
            o.subtotal,
            o.tax_amount,
            o.shipping_amount,
            o.total_amount,
            o.shipping_address,
            o.customer_notes,
            o.cancelled_at,
            o.cancellation_reason,
            u.id AS user_id,
            u.email,
            u.full_name AS customer_name,
            u.phone AS customer_phone
        FROM orders.orders o
        JOIN orders.users u ON u.id = o.user_id
        {join_line_items}
        WHERE {where_clause}
        ORDER BY o.placed_at DESC
        LIMIT %(limit)s
    """

    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(orders_sql, params)
        orders = list(cur.fetchall())

        if not orders:
            return [], []

        order_ids = [row["order_id"] for row in orders]
        cur.execute(
            """
            SELECT
                o.order_id,
                o.status AS order_status,
                o.order_date,
                u.id AS user_id,
                u.email,
                p.sku,
                p.name AS product_name,
                oi.quantity,
                oi.unit_price,
                oi.line_total,
                oi.fulfillment_status
            FROM orders.order_items oi
            JOIN orders.orders o ON o.id = oi.order_id
            JOIN orders.users u ON u.id = o.user_id
            JOIN orders.products p ON p.id = oi.product_id
            WHERE o.order_id = ANY(%(order_ids)s)
            ORDER BY o.order_id, p.name
            """,
            {"order_ids": order_ids},
        )
        line_items = list(cur.fetchall())

        cur.execute(
            """
            SELECT
                o.order_id,
                s.carrier,
                s.tracking_number,
                s.status AS shipment_status,
                s.shipped_at,
                s.estimated_delivery,
                s.delivered_at
            FROM orders.shipments s
            JOIN orders.orders o ON o.id = s.order_id
            WHERE o.order_id = ANY(%(order_ids)s)
            """,
            {"order_ids": order_ids},
        )
        shipments = list(cur.fetchall())

    shipments_by_order: dict[str, list[dict[str, Any]]] = {}
    for shipment in shipments:
        shipments_by_order.setdefault(shipment["order_id"], []).append(shipment)

    for order in orders:
        order["shipments"] = shipments_by_order.get(order["order_id"], [])

    return orders, line_items


def cancel_order(
    *,
    order_id: str,
    user_id: str | None = None,
    reason: str = "Cancelled by customer via assistant",
) -> dict[str, Any]:
    """Cancel an order if it is still cancellable and optional user matches."""
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT o.id, o.order_id, o.status, u.id AS user_id
            FROM orders.orders o
            JOIN orders.users u ON u.id = o.user_id
            WHERE o.order_id = %(order_id)s
              AND (%(user_id)s IS NULL OR u.id::text = %(user_id)s)
            """,
            {"order_id": order_id, "user_id": user_id},
        )
        row = cur.fetchone()
        if not row:
            return {
                "success": False,
                "message": f"Order {order_id} was not found"
                + (f" for user {user_id}." if user_id else "."),
            }

        if row["status"] not in MODIFIABLE_STATUSES:
            return {
                "success": False,
                "message": (
                    f"Order {order_id} cannot be cancelled (current status: {row['status']}). "
                    "Only pending, confirmed, or processing orders can be cancelled."
                ),
            }

        cur.execute(
            """
            UPDATE orders.orders
            SET status = 'cancelled',
                cancelled_at = NOW(),
                cancellation_reason = %(reason)s,
                updated_at = NOW()
            WHERE id = %(id)s
            RETURNING order_id, status, cancelled_at, cancellation_reason
            """,
            {"id": row["id"], "reason": reason},
        )
        updated = cur.fetchone()

        cur.execute(
            """
            UPDATE orders.order_items
            SET fulfillment_status = 'cancelled'
            WHERE order_id = %(id)s
              AND fulfillment_status NOT IN ('shipped', 'delivered')
            """,
            {"id": row["id"]},
        )
        conn.commit()

    return {
        "success": True,
        "message": f"Order {order_id} has been cancelled.",
        "order": dict(updated),
        "user_id": str(row["user_id"]),
    }


def update_order_address(
    *,
    order_id: str,
    new_address: str,
    user_id: str | None = None,
) -> dict[str, Any]:
    """Update delivery address when the order has not shipped yet."""
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(
            """
            SELECT o.id, o.order_id, o.status, u.id AS user_id,
                   o.shipping_address AS current_address
            FROM orders.orders o
            JOIN orders.users u ON u.id = o.user_id
            WHERE o.order_id = %(order_id)s
              AND (%(user_id)s IS NULL OR u.id::text = %(user_id)s)
            """,
            {"order_id": order_id, "user_id": user_id},
        )
        row = cur.fetchone()
        if not row:
            return {
                "success": False,
                "message": f"Order {order_id} was not found"
                + (f" for user {user_id}." if user_id else "."),
            }

        if row["status"] not in MODIFIABLE_STATUSES:
            return {
                "success": False,
                "message": (
                    f"Order {order_id} address cannot be changed (status: {row['status']}). "
                    "Address changes are only allowed before the order ships."
                ),
            }

        cur.execute(
            """
            UPDATE orders.orders
            SET shipping_address = %(new_address)s,
                updated_at = NOW()
            WHERE id = %(id)s
            RETURNING order_id, status, shipping_address
            """,
            {"id": row["id"], "new_address": new_address},
        )
        updated = cur.fetchone()

        cur.execute(
            """
            INSERT INTO orders.order_status_history (order_id, from_status, to_status, note)
            VALUES (
                %(order_id)s,
                %(status)s,
                %(status)s,
                %(note)s
            )
            """,
            {
                "order_id": row["id"],
                "status": row["status"],
                "note": f"Delivery address updated (was: {row['current_address']})",
            },
        )
        conn.commit()

    return {
        "success": True,
        "message": f"Delivery address updated for order {order_id}.",
        "order": dict(updated),
        "user_id": str(row["user_id"]),
        "previous_address": row["current_address"],
    }
