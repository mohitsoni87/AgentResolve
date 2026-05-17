"""Shared helpers for specialist agents."""

from __future__ import annotations

from langchain_core.messages import HumanMessage

from state import AgentState


def latest_user_message(state: AgentState) -> str:
    for message in reversed(state["messages"]):
        if isinstance(message, HumanMessage):
            return str(message.content)
    return ""
