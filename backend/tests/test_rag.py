"""/rag/query and /voice/nlu over the sample manuals.

Runs with the TF-IDF retriever and no Gemini key so CI needs no model download or secret.
"""

import pytest
from fastapi.testclient import TestClient

from app.core import rag
from app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def offline(monkeypatch):
    monkeypatch.setenv("RAG_RETRIEVER", "tfidf")
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    rag.get_retriever.cache_clear()
    yield
    rag.get_retriever.cache_clear()


def test_every_manual_page_is_chunked_with_a_source():
    chunks = rag.load_chunks()
    files = {c.source.split(" § ")[0] for c in chunks}
    assert len(files) == 10
    assert all(c.text.strip() and " § " in c.source for c in chunks)


def test_every_schema_fault_code_has_its_own_section():
    codes = {"HYD_PRESSURE_LOW", "ENGINE_OVERHEAT", "AIR_FILTER_RESTRICTED", "FUEL_FILTER_CLOGGED",
             "TRACK_TENSION", "BRAKE_WEAR", "TIRE_PRESSURE_LOW"}
    tagged = {code for c in rag.load_chunks() for code in c.fault_codes}
    assert codes <= tagged


@pytest.mark.parametrize(
    ("body", "expected_source"),
    [
        ({"question": "what does this fault mean", "fault_code": "TRACK_TENSION"},
         "fault-codes.md § TRACK_TENSION"),
        ({"question": "how fast can I drive on the haul road", "machine_model": "Haul Truck"},
         "haul-truck-operation.md § Haul road speed"),
        ({"question": "when should I change the hydraulic filter"},
         "hydraulic-system.md § Hydraulic filter and oil service"),
        ({"question": "do I need to wear the seatbelt while idling"},
         "safety-procedures.md § Seatbelt use"),
    ],
)
def test_query_cites_the_right_manual_section(body, expected_source):
    res = client.post("/rag/query", json=body)
    assert res.status_code == 200
    data = res.json()
    assert data["sources"][0].startswith(expected_source)
    assert data["answer"].startswith("From the manual")


def test_off_topic_question_is_not_answered():
    data = client.post("/rag/query", json={"question": "what is the capital of France"}).json()
    assert data["sources"] == []
    assert "couldn't find" in data["answer"]


@pytest.mark.parametrize(
    ("transcript", "intent"),
    [
        ("SOS I am injured", "sos"),
        ("bachao", "sos"),
        ("operator down, call an ambulance", "sos"),
        ("can you help me check the hydraulic oil level", "question"),
        ("log an incident please", "log_incident"),
        ("there was a near miss at the trench", "log_incident"),
        ("what's next", "next_task"),
        ("start the pre-start checklist", "start_checklist"),
        ("how do I check the hydraulic oil level", "question"),
        ("what is the capital of France", "unknown"),
    ],
)
def test_voice_intents(transcript, intent):
    res = client.post("/voice/nlu", json={"transcript": transcript})
    assert res.status_code == 200
    assert res.json()["intent"] == intent


@pytest.mark.parametrize("transcript", [
    "can you help me check the hydraulic oil level", "hydraulic mein madad chahiye",
    "where is the emergency stop button", "help me find the next task",
])
def test_asking_for_help_is_not_a_false_sos(transcript):
    assert client.post("/voice/nlu", json={"transcript": transcript}).json()["intent"] != "sos"


def test_voice_question_is_answered_from_the_manual():
    reply = client.post("/voice/nlu", json={"transcript": "how do I check the hydraulic oil level"}).json()
    assert "sight glass" in reply["reply"]


def test_llm_path_searches_the_english_rewrite_and_cites_sources(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(rag, "_english_query", lambda q: "how to check hydraulic oil level")
    monkeypatch.setattr(rag, "_generate", lambda q, hits, lang: f"answer in {lang} [1]")
    data = client.post("/rag/query", json={"question": "tel ka star kaise dekhu",
                                           "language": "hi"}).json()
    assert data["answer"] == "answer in hi [1]"
    assert "hydraulic-system.md § Checking the hydraulic oil level" in data["sources"]


def test_romanised_hindi_alone_is_not_matched_without_the_rewrite():
    data = client.post("/rag/query", json={"question": "tel ka star kaise dekhu"}).json()
    assert data["sources"] == []


def test_gemini_failure_falls_back_to_quoting_the_manual(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "bad-key")
    monkeypatch.setattr(rag, "_english_query", lambda q: q)

    def boom(*_):
        raise RuntimeError("quota exceeded")

    monkeypatch.setattr(rag, "_generate", boom)
    data = client.post("/rag/query", json={"question": "do I need to wear the seatbelt while idling"}).json()
    assert data["answer"].startswith("From the manual")


def test_empty_question_is_not_answered():
    data = client.post("/rag/query", json={"question": "   "}).json()
    assert data["sources"] == [] and "couldn't find" in data["answer"]


def test_missing_manuals_folder_answers_not_found_instead_of_crashing(tmp_path):
    retriever = rag.Retriever(rag.load_chunks(tmp_path))
    assert retriever.search("engine overheating") == []
