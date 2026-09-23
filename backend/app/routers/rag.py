"""RAG endpoint — repair-manual Q&A (P2).

Stub establishes the contract. Real impl: embed query -> retrieve from vector DB -> LLM answer.
"""

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/rag", tags=["rag"])


class RagRequest(BaseModel):
    question: str
    machine_model: str | None = None
    fault_code: str | None = None
    language: str = "en"


class RagResponse(BaseModel):
    answer: str
    sources: list[str] = []


@router.post("/query", response_model=RagResponse)
def query(req: RagRequest) -> RagResponse:
    # TODO(P2): sentence-transformers embed -> Qdrant retrieve -> Gemini answer.
    return RagResponse(answer="(stub) Repair guidance will appear here.", sources=[])
