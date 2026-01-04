# Agent Coding Guidelines

You are an AI coding agent. Follow these rules strictly. No exceptions without explicit human override.

---

## Quick Reference: Core Rules

| Rule | Summary |
|------|---------|
| Plan First | Plan before implementing anything non-trivial |
| Type Safety | Make invalid states irrepresentable |
| Test Everything | Unit + E2E, happy path + edge cases |
| KISS | Simple beats clever; readable beats compact |
| Minimal Dependencies | Every library is a liability |
| Document Changes | ARCHITECTURE_DIFF.md for structural changes |
| Update Docs | README and docs updated with every PR |
| Verify Before Commit | `make test` must pass |
| Verbose PRs | Teach, explain, include architecture context |

---

## 1. Plan Before Coding

**When to plan:** New features, refactoring, bug investigation, multi-file changes.

**Skip only for:** Single-line fixes, typo corrections, explicit unambiguous instructions.

---

## 2. Type-Level Design

Design types so the compiler catches errors, not runtime.

**Do this:**
- Make invalid states irrepresentable
- Use sum types/enums over boolean flags
- Prefer narrow types (`UserId`) over broad types (`string`)
- Encode invariants in the type system

**Avoid:** `any`, `unknown`, or equivalent escape hatches.

**Example - BAD:**
```typescript
type User = {
  isLoggedIn: boolean;
  authToken: string | null;  // Can have token while logged out
}
```

**Example - GOOD:**
```typescript
type User = 
  | { status: 'anonymous' }
  | { status: 'authenticated'; authToken: string }
```

---

## 3. Testing Strategy

Every implementation needs: unit tests + E2E tests + happy paths + edge cases.

**Workflow:**
1. Run `make test` before changes (baseline)
2. Implement changes
3. Write/update tests
4. Run `make test` after changes
5. Fix regressions
6. All tests pass before work is complete

**`make test` must include:** unit tests, E2E tests, type checking, linting.

If `make test` is missing or incomplete, fix it first.

---

## 4. Type Checking and Linting

Run on every verification cycle.

**Compiled languages:** Strict compiler flags, zero warnings policy.

**Interpreted languages:** Type checker (mypy, pyright, tsc) + linter (eslint, ruff, clippy) integrated into `make test`.

**Example Makefile:**
```makefile
test:
	npm run typecheck
	npm run lint
	npm run test:unit
	npm run test:e2e
```

---

## 5. Architecture Documentation

**Trigger:** Any structural change to the codebase.

**What counts as architecture change:**
- New modules or packages
- Changed directory structure
- New external services or integrations
- Database schema changes
- API contract changes
- New dependencies affecting system design
- Changes to data flow or control flow

**Rules:**
1. Create `ARCHITECTURE_DIFF.md` in repo root before PR
2. Delete and replace if one exists from previous work
3. Delete before merging (never merge this file into main)

**Template:**
```markdown
# Architecture Diff

## Summary
One-sentence description of what changed.

## Changes

### Added
- [component/module]: Why it was added

### Modified
- [component/module]: What changed and why

### Removed
- [component/module]: Why it was removed

## Rationale
Why this approach was chosen over alternatives.

## Trade-offs
What we gained and what we gave up.

## Migration Notes (if applicable)
Steps needed to transition from old to new.
```

---

## 6. Documentation Updates

**Rule: Every PR must update relevant documentation.**

Mandatory, not optional. Documentation rot is a bug.

**Always update:**
- README.md if user-facing behavior changes
- API docs if endpoints or contracts change
- Setup/installation docs if dependencies or config change
- Architecture docs if structure changes
- Inline code comments if behavior is non-obvious

**Test:** If a new developer reads only the docs, will they understand the current state? If no, fix the docs.

---

## 7. Pull Request Descriptions

**PR descriptions must be verbose, explanatory, and written in a teaching style.**

Goal: A reviewer should understand WHAT changed, WHY, HOW it works, and what trade-offs were made.

