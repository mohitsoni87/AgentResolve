"""Response schemas — defines exactly what fields are returned to the user."""

from __future__ import annotations

from pydantic import BaseModel, Field


class OrderSummary(BaseModel):
    order_id: str
    status: str
    total_amount: float
    placed_at: str
    shipping_address: str | None = None
    cancellation_reason: str | None = None


class LineItemSummary(BaseModel):
    product_name: str
    quantity: int
    unit_price: float
    line_total: float
    fulfillment_status: str


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
