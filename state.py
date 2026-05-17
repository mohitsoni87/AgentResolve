"""LangGraph state for the multi-agent order assistant."""

from __future__ import annotations

from typing import Any

from langgraph.graph import MessagesState

from schemas import AgentResponse


class AgentState(MessagesState):
    """Shared state across router and specialist agents."""

    active_agent: str | None
    modify_action: str | None
    search_filters: dict[str, Any] | None
    orders: list[dict[str, Any]]
    line_items: list[dict[str, Any]]
    operation_result: dict[str, Any] | None
    error: str | None
    tool_rounds: int
    structured_response: AgentResponse | None
