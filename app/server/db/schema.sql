-- CORTEX Postgres schema (core)
--
-- Goals
-- - Single source of truth for: chats, RAG sources/chunks/embeddings, runs/telemetry,
--   fine-tuning datasets/jobs, benchmarks, and council voting sessions.
--
-- What belongs in the database
-- - Text: conversation titles, messages, chunk text, prompts/templates.
-- - Metadata: model/provider info, run parameters, metrics, hashes, timestamps.
-- - Embeddings: vectors for chunks (pgvector).
-- - References (pointers) to large files on disk/object storage (artifacts).
--
-- What should NOT go in the database
-- - Model weights / checkpoints binaries (store as files, reference via artifacts.uri).
-- - Large raw datasets / huge documents (store as files, optionally store only chunks).
-- - Secrets (API keys, tokens). Keep in env vars or a secrets manager.
--
-- Requirements
-- - Postgres 13+
-- - Extensions: pgcrypto (UUIDs), vector (pgvector)
--
-- Usage (example)
--   createdb cortex
--   psql -d cortex -f app/server/db/schema.sql

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS cortex;

-- ----------
-- Types
-- ----------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'message_role' AND n.nspname = 'cortex'
  ) THEN
    CREATE TYPE cortex.message_role AS ENUM ('system', 'user', 'assistant', 'tool');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'run_status' AND n.nspname = 'cortex'
  ) THEN
    CREATE TYPE cortex.run_status AS ENUM ('queued', 'running', 'succeeded', 'failed', 'canceled');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'artifact_kind' AND n.nspname = 'cortex'
  ) THEN
    CREATE TYPE cortex.artifact_kind AS ENUM (
      'document_raw',
      'document_export',
      'dataset_raw',
      'dataset_export',
      'training_checkpoint',
      'training_output',
      'benchmark_output',
      'log',
      'image',
      'other'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'rag_source_type' AND n.nspname = 'cortex'
  ) THEN
    CREATE TYPE cortex.rag_source_type AS ENUM ('file', 'url', 'note', 'text');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'dataset_format' AND n.nspname = 'cortex'
  ) THEN
    CREATE TYPE cortex.dataset_format AS ENUM ('jsonl', 'chatml', 'alpaca', 'custom');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'job_status' AND n.nspname = 'cortex'
  ) THEN
    CREATE TYPE cortex.job_status AS ENUM ('queued', 'running', 'succeeded', 'failed', 'canceled');
  END IF;
END $$;

-- ----------
-- Core / identity
-- ----------
CREATE TABLE IF NOT EXISTS cortex.workspaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cortex.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  handle text,
  display_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, handle)
);

-- ----------
-- Artifacts (pointers to files stored outside the DB)
-- ----------
CREATE TABLE IF NOT EXISTS cortex.artifacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  kind cortex.artifact_kind NOT NULL,
  storage_backend text NOT NULL DEFAULT 'filesystem',
  uri text NOT NULL,
  mime_type text,
  byte_size bigint,
  sha256 text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workspace_id, uri)
);

CREATE INDEX IF NOT EXISTS artifacts_workspace_kind_idx ON cortex.artifacts (workspace_id, kind);

-- ----------
-- Models + profiles
-- ----------
CREATE TABLE IF NOT EXISTS cortex.llm_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL, -- e.g. 'ollama'
  name text NOT NULL,     -- e.g. 'qwen2.5-coder:3b'
  digest text,
  family text,
  parameter_size text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (provider, name)
);

CREATE TABLE IF NOT EXISTS cortex.embedding_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  name text NOT NULL,
  dims integer, -- optional; can be discovered during ingestion
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (provider, name)
);

CREATE TABLE IF NOT EXISTS cortex.model_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  llm_model_id uuid REFERENCES cortex.llm_models(id) ON DELETE SET NULL,
  system_prompt text,
  parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workspace_id, name)
);

