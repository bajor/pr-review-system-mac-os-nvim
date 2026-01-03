# Agent Coding Guidelines

## Core Principles

1. **Plan before coding** — Use Plan mode for anything non-trivial
2. **Type-level correctness** — Make invalid states irrepresentable
3. **Test thoroughly** — Unit tests + E2E tests, happy paths + edge cases
4. **Keep it simple** — KISS over clever; readable over compact
5. **Minimize dependencies** — Every external library is a liability
6. **Document architecture changes** — Create ARCHITECTURE_DIFF.md before PR
7. **Verify before committing** — Tests and type checks must pass

---

## 1. Plan Mode First

Use Plan mode before implementing features or making significant changes.

**Always use Plan mode for:**
- New features
- Refactoring
- Bug investigation
- Multi-file changes

**Skip Plan mode only for:**
- Single-line fixes
- Typo corrections
- Changes with explicit, unambiguous instructions

---

## 2. Type-Level Design

Design types to catch errors at compile time, not runtime.

**Principles:**
- Make invalid states irrepresentable
- Use sum types/enums over boolean flags
- Prefer narrow types over broad ones (e.g., `UserId` over `string`)
- Encode invariants in the type system
- Avoid `any`, `unknown`, or equivalent escape hatches unless absolutely necessary

**Examples:**

```typescript
// BAD: Invalid states are representable
type User = {
  isLoggedIn: boolean;
  authToken: string | null;  // Can have token while logged out
}

// GOOD: Invalid states are irrepresentable
type User = 
  | { status: 'anonymous' }
  | { status: 'authenticated'; authToken: string }
```

```rust
// BAD: Runtime validation needed
fn process_order(quantity: i32) { /* must check quantity > 0 */ }

// GOOD: Compile-time guarantee
fn process_order(quantity: NonZeroU32) { /* always valid */ }
```

---

## 3. Testing Strategy

Every implementation requires both unit tests and E2E tests covering happy paths and edge cases.

**Test coverage requirements:**
- **Unit tests**: Test individual functions/modules in isolation
- **E2E tests**: Test complete user flows and integrations
- **Happy paths**: Expected inputs produce expected outputs
- **Edge cases**: Boundaries, empty inputs, nulls, errors, concurrency

**Workflow:**
1. Run `make test` before changes (baseline)
2. Implement changes
3. Write/update tests for new behavior
4. Run `make test` after changes
5. Fix any regressions
6. All tests must pass before considering work complete

**All verification runs through `make test`**, which must include:
- Unit tests
- E2E tests
- Type checking (compiler/type checker)
- Linting (for interpreted languages)

If `make test` doesn't exist or doesn't include all checks, fix it first.

---

## 4. Type Checking and Linting

Type checks and linters run on every verification cycle, not as an afterthought.

**For compiled languages:**
- Type checking is part of compilation
- Ensure strict compiler flags are enabled
- Zero warnings policy where feasible

**For interpreted languages:**
- Type checker must run (mypy, pyright, tsc, etc.)
- Linter must run (eslint, ruff, clippy, etc.)
- Both integrated into `make test`

**Configuration examples:**

```makefile
# make test should include everything
test:
	npm run typecheck
	npm run lint
	npm run test:unit
	npm run test:e2e
```

```makefile
test:
	mypy src/
	ruff check src/
	pytest tests/
```

---

## 5. Architecture Documentation

**When architecture changes, create `ARCHITECTURE_DIFF.md` before opening a PR.**

This file documents what changed structurally and why. It exists for review purposes only.

**Rules:**
- Create `ARCHITECTURE_DIFF.md` in the repository root before creating a PR
- If `ARCHITECTURE_DIFF.md` already exists from a previous change, delete it and replace with yours
- Delete `ARCHITECTURE_DIFF.md` before merging the PR (it must not be merged into main)

**What counts as an architecture change:**
- New modules or packages
- Changed directory structure
- New external services or integrations
- Database schema changes
- API contract changes
- New dependencies that affect system design
- Changes to data flow or control flow patterns

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

## 6. GitHub Actions CI

If the repository lacks GitHub Actions for PR checks, create them.

**Requirements:**
- Triggered on pull requests only (not pushes to main)
- Must run the full `make test` suite
- Must include type checking and linting
- PRs cannot merge with failing checks

**Minimal workflow:**

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup # (language-specific setup)
        # ...
      
      - name: Install dependencies
        run: make install  # or equivalent
      
      - name: Run all checks
        run: make test
```

**After creating or modifying CI:**
- Push changes to a branch
- Open a PR
- Verify the workflow triggers and passes
- Do not merge until CI is green

---

## 7. Code Simplicity (KISS)

Never overcomplicate. Simple and readable beats clever and compact.

**Rules:**
- Write code a junior developer can understand
- One level of abstraction per function
- Avoid premature optimization
- Avoid premature abstraction
- If you need a comment to explain what code does, rewrite the code
- Prefer explicit over implicit
- Prefer boring technology over exciting technology

**Red flags — stop and simplify if you see:**
- Functions over 30 lines
- More than 3 levels of nesting
- Clever one-liners that require thought to parse
- Abstractions with only one implementation
- "Flexible" code for hypothetical future requirements

---

## 8. Minimal Dependencies

Every external dependency is a liability: security risk, maintenance burden, potential breakage.

**Before adding a dependency, ask:**
1. Can this be implemented in <50 lines of code?
2. Is this a core, well-maintained library (not abandoned)?
3. Does the dependency tree stay small?
4. Is the license compatible?

**Prefer:**
- Standard library over external packages
- Single-purpose libraries over frameworks
- Vendoring small utilities over adding dependencies
- No dependency over any dependency

**Dependency audit:** If a feature requires pulling in 5+ transitive dependencies, reconsider the approach.

---

## 9. Code Review

Use `/code-review` on all non-trivial PRs. Apply the same standards to AI-generated and human code.

**Workflow:**
1. Complete implementation
2. Ensure `make test` passes
3. Commit and push
4. Create PR
5. Run `/code-review`
6. Address issues with confidence >= 80
7. Re-run if significant changes made

---

## 10. Commit Discipline

Commit when work is complete and verified. Never leave work uncommitted.

**Before committing (if not on main/master):**
1. Fetch latest changes from origin
2. Rebase or merge main/master into your branch
3. Resolve all conflicts
4. Re-run `make test` after resolving conflicts
5. Only then proceed to commit

**When to commit:**
- After completing a feature or fix
- After `make test` passes
- Before switching tasks
- At natural breakpoints in larger work

**Commit message format:**

```bash
# Simple commits
git commit -m "Add user authentication endpoint"

# With details (use multiple -m flags, not heredocs)
git commit -m "Fix race condition in cache invalidation" -m "The previous implementation could serve stale data when concurrent requests triggered invalidation. Now using mutex to serialize cache updates."
```

**Never use heredocs in commit commands** — they fail in sandboxed environments.

---

## Summary Checklist

Before marking any task complete:

- [ ] Plan mode used (if non-trivial)
- [ ] Types designed to prevent invalid states
- [ ] Unit tests written (happy path + edge cases)
- [ ] E2E tests written (happy path + edge cases)
- [ ] `make test` passes (tests + types + lint)
- [ ] GitHub Actions CI exists and passes on PR
- [ ] Code is simple and readable
- [ ] No unnecessary dependencies added
- [ ] `ARCHITECTURE_DIFF.md` created (if architecture changed)
- [ ] Code review completed
- [ ] Branch updated with latest main/master (if on feature branch)
- [ ] Changes committed with clear message
- [ ] `ARCHITECTURE_DIFF.md` removed before merge (if created)
