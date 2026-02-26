---
applyTo: "**/db/changelog/**"
---

# Liquibase Migration Conventions

Follow the spring-boot skill — specifically the Database & JPA section.

## Rules
- Use YAML format for all changesets — NEVER SQL or XML format
- NEVER modify a deployed changeset — always create a new one
- File naming: `NNN-description.yaml` (e.g., `001-create-users-table.yaml`)
- Every changeset MUST have a unique `id` and `author`
- Include rollback instructions for destructive changes (drop table, drop column)
- Add audit columns (`created_at`, `updated_at`, `created_by`, `updated_by`) to business entity tables
- Use appropriate column types: `BIGINT` for IDs, `TIMESTAMP WITH TIME ZONE` for dates, `VARCHAR(n)` with explicit length
- Add indexes for foreign keys and frequently queried columns
- Add constraints explicitly: `NOT NULL`, `UNIQUE`, foreign keys with `ON DELETE` behavior