-- ----------
-- Chat
-- ----------
CREATE TABLE IF NOT EXISTS cortex.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  created_by_user_id uuid REFERENCES cortex.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  model_profile_id uuid REFERENCES cortex.model_profiles(id) ON DELETE SET NULL,
  pinned boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS conversations_workspace_updated_idx ON cortex.conversations (workspace_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS cortex.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES cortex.conversations(id) ON DELETE CASCADE,
  seq bigint GENERATED ALWAYS AS IDENTITY,
  role cortex.message_role NOT NULL,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS messages_conversation_seq_idx ON cortex.messages (conversation_id, seq);
CREATE INDEX IF NOT EXISTS messages_conversation_created_idx ON cortex.messages (conversation_id, created_at);

CREATE TABLE IF NOT EXISTS cortex.message_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES cortex.messages(id) ON DELETE CASCADE,
  artifact_id uuid REFERENCES cortex.artifacts(id) ON DELETE SET NULL,
  title text,
  mime_type text,
  byte_size bigint,
  uri text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS message_attachments_message_idx ON cortex.message_attachments (message_id);

-- ----------
-- LLM runs / telemetry
-- ----------
CREATE TABLE IF NOT EXISTS cortex.llm_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES cortex.conversations(id) ON DELETE CASCADE,
  request_message_id uuid REFERENCES cortex.messages(id) ON DELETE SET NULL,
  response_message_id uuid REFERENCES cortex.messages(id) ON DELETE SET NULL,
  provider text NOT NULL DEFAULT 'ollama',
  model_name text NOT NULL,
  llm_model_id uuid REFERENCES cortex.llm_models(id) ON DELETE SET NULL,
  parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
  status cortex.run_status NOT NULL DEFAULT 'queued',
  started_at timestamptz,
  finished_at timestamptz,
  duration_ms integer,
  input_tokens integer,
  output_tokens integer,
  total_tokens integer,
  error_text text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS llm_runs_workspace_created_idx ON cortex.llm_runs (workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS llm_runs_conversation_created_idx ON cortex.llm_runs (conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS llm_runs_status_idx ON cortex.llm_runs (status);

CREATE TABLE IF NOT EXISTS cortex.tool_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  llm_run_id uuid NOT NULL REFERENCES cortex.llm_runs(id) ON DELETE CASCADE,
  tool_name text NOT NULL,
  input jsonb NOT NULL DEFAULT '{}'::jsonb,
  output jsonb,
  output_artifact_id uuid REFERENCES cortex.artifacts(id) ON DELETE SET NULL,
  error_text text,
  started_at timestamptz,
  finished_at timestamptz,
  duration_ms integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS tool_calls_llm_run_idx ON cortex.tool_calls (llm_run_id);

-- ----------
-- RAG
-- ----------
CREATE TABLE IF NOT EXISTS cortex.rag_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workspace_id, name)
);

CREATE TABLE IF NOT EXISTS cortex.rag_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  source_type cortex.rag_source_type NOT NULL,
  title text NOT NULL,
  uri text,
  artifact_id uuid REFERENCES cortex.artifacts(id) ON DELETE SET NULL,
  content_sha256 text,
  byte_size bigint,
  ingested_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS rag_sources_workspace_updated_idx ON cortex.rag_sources (workspace_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS cortex.rag_collection_sources (
  collection_id uuid NOT NULL REFERENCES cortex.rag_collections(id) ON DELETE CASCADE,
  source_id uuid NOT NULL REFERENCES cortex.rag_sources(id) ON DELETE CASCADE,
  added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (collection_id, source_id)
);

CREATE TABLE IF NOT EXISTS cortex.rag_source_text (
  source_id uuid PRIMARY KEY REFERENCES cortex.rag_sources(id) ON DELETE CASCADE,
  content text NOT NULL
);

CREATE TABLE IF NOT EXISTS cortex.rag_chunks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid NOT NULL REFERENCES cortex.rag_sources(id) ON DELETE CASCADE,
  chunk_index integer NOT NULL,
  content text NOT NULL,
  token_count integer,
  char_start integer,
  char_end integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  tsv tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(content, ''))) STORED,
  UNIQUE (source_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS rag_chunks_source_chunk_idx ON cortex.rag_chunks (source_id, chunk_index);
CREATE INDEX IF NOT EXISTS rag_chunks_tsv_gin ON cortex.rag_chunks USING gin (tsv);

-- Embeddings can have different dimensions in the same column by using `vector`
-- (instead of `vector(n)`). To index embeddings, create a partial expression index
-- per embedding model + dimension.
--
-- Example template (replace DIM and model UUID):
--   CREATE INDEX ON cortex.rag_embeddings
--     USING hnsw ((embedding::vector(DIM)) vector_cosine_ops)
--     WHERE (embedding_model_id = '00000000-0000-0000-0000-000000000000');

CREATE TABLE IF NOT EXISTS cortex.rag_embeddings (
  embedding_model_id uuid NOT NULL REFERENCES cortex.embedding_models(id) ON DELETE CASCADE,
  chunk_id uuid NOT NULL REFERENCES cortex.rag_chunks(id) ON DELETE CASCADE,
  embedding vector NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (embedding_model_id, chunk_id)
);

CREATE TABLE IF NOT EXISTS cortex.message_citations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES cortex.messages(id) ON DELETE CASCADE,
  chunk_id uuid NOT NULL REFERENCES cortex.rag_chunks(id) ON DELETE RESTRICT,
  rank integer,
  score real,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS message_citations_message_idx ON cortex.message_citations (message_id);

-- ----------
-- Prompt templates
-- ----------
CREATE TABLE IF NOT EXISTS cortex.prompt_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  template text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workspace_id, name)
);

