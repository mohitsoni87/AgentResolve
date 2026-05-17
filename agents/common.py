"""Shared helpers for specialist agents."""

from __future__ import annotations

from typing import Any

from langchain.agents.middleware.types import AgentMiddleware
from langchain_core.messages import AIMessage, HumanMessage

from state import AgentState


def latest_user_message(state: AgentState) -> str:
    for message in reversed(state["messages"]):
        if isinstance(message, HumanMessage):
            return str(message.content)
    return ""


class CleanResponseMiddleware(AgentMiddleware):
    """Replaces the agent's raw JSON message with the natural language message field."""

    def after_agent(self, state: Any, runtime: Any) -> dict[str, Any] | None:
        resp = state.get("structured_response")
        if not resp:
            return None

        last_ai = next(
            (m for m in reversed(state["messages"]) if isinstance(m, AIMessage)),
            None,
        )
        if not last_ai:
            return None

        return {"messages": [AIMessage(id=last_ai.id, content=resp.message)]}
