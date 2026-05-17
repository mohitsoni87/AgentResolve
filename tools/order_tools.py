"""LangChain tools wrapping Postgres order operations."""

from __future__ import annotations

import json
from datetime import date
from typing import Any

from langchain_core.tools import tool

import db

# Fields stripped before the LLM sees tool results
_ORDER_STRIP = {"user_id", "customer_phone"}
_LINE_ITEM_STRIP = {"user_id", "email"}


def _json(data: Any) -> str:
    return json.dumps(data, indent=2, default=str)


def _safe_orders(orders: list[dict]) -> list[dict]:
    return [{k: v for k, v in o.items() if k not in _ORDER_STRIP} for o in orders]


def _safe_line_items(items: list[dict]) -> list[dict]:
    return [{k: v for k, v in i.items() if k not in _LINE_ITEM_STRIP} for i in items]


@tool
def find_orders(
    user_id: str | None = None,
    order_id: str | None = None,
    email: str | None = None,
    product_name: str | None = None,
    order_date: str | None = None,
    status: str | None = None,
) -> str:
    """Search existing orders in the database.

    Provide at least one filter. user_id is the user UUID.
    order_id format: ORD-2026-0001. order_date format: YYYY-MM-DD.
    """
    if not any([user_id, order_id, email, product_name, order_date, status]):
        return _json({"success": False, "message": "Provide at least one search filter."})

    parsed_date: date | None = None
    if order_date:
        parsed_date = date.fromisoformat(order_date)

    try:
        orders, line_items = db.search_orders(
            user_id=user_id,
            order_id=order_id,
            email=email,
            product_name=product_name,
            order_date=parsed_date,
            status=status,
        )
    except Exception as exc:  # noqa: BLE001
        return _json({"success": False, "message": str(exc)})

    if not orders:
        return _json({"success": False, "message": "No orders matched your search."})

    return _json({
        "success": True,
        "message": f"Found {len(orders)} order(s).",
        "orders": _safe_orders(orders),
        "line_items": _safe_line_items(line_items),
    })


@tool
def cancel_order(
    order_id: str,
    user_id: str | None = None,
    cancellation_reason: str | None = None,
) -> str:
    """Cancel an order that has not shipped yet (pending, confirmed, or processing).

    order_id is required (e.g. ORD-2026-0004). Optionally pass user_id to verify ownership.
    """
    try:
        result = db.cancel_order(
            order_id=order_id,
            user_id=user_id,
            reason=cancellation_reason or "Cancelled by customer via assistant",
        )
    except Exception as exc:  # noqa: BLE001
        return _json({"success": False, "message": str(exc)})

    return _json(result)


@tool
def update_delivery_address(
    order_id: str,
    new_address: str,
    user_id: str | None = None,
) -> str:
    """Update delivery address before the order ships.

    Only allowed when status is pending, confirmed, or processing.
    """
    try:
        result = db.update_order_address(
            order_id=order_id,
            new_address=new_address,
            user_id=user_id,
        )
    except Exception as exc:  # noqa: BLE001
        return _json({"success": False, "message": str(exc)})

    return _json(result)


STATUS_TOOLS = [find_orders]
MODIFY_TOOLS = [find_orders, cancel_order, update_delivery_address]
