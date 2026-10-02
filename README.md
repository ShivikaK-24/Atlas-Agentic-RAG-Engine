> **Team academic project (3 members).** I led the design and build, directing the **Claude Code** agent to implement the system end-to-end. The document corpus is **synthetic** — authored for this project, no real or confidential data.

<div align="center">

# Atlas — Multi-Department Agentic RAG Engine

**Every policy, contract and specification your organisation owns — answerable in one question, with a citation behind every claim.**

`Docling` → `LlamaIndex` → `Qdrant` → `LangGraph` → `Ollama Cloud` → `FastAPI + Web Console`

</div>

---

## What this is

A production-shaped Retrieval-Augmented Generation engine for an organisation whose
knowledge is scattered across **five departments** — HR, Finance, Legal & Compliance,
Engineering and Customer Support — each holding its own policies, contracts,
specifications and customer-facing documents in PDF, DOCX, XLSX and Markdown.

Atlas does three things that a plain "chat with your PDF" demo does not:

1. **It parses faithfully.** Binary office documents go through Docling (or MinerU),
   preserving table structure and reading order, into provenance-stamped Markdown.
   Most answerable facts in a policy corpus live inside tables; a parser that
   flattens them destroys the answer.
2. **It retrieves under access control.** A caller's role decides which departments
   they may read, and that decision becomes a *hard metadata filter on the vector
   query* — not a line in a prompt. A prompt injection cannot widen it.
3. **It is an agent, not a chain.** A LangGraph state machine grades its own
   evidence and, when the evidence is thin, rewrites the query in the corpus's own
   vocabulary and retrieves again before it will answer.

## Signing in

The console opens on a sign-in screen. **Roles come from the authenticated
session, never from a request parameter**, so what a user can retrieve, upload or
delete is decided by who they are rather than by what their browser claims.

Seeded demo accounts:

| Username | Password | Role | Can see |
|---|---|---|---|
| `admin` | `atlas-admin` | Administrator | everything, plus document and user management |
| `priya` | `atlas-demo` | Employee | HR, Customer Support |
| `rahul` | `atlas-demo` | Support agent | HR, Support, Engineering |
| `aditi` | `atlas-demo` | Finance analyst | Finance, HR, Legal |
| `vikram` | `atlas-demo` | Legal counsel | Legal, Finance, HR |
| `sanjay` | `atlas-demo` | Executive | all five departments, read-only |

**Create account** self-registers an `employee`. Choosing *Administrator* needs
the operator's signup code (`make users-code`) — an open admin checkbox would make
the whole access-control model decorative. An administrator can create an account
with any role directly, from the console or the CLI.

> The demo accounts have published passwords. Before exposing a deployment:
> ```bash
> python scripts/manage_users.py add <you> --role admin
> python scripts/manage_users.py purge-demo
> ```

## Six workflows, one graph

| # | Workflow | The real problem it solves |
|---|----------|----------------------------|
| 1 | **Cross-Department Q&A** | "Where is this written down?" — the single most common internal-support question. |
| 2 | **Policy & Contract Compliance Check** | Returns PASS / REVIEW / FAIL against the organisation's own clauses before someone signs something they shouldn't. |
| 3 | **Support Ticket Resolver** | Turns a raw ticket into a grounded draft reply plus SLA, refund eligibility and escalation path. |
| 4 | **Cross-Document Conflict Detector** | Finds where the organisation's own departments contradict each other. |
| 5 | **Executive Briefing Generator** | A board-ready brief across all departments: position, obligations, risks, owners, actions. |
| 6 | **Role Onboarding Copilot** | A new joiner's cited first-week checklist. |

## Quickstart — 4 commands, no Docker, no API key

```bash
cd atlas-rag
make install        # venv + light stack (~60s)
make demo           # generate corpus → parse → index
make run            # http://localhost:8000
```

That runs in **offline demo mode**: retrieval is fully live, and answers are produced
by a deterministic extractive synthesizer. Everything — the graph, the trace, the
citations, the console — behaves identically.

For full natural-language synthesis, point it at either Ollama Cloud **or** a local
daemon:

