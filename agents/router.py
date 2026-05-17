"""Top-level router: sends user queries to the right specialist agent."""

from __future__ import annotations

from typing import Any, Literal

from langchain_core.messages import SystemMessage
from pydantic import BaseModel, Field

from agents.common import latest_user_message
from llm import get_chat_model
from state import AgentState

AgentName = Literal[
    "order_status_agent",
    "order_modify_agent",
    "general",
]
ModifyAction = Literal["cancel_order", "change_address"]


class RouterDecision(BaseModel):
    """Route the user message to a specialist agent."""

    agent: AgentName = Field(
        description=(
            "order_status_agent: check status, track, or find orders. "
            "order_modify_agent: cancel an order or change delivery address. "
            "general: greeting, unclear intent, or still need more information to route."
        )
    )
    modify_action: ModifyAction | None = Field(
        default=None,
        description="Required when agent is order_modify_agent.",
    )
    user_id: str | None = Field(default=None, description="Business user id extracted verbatim from the conversation")
    order_id: str | None = Field(default=None, description="Order id extracted verbatim from the conversation")
    email: str | None = None
    product_name: str | None = None
    order_date: str | None = Field(default=None, description="YYYY-MM-DD")
    new_address: str | None = Field(
        default=None,
        description="Full delivery address when changing address",
    )
    cancellation_reason: str | None = None


def route_user_query(state: AgentState) -> dict[str, Any]:
    """Classify the message and pick order_status_agent vs order_modify_agent."""
    messages = list(state.get("messages") or [])
    if not messages or not latest_user_message(state).strip():
        return _clarify_state()

    llm = get_chat_model().with_structured_output(RouterDecision)
    decision = llm.invoke(
        [
            SystemMessage(
                content=(
                    "You are the router for an order support system. "
                    "Analyze the FULL conversation history to extract identifiers and determine intent.\n\n"
                    "Route to:\n"
                    "- order_status_agent: check status, track shipment, or find orders\n"
                    "- order_modify_agent: cancel an order or change delivery address (pre-shipment only)\n"
                    "- general: greeting, unclear intent, or still missing information needed to act\n\n"
                    "Extract from ANYWHERE in the conversation: "
                    "user_id (usr_*), order_id (ORD-*), email, product_name, order_date, "
                    "new_address, cancellation_reason.\n"
                    "Set modify_action to cancel_order or change_address when routing to order_modify_agent."
                )
            ),
        ]
        + messages
    )

    filters = {
        "user_id": decision.user_id,
        "order_id": decision.order_id,
        "email": decision.email,
        "product_name": decision.product_name,
        "order_date": decision.order_date,
        "new_address": decision.new_address,
        "cancellation_reason": decision.cancellation_reason,
    }

    agent = decision.agent
    modify_action = decision.modify_action

    if agent == "order_modify_agent":
        if not modify_action:
            return _clarify_state()
        if not decision.order_id:
            return _clarify_state()
        if modify_action == "change_address" and not decision.new_address:
            return _clarify_state()

    return {
        "active_agent": agent,
        "modify_action": modify_action,
        "search_filters": filters,
        "orders": [],
        "line_items": [],
        "error": None,
        "operation_result": None,
        "tool_rounds": 0,
    }


def _clarify_state() -> dict[str, Any]:
    return {
        "active_agent": "general",
        "modify_action": None,
        "search_filters": {},
        "orders": [],
        "line_items": [],
        "error": None,
        "operation_result": None,
        "tool_rounds": 0,
    }


def route_to_agent(state: AgentState) -> str:
    """Conditional edge after router."""
    agent = state.get("active_agent") or "general"
    if agent == "order_status_agent":
        return "order_status_agent"
    if agent == "order_modify_agent":
        return "order_modify_agent"
    return "handle_general"  # covers "general" and any unrecognised value
