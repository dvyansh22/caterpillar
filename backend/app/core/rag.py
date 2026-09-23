"""Manual Q&A with retrieval-augmented generation (P2, FR-ML-4).

Pipeline: manual pages (ml/data/manuals/*.md) -> one chunk per `##` section -> embeddings in an
in-memory Qdrant collection -> top-k sections -> Gemini writes a short answer citing them.

Degrades gracefully so the endpoint always answers:
- no embedding model available (offline / CI) -> TF-IDF retrieval (RAG_RETRIEVER=tfidf forces it);
- no GEMINI_API_KEY -> extractive answer that quotes the best-matching manual section.
"""

from __future__ import annotations

import logging
import os
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import numpy as np

log = logging.getLogger(__name__)

MANUALS_DIR = Path(os.environ.get(
    "MANUALS_DIR", Path(__file__).resolve().parents[3] / "ml" / "data" / "manuals"))
EMBEDDING_MODEL = os.environ.get(
    "RAG_EMBEDDING_MODEL", "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
TOP_K = 4
FAULT_BOOST = 0.5  # the fault code's own section should win when the app sends a fault_code
WRONG_MACHINE_PENALTY = 0.2
MIN_SCORE = {"embeddings": 0.25, "tfidf": 0.05}

NOT_FOUND = ("I couldn't find this in the machine manuals. Stop if it is unsafe, and ask your "
             "supervisor or a technician.")


@dataclass
class Chunk:
    source: str  # "file.md § Heading" — what we cite
    heading: str
    text: str
    machine_types: set[str] = field(default_factory=lambda: {"all"})
    fault_codes: set[str] = field(default_factory=set)


@dataclass
class Hit:
    chunk: Chunk
    score: float


@dataclass
class Answer:
    answer: str
    sources: list[str]
    grounded: bool  # False when nothing relevant was found


def load_chunks(directory: Path = MANUALS_DIR) -> list[Chunk]:
    chunks: list[Chunk] = []
    for path in sorted(directory.glob("*.md")):
        if path.name.lower() == "readme.md":
            continue
        # Normalise line endings: git may check these files out with CRLF on Windows.
        meta, body = _front_matter(path.read_text(encoding="utf-8").replace("\r\n", "\n"))
        title = meta.get("title", path.stem)
        types = _csv(meta.get("machine_types", "all")) or {"all"}
        faults = _csv(meta.get("fault_codes", ""))
        for heading, text in _sections(body):
            section_faults = {f for f in faults if f in heading}
            chunks.append(Chunk(
                source=f"{path.name} § {heading}",
                heading=heading,
                text=f"{title} — {heading}\n{text}",
                machine_types=types,
                fault_codes=section_faults,
            ))
    return chunks


class Retriever:
    """Embeddings + Qdrant when available, TF-IDF otherwise. Same interface either way."""

    def __init__(self, chunks: list[Chunk], mode: str | None = None) -> None:
        self.chunks = chunks
        self.mode = mode or os.environ.get("RAG_RETRIEVER", "embeddings")
        if self.mode == "embeddings":
            try:
                self._init_embeddings()
                return
            except Exception as exc:  # model download blocked, offline, etc.
                log.warning("embedding retriever unavailable (%s); falling back to TF-IDF", exc)
                self.mode = "tfidf"
        self._init_tfidf()

    def _init_embeddings(self) -> None:
        from qdrant_client import QdrantClient
        from qdrant_client.models import Distance, PointStruct, VectorParams
        from sentence_transformers import SentenceTransformer

        self._model = SentenceTransformer(EMBEDDING_MODEL)
        vectors = self._model.encode([c.text for c in self.chunks], normalize_embeddings=True)
        self._qdrant = QdrantClient(":memory:")
        self._qdrant.create_collection(
            "manuals", vectors_config=VectorParams(size=vectors.shape[1], distance=Distance.COSINE))
        self._qdrant.upsert("manuals", points=[
            PointStruct(id=i, vector=v.tolist()) for i, v in enumerate(vectors)])

    def _init_tfidf(self) -> None:
        from sklearn.feature_extraction.text import TfidfVectorizer

        self._tfidf = TfidfVectorizer(stop_words="english", ngram_range=(1, 2), sublinear_tf=True)
        self._matrix = self._tfidf.fit_transform([c.text for c in self.chunks])

    def _scores(self, query: str) -> np.ndarray:
        if self.mode == "embeddings":
            vector = self._model.encode(query, normalize_embeddings=True)
            points = self._qdrant.query_points("manuals", query=vector.tolist(),
                                               limit=len(self.chunks)).points
            scores = np.zeros(len(self.chunks))
            for p in points:
                scores[p.id] = p.score
            return scores
        return (self._matrix @ self._tfidf.transform([query]).T).toarray().ravel()

    def search(self, query: str, machine_type: str | None = None, fault_code: str | None = None,
               k: int = TOP_K) -> list[Hit]:
        scores = self._scores(query)
        for i, chunk in enumerate(self.chunks):
            if fault_code and fault_code in chunk.fault_codes:
                scores[i] += FAULT_BOOST
            if machine_type and "all" not in chunk.machine_types and machine_type not in chunk.machine_types:
                scores[i] -= WRONG_MACHINE_PENALTY
        order = np.argsort(-scores)[:k]
        return [Hit(self.chunks[i], float(scores[i])) for i in order
                if scores[i] >= MIN_SCORE[self.mode]]


@lru_cache(maxsize=1)
def get_retriever() -> Retriever:
    return Retriever(load_chunks())


def answer(question: str, machine_type: str | None = None, fault_code: str | None = None,
           language: str = "en") -> Answer:
    query = " ".join(filter(None, [question, fault_code]))
    hits = get_retriever().search(query, machine_type=machine_type, fault_code=fault_code)
    if not hits:
        return Answer(NOT_FOUND, [], grounded=False)

    sources = list(dict.fromkeys(h.chunk.source for h in hits))
    if os.environ.get("GEMINI_API_KEY"):
        try:
            return Answer(_generate(question, hits, language), sources, grounded=True)
        except Exception as exc:  # quota, network, bad key — never fail the operator
            log.warning("Gemini call failed (%s); returning extractive answer", exc)
    return Answer(_extractive(hits[0]), sources[:1], grounded=True)


def _generate(question: str, hits: list[Hit], language: str) -> str:
    import google.generativeai as genai

    genai.configure(api_key=os.environ["GEMINI_API_KEY"])
    excerpts = "\n\n".join(f"[{i + 1}] ({h.chunk.source})\n{h.chunk.text}" for i, h in enumerate(hits))
    prompt = (
        "You are the voice assistant for a heavy-equipment operator in the cab. Answer ONLY from "
        "the manual excerpts below. If they do not answer the question, say so and tell the "
        "operator to contact their supervisor or a technician. Put safety first. Reply in at most "
        "5 short numbered steps or 3 sentences, plain words, no markdown headings. Cite excerpts "
        f"like [1]. Reply in this language: {language}.\n\n"
        f"Manual excerpts:\n{excerpts}\n\nOperator's question: {question}"
    )
    response = genai.GenerativeModel(GEMINI_MODEL).generate_content(prompt)
    return response.text.strip()


def _extractive(hit: Hit, limit: int = 700) -> str:
    body = hit.chunk.text.split("\n", 1)[-1].strip()
    body = re.sub(r"\*\*(.+?)\*\*", r"\1", body)
    body = re.sub(r"\n(?![-\d])", " ", body)  # re-join wrapped lines; keep list items
    if len(body) > limit:
        body = body[:limit].rsplit(" ", 1)[0] + " …"
    return f"From the manual ({hit.chunk.heading}): {body}"


def _front_matter(text: str) -> tuple[dict[str, str], str]:
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        return {}, text
    meta = dict(line.split(":", 1) for line in match.group(1).splitlines() if ":" in line)
    return {k.strip(): v.strip() for k, v in meta.items()}, text[match.end():]


def _sections(body: str) -> list[tuple[str, str]]:
    parts = re.split(r"^## +(.+)$", body, flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip()) for i in range(1, len(parts) - 1, 2)
            if parts[i + 1].strip()]


def _csv(value: str) -> set[str]:
    return {v.strip() for v in value.split(",") if v.strip()}
