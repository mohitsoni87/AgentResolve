"""Specialist agent: order lookup and status (tool-calling)."""

from __future__ import annotations

from langchain.agents import create_agent

from agents.common import CleanResponseMiddleware
from llm import get_chat_model
from schemas import AgentResponse
from tools import STATUS_TOOLS

STATUS_SYSTEM = """You are the order status specialist.

Your job:
- Find orders using find_orders (by user_id, order_id, email, product_name, order_date, or status)
- Explain status, line items, delivery address, and shipment tracking clearly

You cannot cancel orders or change addresses — only look up information."""


def build_order_status_agent():
    return create_agent(
        model=get_chat_model(),
        tools=STATUS_TOOLS,
        system_prompt=STATUS_SYSTEM,
        response_format=AgentResponse,
        middleware=[CleanResponseMiddleware()],
    )
