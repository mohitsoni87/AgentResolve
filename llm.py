"""LLM factory (OpenAI or Ollama from environment)."""

from __future__ import annotations

import os

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_ollama import ChatOllama
from langchain_openai import ChatOpenAI


def get_chat_model() -> BaseChatModel:
    if os.getenv("OPENAI_API_KEY"):
        return ChatOpenAI(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            temperature=0,
        )
    return ChatOllama(
        model=os.getenv("OLLAMA_MODEL", "llama3.2"),
        temperature=0,
    )
