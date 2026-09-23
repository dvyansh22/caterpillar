"""Voice NLU endpoint (P2).

Complex voice queries route here: transcript -> intent/answer (LLM, optionally via RAG).
Simple commands are handled on-device (sherpa-onnx) in the app.
"""

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/voice", tags=["voice"])


class NluRequest(BaseModel):
    transcript: str
    language: str = "en"
    machine_model: str | None = None


class NluResponse(BaseModel):
    intent: str
    reply: str


@router.post("/nlu", response_model=NluResponse)
def nlu(req: NluRequest) -> NluResponse:
    # TODO(P2): LLM intent classification + response (reuse RAG for repair questions).
    return NluResponse(intent="unknown", reply="(stub) Voice response will appear here.")
