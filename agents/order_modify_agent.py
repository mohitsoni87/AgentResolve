"""Specialist agent: cancel orders or update address (tool-calling)."""

from __future__ import annotations

from langchain.agents import create_agent

from llm import get_chat_model
from tools import MODIFY_TOOLS

MODIFY_SYSTEM = """You are the order modification specialist.

Your job:
- Use find_orders first if you need to verify an order exists or check its status
- cancel_order: cancel orders that are pending, confirmed, or processing (not shipped)
- update_delivery_address: change address only before the order ships

Rules:
- Never include internal UUIDs, phone numbers, or raw email addresses in your reply
- Respond in plain natural language only — no JSON, no raw dicts
- Always confirm the outcome to the customer. If a modification is rejected, explain why."""


def build_order_modify_agent():
    return create_agent(
        model=get_chat_model(),
        tools=MODIFY_TOOLS,
        system_prompt=MODIFY_SYSTEM,
    )