**Required sections:**

### Summary
What this PR does in 1-2 sentences.

### Motivation
Why this change is needed. What problem it solves.

### Implementation Details
How the solution works. Walk through key changes. Explain non-obvious decisions.

### Architecture Changes (if applicable)
Include the full content of ARCHITECTURE_DIFF.md here. Do not just link to it.

### Testing
What tests were added or modified. How to verify the change works.

### Trade-offs and Alternatives Considered
What other approaches were evaluated. Why this one was chosen.

### Comprehension Questions
At the bottom of every PR, include 1-3 questions to verify the reviewer understands the change.

**Example:**
```markdown
## Comprehension Check

1. Why did we choose a mutex over a RwLock for the cache invalidation?
2. What would break if we removed the `NonZeroU32` constraint on `quantity`?
3. How does the new retry logic differ from the previous implementation?
```

**Purpose:** Forces identification of key concepts, helps reviewers focus, creates teaching moments, catches PRs where even the author can't explain the change.

---

## 8. GitHub Actions CI

If the repo lacks CI, create it.

**Requirements:**
- Trigger on pull requests only
- Run full `make test` suite
- Include type checking and linting
- Block merge on failure

**Minimal workflow:**
```yaml
name: CI

on:
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: make install
      - name: Run all checks
        run: make test
```

---

## 9. Code Simplicity (KISS)

Simple and readable beats clever and compact.

**Rules:**
- Write code a junior developer can understand
- One level of abstraction per function
- No premature optimization
- No premature abstraction
- If you need a comment to explain what code does, rewrite the code
- Explicit over implicit
- Boring technology over exciting technology

**Red flags - stop and simplify:**
- Functions over 30 lines
- More than 3 levels of nesting
- Clever one-liners requiring thought to parse
- Abstractions with only one implementation
- "Flexible" code for hypothetical future requirements

---

## 10. Minimal Dependencies

Every external dependency is a liability.

**Before adding a dependency, verify:**
1. Cannot be implemented in <50 lines
2. Core, actively maintained library
3. Small dependency tree
4. Compatible license

**Prefer:** Standard library > single-purpose library > framework > no dependency.

**If a feature requires 5+ transitive dependencies, reconsider the approach.**

---

## 11. Code Review

Run code review on all non-trivial PRs.

**Workflow:**
1. Complete implementation
2. Ensure `make test` passes
3. Commit and push
4. Create PR (with verbose description and comprehension questions)
5. Run code review
6. Address issues with high confidence
7. Re-run if significant changes made

---

## 12. Commit Discipline

Commit when work is complete and verified.

**Before committing (if on feature branch):**
1. Fetch latest from origin
2. Rebase or merge main/master
3. Resolve conflicts
4. Re-run `make test`
5. Commit

**Commit message format:**
```bash
git commit -m "Add user authentication endpoint"

git commit -m "Fix race condition in cache invalidation" -m "Previous implementation could serve stale data during concurrent invalidation. Now using mutex to serialize cache updates."
```

**Never use heredocs in commit commands** - they fail in sandboxed environments.

---

## Summary Checklist

Before marking any task complete:

- [ ] Planning done (if non-trivial)
- [ ] Types prevent invalid states
- [ ] Unit tests written (happy path + edge cases)
- [ ] E2E tests written (happy path + edge cases)
- [ ] `make test` passes
- [ ] GitHub Actions CI exists and passes
- [ ] Code is simple and readable
- [ ] No unnecessary dependencies
- [ ] README and docs updated
- [ ] ARCHITECTURE_DIFF.md created (if architecture changed)
- [ ] PR description is verbose and explanatory
- [ ] PR includes ARCHITECTURE_DIFF.md content (if created)
- [ ] PR includes 1-3 comprehension questions
- [ ] Code review completed
- [ ] Branch updated with latest main/master
- [ ] Changes committed with clear message
- [ ] ARCHITECTURE_DIFF.md removed before merge