-- ----------
-- Fine-tuning / datasets
-- ----------
CREATE TABLE IF NOT EXISTS cortex.datasets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  format cortex.dataset_format NOT NULL,
  storage_artifact_id uuid REFERENCES cortex.artifacts(id) ON DELETE SET NULL,
  schema_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workspace_id, name)
);

CREATE TABLE IF NOT EXISTS cortex.dataset_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_id uuid NOT NULL REFERENCES cortex.datasets(id) ON DELETE CASCADE,
  version integer NOT NULL,
  storage_artifact_id uuid REFERENCES cortex.artifacts(id) ON DELETE SET NULL,
  row_count bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (dataset_id, version)
);

-- Optional: store individual dataset items when you need row-level traceability.
-- For very large datasets, keep them as files and store only the artifact pointer.
CREATE TABLE IF NOT EXISTS cortex.dataset_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_version_id uuid NOT NULL REFERENCES cortex.dataset_versions(id) ON DELETE CASCADE,
  item_index bigint NOT NULL,
  input jsonb NOT NULL,
  output jsonb,
  hash_sha256 text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (dataset_version_id, item_index)
);

CREATE INDEX IF NOT EXISTS dataset_items_version_idx ON cortex.dataset_items (dataset_version_id, item_index);

CREATE TABLE IF NOT EXISTS cortex.training_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  base_model_id uuid REFERENCES cortex.llm_models(id) ON DELETE SET NULL,
  base_model_name text NOT NULL,
  dataset_version_id uuid REFERENCES cortex.dataset_versions(id) ON DELETE SET NULL,
  status cortex.job_status NOT NULL DEFAULT 'queued',
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  finished_at timestamptz,
  output_artifact_id uuid REFERENCES cortex.artifacts(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS training_jobs_workspace_created_idx ON cortex.training_jobs (workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS training_jobs_status_idx ON cortex.training_jobs (status);

CREATE TABLE IF NOT EXISTS cortex.training_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  training_job_id uuid NOT NULL REFERENCES cortex.training_jobs(id) ON DELETE CASCADE,
  step integer NOT NULL,
  epoch real,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  artifact_id uuid REFERENCES cortex.artifacts(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (training_job_id, step)
);

CREATE TABLE IF NOT EXISTS cortex.training_events (
  id bigserial PRIMARY KEY,
  training_job_id uuid NOT NULL REFERENCES cortex.training_jobs(id) ON DELETE CASCADE,
  ts timestamptz NOT NULL DEFAULT now(),
  level text NOT NULL,
  message text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS training_events_job_ts_idx ON cortex.training_events (training_job_id, ts);

-- ----------
-- Benchmarks / evaluation
-- ----------
CREATE TABLE IF NOT EXISTS cortex.benchmark_suites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workspace_id, name)
);

CREATE TABLE IF NOT EXISTS cortex.benchmark_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  suite_id uuid NOT NULL REFERENCES cortex.benchmark_suites(id) ON DELETE CASCADE,
  external_id text,
  input jsonb NOT NULL,
  expected jsonb,
  tags text[] NOT NULL DEFAULT '{}',
  weight real NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS benchmark_cases_suite_idx ON cortex.benchmark_cases (suite_id);

CREATE TABLE IF NOT EXISTS cortex.benchmark_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  suite_id uuid NOT NULL REFERENCES cortex.benchmark_suites(id) ON DELETE CASCADE,
  llm_model_id uuid REFERENCES cortex.llm_models(id) ON DELETE SET NULL,
  model_name text NOT NULL,
  status cortex.run_status NOT NULL DEFAULT 'queued',
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS benchmark_runs_suite_created_idx ON cortex.benchmark_runs (suite_id, created_at DESC);

CREATE TABLE IF NOT EXISTS cortex.benchmark_case_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  benchmark_run_id uuid NOT NULL REFERENCES cortex.benchmark_runs(id) ON DELETE CASCADE,
  case_id uuid NOT NULL REFERENCES cortex.benchmark_cases(id) ON DELETE CASCADE,
  status cortex.run_status NOT NULL DEFAULT 'succeeded',
  score numeric,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  output jsonb,
  error_text text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (benchmark_run_id, case_id)
);

