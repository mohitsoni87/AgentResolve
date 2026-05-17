"""Response schemas — defines exactly what fields are returned to the user."""

from __future__ import annotations

from pydantic import BaseModel, Field


class OrderSummary(BaseModel):
    order_id: str
    status: str | None = None
    total_amount: float | None = None
    placed_at: str | None = None
    shipping_address: str | None = None
    cancellation_reason: str | None = None


class LineItemSummary(BaseModel):
    product_name: str
    quantity: int | None = None
    unit_price: float | None = None
    line_total: float | None = None
    fulfillment_status: str | None = None


class ShipmentSummary(BaseModel):
    carrier: str | None = None
    tracking_number: str | None = None
    shipment_status: str | None = None
    estimated_delivery: str | None = None


class AgentResponse(BaseModel):
    """Structured response — only safe fields, no PII."""

    message: str = Field(
        description=(
            "The complete, fully formatted response to show the user. "
            "Must include all relevant order details, statuses, line items, "
            "and tracking info inline — do not refer to other fields."
        )
    )
    orders: list[OrderSummary] = []
    line_items: list[LineItemSummary] = []
    shipments: list[ShipmentSummary] = []
