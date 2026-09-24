# Sample manual corpus (RAG)

**These are sample pages written by the team for the hackathon demo. They are not official
Caterpillar documentation.** Values such as service intervals, temperatures and pressures are
realistic placeholders chosen to match the synthetic data (schema v1.0), not manufacturer specs.
Always follow the real Operation & Maintenance Manual (OMM) for a machine.

`/rag/query` and `/voice/nlu` answer from these files. Each file starts with a small header:

```
---
title: Human-readable title
machine_types: all | comma-separated MachineType values (schema v1.0 enums)
fault_codes: optional, comma-separated FaultCode values this page covers
---
```

Every `##` heading becomes one searchable chunk, and its source is cited as `file.md § Heading`.
To add a page, drop a new `.md` file here with the same header (this `README.md` is skipped).
- **When the index is built:** on the first `/rag/query` or `/voice/nlu` request, then cached for
  the life of the process. Restart the backend to pick up new pages.
- **Retriever:** in-memory Qdrant with multilingual sentence-transformers embeddings, or TF-IDF when
  those packages aren't installed (e.g. the Docker image).
