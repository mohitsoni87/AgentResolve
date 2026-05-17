"""Interactive CLI for the order assistant graph."""

from __future__ import annotations

from dotenv import load_dotenv
from langchain_core.messages import HumanMessage

from graph import graph


def main() -> None:
    load_dotenv()
    print("AgentResolve — order status & cancellation assistant")
    print("Type 'quit' to exit.\n")

    state = {"messages": []}

    while True:
        user_input = input("You: ").strip()
        if not user_input:
            continue
        if user_input.lower() in {"quit", "exit", "q"}:
            break

        state["messages"] = state.get("messages", []) + [HumanMessage(content=user_input)]
        state = graph.invoke(state)
        reply = state["messages"][-1]
        print(f"\nAssistant: {reply.content}\n")


if __name__ == "__main__":
    main()
