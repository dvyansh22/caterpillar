"""RAG endpoint — repair-manual Q&A (P2).

Embed query -> retrieve manual sections (Qdrant) -> Gemini answer with citations. See app.core.rag.
"""

from fastapi import APIRouter
from pydantic import BaseModel

from app.core.rag import answer

router = APIRouter(prefix="/rag", tags=["rag"])


class RagRequest(BaseModel):
    question: str
    machine_model: str | None = None  # a schema MachineType, e.g. "Excavator" or "Haul Truck"
    fault_code: str | None = None
    language: str = "en"


class RagResponse(BaseModel):
    answer: str
    sources: list[str] = []


@router.post("/query", response_model=RagResponse)
def query(req: RagRequest) -> RagResponse:
    result = answer(req.question, machine_type=req.machine_model, fault_code=req.fault_code,
                    language=req.language)
    return RagResponse(answer=result.answer, sources=result.sources)
