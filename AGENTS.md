# Repository Guidelines

The Interview System (面试系统) manages the recruiting lifecycle: application, resume screening, interview scheduling, evaluation, and offer. The product spec is `docs/面试系统需求文档.md` (maintained in Chinese). Planned stack: Vue frontend, Java backend (Spring Boot + MyBatis-Plus), MySQL 8.

## Project Structure & Module Organization

Current layout:
- `docs/` — PRD and design documents (Chinese)
- `docs/sql/schema.sql` — MySQL DDL; the single source of truth for schema changes
- `README.md` — project overview

Planned monorepo layout:
- `frontend/` — Vue 3 SPA (candidate H5 + admin PC)
- `backend/` — Spring Boot service, packages grouped by domain: `system`, `candidate`, `interview`, `offer`, `report`

## Build, Test, and Development Commands

No build tooling is committed yet; use these once modules are added:
- `cd backend && mvn spring-boot:run` — run the backend locally
- `cd backend && mvn test` — run backend unit tests
- `cd frontend && npm install && npm run dev` — start the Vue dev server
- `mysql -u root -p < docs/sql/schema.sql` — initialize the local database (utf8mb4)

## Coding Style & Naming Conventions

- SQL: uppercase keywords, `snake_case` tables/columns, Chinese comments, `sys_` prefix for system-domain tables; every table includes audit columns (`created_by`, `created_time`, `updated_by`, `updated_time`, `deleted`) and BIGINT snowflake IDs (MyBatis-Plus `ASSIGN_ID`).
- Java: 4-space indent, camelCase, domain-driven packages.
- Vue: 2-space indent, PascalCase components, camelCase functions.
- No linter/formatter is configured; agree on one (e.g. Prettier, Spotless) before the first code commit.

## Testing Guidelines

No tests exist yet. Once code lands:
- Backend: JUnit 5 with Spring Boot Test; name classes `XxxServiceTest` and methods `shouldDoSomething`.
- Frontend: Vitest; name specs `<Component>.spec.js`.
- Cover at least the core flows: scheduling, evaluation, offer.
- Run the full suite before opening a PR.

## Commit & Pull Request Guidelines

No commits exist yet; adopt Conventional Commits from the first commit: `feat(interview): ...`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`. Keep subjects imperative, short, and in English.

For PRs:
- Reference the related issue; summarize what changed and why.
- Include screenshots for UI changes.
- Any DDL change must update `docs/sql/schema.sql`; behavior changes update the PRD.

## Security & Configuration

- Store candidate PII (phone, ID number) AES-encrypted and mask it in the UI; expose plaintext only to authorized roles.
- Hash passwords with BCrypt; enforce RBAC so interviewers only see their assigned interviews.
- Never commit secrets; load credentials from environment variables or profile-specific config.