CREATE INDEX IF NOT EXISTS benchmark_case_results_run_idx ON cortex.benchmark_case_results (benchmark_run_id);

-- ----------
-- Council (multi-agent voting)
-- ----------
CREATE TABLE IF NOT EXISTS cortex.council_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES cortex.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workspace_id, name)
);

CREATE TABLE IF NOT EXISTS cortex.council_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  council_config_id uuid NOT NULL REFERENCES cortex.council_configs(id) ON DELETE CASCADE,
  member_index integer NOT NULL,
  name text NOT NULL,
  llm_model_id uuid REFERENCES cortex.llm_models(id) ON DELETE SET NULL,
  model_name text NOT NULL,
  system_prompt text,
  parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (council_config_id, member_index)
);

CREATE TABLE IF NOT EXISTS cortex.council_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES cortex.conversations(id) ON DELETE CASCADE,
  council_config_id uuid NOT NULL REFERENCES cortex.council_configs(id) ON DELETE RESTRICT,
  triggered_by_message_id uuid REFERENCES cortex.messages(id) ON DELETE SET NULL,
  status cortex.run_status NOT NULL DEFAULT 'queued',
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS council_sessions_conversation_created_idx ON cortex.council_sessions (conversation_id, created_at DESC);

CREATE TABLE IF NOT EXISTS cortex.council_member_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  council_session_id uuid NOT NULL REFERENCES cortex.council_sessions(id) ON DELETE CASCADE,
  council_member_id uuid NOT NULL REFERENCES cortex.council_members(id) ON DELETE RESTRICT,
  llm_run_id uuid REFERENCES cortex.llm_runs(id) ON DELETE SET NULL,
  output_message_id uuid REFERENCES cortex.messages(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (council_session_id, council_member_id)
);

CREATE TABLE IF NOT EXISTS cortex.council_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  council_session_id uuid NOT NULL REFERENCES cortex.council_sessions(id) ON DELETE CASCADE,
  voter_member_id uuid NOT NULL REFERENCES cortex.council_members(id) ON DELETE RESTRICT,
  target_member_id uuid NOT NULL REFERENCES cortex.council_members(id) ON DELETE RESTRICT,
  vote_score integer NOT NULL,
  rationale text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (council_session_id, voter_member_id, target_member_id),
  CHECK (vote_score BETWEEN -10 AND 10)
);

CREATE TABLE IF NOT EXISTS cortex.council_decisions (
  council_session_id uuid PRIMARY KEY REFERENCES cortex.council_sessions(id) ON DELETE CASCADE,
  selected_member_id uuid REFERENCES cortex.council_members(id) ON DELETE SET NULL,
  final_message_id uuid REFERENCES cortex.messages(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMIT;
