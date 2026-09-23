"""Voice NLU endpoint (P2).

Complex voice queries route here: transcript -> intent + spoken reply.
Simple commands are handled on-device (sherpa-onnx) in the app; the same command intents are
recognised here too so an online client gets a consistent answer. Anything else is treated as a
question and answered from the manuals via RAG.
"""

import re

from fastapi import APIRouter
from pydantic import BaseModel

from app.core.rag import answer

router = APIRouter(prefix="/voice", tags=["voice"])

# Checked in order; first match wins. English plus common Hindi/Hinglish phrasings.
# TODO(P2): replace with LLM intent classification for other Indian languages.
COMMANDS: list[tuple[str, re.Pattern[str], str]] = [
    ("sos", re.compile(r"\b(sos|emergency|help me|injured|bachao|madad)\b", re.I),
     "Sending SOS now. Stay where you are if it is safe. Help is being alerted."),
    ("log_incident", re.compile(r"\b(log|report|record)\b.*\b(incident|near miss|issue|problem)\b"
                                r"|\bnear miss\b", re.I),
     "Okay, recording an incident. Describe what happened after the beep."),
    ("next_task", re.compile(r"\b(next task|what'?s next|agla (kaam|task))\b", re.I),
     "Opening your next task."),
    ("start_checklist", re.compile(r"\b(start|begin|open)\b.*\b(checklist|inspection|walkaround)\b",
                                   re.I),
     "Starting the pre-start checklist."),
]


class NluRequest(BaseModel):
    transcript: str
    language: str = "en"
    machine_model: str | None = None


class NluResponse(BaseModel):
    intent: str
    reply: str


@router.post("/nlu", response_model=NluResponse)
def nlu(req: NluRequest) -> NluResponse:
    for intent, pattern, reply in COMMANDS:
        if pattern.search(req.transcript):
            return NluResponse(intent=intent, reply=reply)

    result = answer(req.transcript, machine_type=req.machine_model, language=req.language)
    return NluResponse(intent="question" if result.grounded else "unknown", reply=result.answer)
