# AGENTS.md

Repository working rules:

1. `TASKS.md` is the only task tracker in this repository.
2. Every code, UX, sync, platform, or asset change must evaluate whether `SPEC.md`, `DESIGN.md`, and `TASKS.md` need updates.
3. If runtime behavior, shipped capabilities, limitations, architecture, or completed work changed, update the relevant documentation in the same work item.
4. Do not leave `SPEC.md`, `DESIGN.md`, or `TASKS.md` knowingly out of sync with the implemented app.
5. When a task is completed or partially completed, reflect that status in `TASKS.md` if the tracker is affected.
6. Prefer small, accurate documentation updates over broad speculative rewrites.
7. Follow TDD whenever it is reasonably practical for the change.
8. For new behavior or bug fixes, add or update a failing test first when feasible, then implement the minimum code needed to make it pass.
9. If a test-first change is not practical, document that constraint in the work summary and still add focused tests as soon as the code can be exercised safely.
