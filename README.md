# AgentResolve

A multi-agent order support system built with [LangGraph](https://github.com/langchain-ai/langgraph) and PostgreSQL. Customers can check order status, track shipments, cancel orders, and update delivery addresses through a conversational interface.

## Architecture

```
User → Router → order_status_agent  → END
               order_modify_agent   → END
               handle_general       → END
```

- **Router** — classifies intent and extracts identifiers (order ID, user ID, email) from the conversation
- **order_status_agent** — looks up orders, line items, and shipment tracking via a ReAct tool loop
- **order_modify_agent** — cancels orders or updates delivery addresses (pre-shipment only)
- **handle_general** — handles greetings and clarifying questions when intent or identifiers are missing
- **CleanResponseMiddleware** — runs after each specialist agent; replaces raw JSON with a natural language response, enforcing the `AgentResponse` schema as a privacy boundary (no PII leakage)

![Graph](graph.png)

## Stack

| Layer | Technology |
|---|---|
| Agent framework | LangGraph 1.2 + LangChain 1.3 |
| LLM | OpenAI GPT-4o-mini (or Ollama locally) |
| Database | PostgreSQL 16 |
| Python | 3.12 |
| Package manager | uv |

## Project Structure

```
AgentResolve/
├── agents/
│   ├── common.py            # CleanResponseMiddleware + shared helpers
│   ├── order_status_agent.py
│   ├── order_modify_agent.py
│   └── router.py
├── tools/
│   └── order_tools.py       # LangChain tools wrapping db.py
├── db/
│   ├── init.sql             # Schema: tables, indexes, views, triggers
│   ├── seed.sql             # Demo data (6 users, 12 orders)
│   └── migrations/
├── db.py                    # PostgreSQL access (search, cancel, update address)
├── schemas.py               # AgentResponse Pydantic schema (privacy boundary)
├── state.py                 # AgentState (LangGraph shared state)
├── graph.py                 # Graph assembly
├── llm.py                   # LLM factory (OpenAI / Ollama)
└── docker-compose.yml       # Postgres container
```

## Getting Started

### 1. Start PostgreSQL

```bash
docker-compose up -d
```

### 2. Install dependencies

```bash
uv sync
```

### 3. Configure environment

```bash
cp .env.example .env
# Add your OPENAI_API_KEY (or set OLLAMA_MODEL for local inference)
```

### 4. Seed demo data

```bash
./db/seed.sh
```

Loads 6 users and 12 orders across all statuses. Safe to re-run — truncates first.

### 5. Run the LangGraph server

```bash
uv run langgraph dev
```

Open the LangGraph Studio UI at `http://localhost:8123`.

## Database Schema

The `orders` schema contains:

- **users** — UUID primary key, email, name, phone
- **orders** — order header with status, amounts, shipping address
- **order_items** — line items linked to products
- **products** / **product_categories** — product catalog
- **shipments** — carrier, tracking number, delivery status
- **order_status_history** — full audit trail of status transitions

### Key design decisions

- Single UUID identity for users — no dual `user_id`/`id` ambiguity
- Direct table queries in `db.py` — no view dependencies
- `AgentResponse` schema controls exactly what fields reach the user (no internal UUIDs, no raw PII)

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql://agentresolve:agentresolve@localhost:5432/agentresolve` | Postgres connection string |
| `OPENAI_API_KEY` | — | Required for OpenAI models |
| `OPENAI_MODEL` | `gpt-4o-mini` | OpenAI model name |
| `OLLAMA_MODEL` | `llama3.2` | Ollama model (used if no OpenAI key) |