```bash
cp .env.example .env
```

```ini
# Ollama Cloud — free key at https://ollama.com/settings/keys
OLLAMA_BASE_URL=https://ollama.com
OLLAMA_API_KEY=your-key

# ...or a local daemon, which needs no key at all
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_API_KEY=
OLLAMA_CHAT_MODEL=llama3.1:8b
OLLAMA_FAST_MODEL=llama3.1:8b
```

Offline mode is selected only when the base URL is `ollama.com` *and* no key is set.

## Full stack — LlamaIndex + Qdrant + Docling

```bash
make install-full                      # LlamaIndex, Qdrant client, Docling
docker compose up -d qdrant            # or use Qdrant Cloud's free tier
make parse-docling                     # re-parse with Docling
make ingest                            # embed → Qdrant
make run
```

Or the whole thing in one command:

```bash
docker compose up --build              # Qdrant + Atlas, http://localhost:8000
```

## Verify it works

```bash
make test                                    # 152 tests
python scripts/smoke_test.py                 # black-box checks against a running server
python scripts/smoke_test.py --base-url https://your-deployment.example
```

## Documentation

| Document | Contents |
|----------|----------|
| [`docs/REPORT.md`](docs/REPORT.md) | **The project report** — architecture, design decisions, results, evaluation, limitations. |
| [`docs/INSTALL.md`](docs/INSTALL.md) | Installing Docling and MinerU on WSL Ubuntu / Ubuntu, with the failures you will actually hit. |
| [`docs/VECTOR_STORE_COMPARISON.md`](docs/VECTOR_STORE_COMPARISON.md) | pgvector vs Qdrant vs Chroma vs Supabase — the comparison behind choosing Qdrant. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Diagrams and the data-flow walkthrough. |
| [`docs/PROMPTS.md`](docs/PROMPTS.md) | Every prompt used to build this with a coding agent. |
| [`docs/DEMO.md`](docs/DEMO.md) | The 8-minute demo script, with the questions to ask and what to point at. |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Hosting it publicly, and the CI/CD pipeline. |
| [`docs/SUBMISSION.md`](docs/SUBMISSION.md) | Deliverables checklist mapped to the brief. |

## Repository layout

```
atlas-rag/
├── atlas/
│   ├── parsing/          Docling / MinerU / dependency-free parsers → Markdown
│   ├── rag/              chunking, ACL, embeddings, Qdrant, LlamaIndex + lite backends
│   ├── agent/            LangGraph state, nodes, graph
│   ├── usecases/         the six output contracts
│   └── api/              FastAPI: JSON + SSE, serves the console
├── web/                  the console — hand-written HTML/CSS/JS, no build step
├── scripts/              corpus generator, parser CLI, ingest CLI, smoke test
├── data/raw/<dept>/      source PDF / DOCX / XLSX  ← drop your own documents here
├── data/markdown/<dept>/ parsed output with provenance front matter
├── tests/                152 tests: parsing, retrieval, ACL, agent, API
├── docs/                 report and supporting documents
└── Dockerfile · docker-compose.yml · render.yaml · fly.toml
```

The CI workflow lives at the **repository root** (`.github/workflows/atlas-ci-cd.yml`),
because GitHub only reads workflows from there. Every job runs with
`working-directory: atlas-rag`, and path filters keep it off unrelated pushes.

## Using your own documents

**From the web console** — click **Browse & add documents** in the sidebar, pick a
department, and drop in PDFs, Word files or spreadsheets. Each upload is parsed to
Markdown with provenance front matter and indexed immediately; it is answerable in
the next question you ask. The same panel lists everything currently indexed and
lets you remove a document (source file and parsed Markdown together).

**From the CLI** — delete `data/raw/*/*`, drop your own files into the department
folders, then:

```bash
make parse && make ingest
```

Departments are declared in one place — `DEPARTMENTS` in `atlas/config.py` — together
with the role → department access matrix. Adding a sixth department is a dictionary
entry and a folder.

---

<div align="center">
<sub>Built for the Agentic AI course project · MIT licensed · See <code>docs/REPORT.md</code></sub>
</div>
