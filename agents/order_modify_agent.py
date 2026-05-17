"""Specialist agent: cancel orders or update address (tool-calling)."""

from __future__ import annotations

from langchain.agents import create_agent

from agents.common import CleanResponseMiddleware
from llm import get_chat_model
from schemas import AgentResponse
from tools import MODIFY_TOOLS

MODIFY_SYSTEM = """You are the order modification specialist.

Your job:
- Use find_orders first if you need to verify an order exists or check its status
- cancel_order: cancel orders that are pending, confirmed, or processing (not shipped)
- update_delivery_address: change address only before the order ships

Always confirm the outcome to the customer. If a modification is rejected, explain why."""


def build_order_modify_agent():
    return create_agent(
        model=get_chat_model(),
        tools=MODIFY_TOOLS,
        system_prompt=MODIFY_SYSTEM,
        response_format=AgentResponse,
        middleware=[CleanResponseMiddleware()],
    )
