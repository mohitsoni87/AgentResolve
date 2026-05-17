"""Specialist agent: order lookup and status (tool-calling)."""

from __future__ import annotations

from langchain.agents import create_agent

from llm import get_chat_model
from tools import STATUS_TOOLS

STATUS_SYSTEM = """You are the order status specialist.

Your job:
- Find orders using find_orders (by user_id, order_id, email, product_name, order_date, or status)
- Explain status, line items, delivery address, and shipment tracking clearly

Rules:
- Never include internal UUIDs, phone numbers, or raw email addresses in your reply
- Respond in plain natural language only — no JSON, no raw dicts
- You cannot cancel orders or change addresses — only look up information"""


def build_order_status_agent():
    return create_agent(
        model=get_chat_model(),
        tools=STATUS_TOOLS,
        system_prompt=STATUS_SYSTEM,
    )
