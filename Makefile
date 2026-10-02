# ===========================================================================
# Atlas RAG - developer entry points.  `make help` lists everything.
# ===========================================================================
SHELL := /bin/bash
PY    := .venv/bin/python
PIP   := .venv/bin/pip
PORT  ?= 8000

.DEFAULT_GOAL := help
.PHONY: help venv install install-full seed parse parse-docling ingest ingest-lite evaluate smoke users users-code users-purge-demo \
        run dev test lint clean demo up down logs docker-build reset all

help:  ## show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	 | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

venv:  ## create the virtualenv
	python3 -m venv .venv && $(PIP) install --upgrade pip

install: venv  ## install the light stack (API + LangGraph + lite retrieval)
	$(PIP) install -r requirements-min.txt
	$(PIP) install python-docx openpyxl reportlab pypdf

install-full: venv  ## install the full stack (LlamaIndex + Qdrant + Docling)
	$(PIP) install -r requirements.txt

seed:  ## generate the sample multi-department corpus (docx/xlsx/pdf/md)
	$(PY) scripts/generate_sample_corpus.py

parse:  ## stage 1: data/raw -> data/markdown  (parser from .env)
	$(PY) scripts/parse_documents.py --report

parse-docling:  ## stage 1 forcing Docling
	$(PY) scripts/parse_documents.py --parser docling --force --report

ingest:  ## stage 2: data/markdown -> vector store
	$(PY) scripts/ingest.py

ingest-lite:  ## stage 2 using the zero-dependency backend
	$(PY) scripts/ingest.py --backend lite

run:  ## serve the API + web console on $(PORT)
	$(PY) -m uvicorn atlas.api.main:app --host 0.0.0.0 --port $(PORT)

dev:  ## serve with auto-reload
	$(PY) -m uvicorn atlas.api.main:app --reload --port $(PORT)

test:  ## run the test suite
	$(PY) -m pytest tests/ -q

lint:  ## ruff check
	$(PY) -m ruff check atlas scripts tests

demo: seed parse ingest-lite  ## one-shot: corpus -> markdown -> index
	@echo ""
	@echo "  Ready.  Run 'make run' and open http://localhost:$(PORT)"

all: install demo run  ## everything, from a clean clone

up:  ## docker compose up (Qdrant + Atlas)
	docker compose up --build -d && docker compose ps

down:  ## stop the stack
	docker compose down

logs:  ## follow container logs
	docker compose logs -f atlas

docker-build:  ## build the image only
	docker build -t atlas-rag:latest .

reset:  ## drop the index and parsed markdown (keeps data/raw)
	rm -rf storage data/markdown/*/*.md

clean: reset  ## reset + remove caches
	find . -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache .ruff_cache

evaluate:  ## run the retrieval + agent evaluation against the gold set
	$(PY) scripts/evaluate.py --with-agent

smoke:  ## black-box check a running server (BASE=http://... to target a deployment)
	$(PY) scripts/smoke_test.py --base-url $(or $(BASE),http://localhost:$(PORT))

hostinfo:  ## print the execution host details (submission deliverable e)
	$(PY) scripts/host_info.py

users:  ## list user accounts
	$(PY) scripts/manage_users.py list

users-code:  ## print the admin signup code
	$(PY) scripts/manage_users.py admin-code

users-purge-demo:  ## delete the seeded demo accounts (needs a real admin first)
	$(PY) scripts/manage_users.py purge-demo

submission:  ## build the submission zip (deliverables a-f)
	@rm -rf build/submission && mkdir -p build/submission
	@git -C .. archive --format=zip --prefix=atlas-rag-code/ HEAD:atlas-rag \
		-o "$(CURDIR)/build/submission/c_full_code.zip"
	@cp docs/PROMPTS.md            build/submission/a_prompts_used.md
	@cp docs/PLATFORM.md           build/submission/b_platform_used.md
	@cp docs/INSTALL.md            build/submission/d_installation_steps.md
	@$(PY) scripts/host_info.py --markdown > build/submission/e_execution_host.md
	@cp docs/PROJECT_REPORT.md     build/submission/f_architecture_and_results_report.md
	@cp docs/SUBMISSION.md         build/submission/README_deliverables.md
	@rm -f build/atlas-rag-submission.zip
	@cd build/submission && zip -qr ../atlas-rag-submission.zip .
	@echo "built build/atlas-rag-submission.zip"
	@unzip -l build/atlas-rag-submission.zip
