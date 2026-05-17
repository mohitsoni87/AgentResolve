"""Multi-agent graph: router → order_status_agent | order_modify_agent."""

from __future__ import annotations

from langchain_core.messages import AIMessage, SystemMessage
from langgraph.graph import END, START, StateGraph

from agents import (
    build_order_modify_agent,
    build_order_status_agent,
    route_to_agent,
    route_user_query,
)
from llm import get_chat_model
from state import AgentState

GENERAL_SYSTEM = """You are a friendly order support assistant having a natural conversation.

To help the customer you need two things:
1. An identifier — an order ID, user ID, or email address (accept whatever the customer provides as-is)
2. Their intent — check order status, cancel an order, or change a delivery address

Read the full conversation above before responding.
- If this is a first message or greeting, respond warmly and ask how you can help.
- If you have an identifier but no clear intent, ask what they'd like to do with the order.
- If you have an intent but no identifier, ask for their order ID or email.
- If you have both, let them know you're pulling things up.
- Ask ONE question at a time. Never ask for something already provided.
- Never validate or correct the format of any identifier the customer provides.
- Be warm and natural — like a real support agent, not a checklist."""


def handle_general(state: AgentState) -> dict:
    llm = get_chat_model()
    messages = list(state.get("messages") or [])
    response = llm.invoke([SystemMessage(content=GENERAL_SYSTEM)] + messages)
    return {"messages": [AIMessage(content=str(response.content))]}


def build_graph():
    builder = StateGraph(AgentState)

    builder.add_node("router", route_user_query)
    builder.add_node("order_status_agent", build_order_status_agent())
    builder.add_node("order_modify_agent", build_order_modify_agent())
    builder.add_node("handle_general", handle_general)

    builder.add_edge(START, "router")
    builder.add_conditional_edges(
        "router",
        route_to_agent,
        {
            "order_status_agent": "order_status_agent",
            "order_modify_agent": "order_modify_agent",
            "handle_general": "handle_general",
        },
    )
    builder.add_edge("order_status_agent", END)
    builder.add_edge("order_modify_agent", END)
    builder.add_edge("handle_general", END)

    return builder.compile()


graph = build_graph()
