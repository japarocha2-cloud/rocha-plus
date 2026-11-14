"""Rocha+ LAB: simulated model-routing fallback (no network, no keys, no cost).

Every deployment uses LiteLLM ``mock_response``, so no provider is called.
The primary deployment is forced to fail with a simulated rate limit (429)
to prove that the router falls back to the next tier.

Run (inside a venv with ``pip install litellm``):
    LITELLM_LOCAL_MODEL_COST_MAP=True python3 tools/lab/model_router_sim.py
"""
import os

os.environ.setdefault("LITELLM_LOCAL_MODEL_COST_MAP", "True")

import litellm  # noqa: E402
from litellm import Router  # noqa: E402

# Placeholder keys only: mock_response short-circuits before any HTTP request.
SIM_KEY = "sim-not-a-real-key"

MODEL_LIST = [
    {
        "model_name": "rocha-primary",
        "litellm_params": {
            "model": "anthropic/claude-sim-primary",
            "api_key": SIM_KEY,
            "mock_response": "litellm.RateLimitError",
        },
    },
    {
        "model_name": "rocha-fallback-a",
        "litellm_params": {
            "model": "openai/gpt-sim-fallback",
            "api_key": SIM_KEY,
            "mock_response": "SIMULADO: resposta do fallback A",
        },
    },
    {
        "model_name": "rocha-fallback-b",
        "litellm_params": {
            "model": "gemini/gemini-sim-fallback",
            "api_key": SIM_KEY,
            "mock_response": "SIMULADO: resposta do fallback B",
        },
    },
]


def build_router() -> Router:
    return Router(
        model_list=MODEL_LIST,
        fallbacks=[{"rocha-primary": ["rocha-fallback-a", "rocha-fallback-b"]}],
        num_retries=0,
    )


def run() -> str:
    litellm.telemetry = False
    response = build_router().completion(
        model="rocha-primary",
        messages=[{"role": "user", "content": "ping LAB"}],
    )
    return response.choices[0].message.content


if __name__ == "__main__":
    print(run())
