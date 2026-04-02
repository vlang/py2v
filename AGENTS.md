# AGENTS Guide for `py2v`

## Purpose
- This file gives concise, actionable rules for automated agents working in `py2v`.
- Focus on repository conventions, build/test workflows, and places to implement
  functionality.

## Big Picture
- `py2v` is a 2-stage transpiler: Python frontend emits enriched JSON AST, V backend parses
  JSON and generates V code.
- Entry flow: `main.v` -> run `frontend/ast_dump.py` via `python3` -> `parse_ast()` in
  `parser.v` -> `VTranspiler.visit_module()` in `transpiler.v`.
- Why this split matters: semantic analysis (mutability, class-method flags, main-guard
  rewrite) is done in Python where AST tooling is strong; V side focuses on deterministic
  codegen.

## Architecture Map (read these first)
- `frontend/ast_dump.py`: enrichment passes (`ScopeTracker`, `_rewrite_main_guard`,
  `_detect_class_methods`, nesting levels, `v_annotation` hints).
- `ast.v`: canonical V-side AST types (`Expr`, `Stmt`, `Module`); parser/transpiler must stay
  in sync with this contract.
- `parser.v`: JSON -> V AST conversion; add node fields/types here when frontend JSON shape
  changes.
- `transpiler.v`: core codegen and ordering rules (`__global` block, defs first, `fn main()`
  wrapping, import emission).
- `plugins.v`: builtin/function shims via `dispatch_builtin()` (preferred place for Python
  builtin behavior mapping).
- `types.v`: Python -> V type mapping, identifier escaping, numeric promotion rules.

## Project-Specific Conventions
- Module-level assignments are intentionally split: first definitions become `__global (...)`,
  executable top-level statements go into generated `fn main()`
  (`transpiler.v::visit_module`).
- Generated files start with `@[translated]` and `module <name>`; `module_name` is derived from
  output directory when using `-o` (`main.v::module_name_from_output_path`).
- `Any` is emitted as a union alias only when generated code actually uses it
  (`transpiler.v::usings_code`).
- Builtins are not handled ad hoc in visitors when avoidable; route through `plugins.v`
  dispatch and add required imports via `t.add_using(...)`.
- Do not use global variables.
- Do not create const groups.

## Change Workflow
- If behavior depends on semantic context (mutability, inferred annotations, guard rewrites),
  implement in `frontend/ast_dump.py` first.
- Do not use global variables.
  - Avoid module-level mutable state. Prefer adding state as fields on structs (for
    example, on `VTranspiler`) or passing state explicitly through function/method
    parameters. If a constant value is required, use `const` or a zero-argument
    function that returns the value rather than a mutable module-level variable.
- If frontend JSON changes, update both `ast.v` node definitions and `parser.v` parse functions
  together.
- Then adjust codegen in `transpiler.v` and/or builtin translation in `plugins.v`.
- Add or update a fixture pair: `tests/cases/<name>.py` and `tests/expected/<name>.v`.

## Build, Test, and Fixture Update
- Build binary from repo root:
  - `v .`
- Main regression suite (normalizes both sides with `v fmt` before compare):
  - Linux/macOS: `sh tests/run_tests.sh`
  - Windows: `cd tests; ./run_tests.ps1`
- V test file with targeted invariants (line length limit, module naming, super calls,
  exception union alias):
  - `v test py2v_test.v`
- Refresh expected fixtures after intentional output changes:
  - `sh tests/update_expected.sh`

## Debugging Tips
- Repro one case quickly: `./py2v tests/cases/<case>.py`.
- Frontend-only inspect JSON AST: `python3 frontend/ast_dump.py tests/cases/<case>.py`.
- If output diffs are surprising, run through `v fmt` first; test scripts compare normalized
  formatted code, not raw whitespace.

## Agent Guardrails for This Repo
- Add `2>&1` to any command that might produce output to stderr, to ensure all output is captured.
- Keep all markdown lines at 100 characters or fewer in `.md` files, including this file.
- Run `v check-md` on any markdown files you edit to validate line lengths.
- Validate on Linux and local platform when possible (matches existing project guidance in
  `AGENTS.md`).
 - V doc comments use `//` (single-line comments). Do not use `///` - it is not the
   convention in V and causes style mismatches.
- Do not execute ANY git commands.
- Do not create changelog entries. Do not edit `CHANGELOG.md` or create new changelog files.
- Do not create branches. Work in-place on the workspace files provided; do not create
  new VCS branches.
- Do not create pull requests. Do not open or submit PRs from this agent.
- Do not create temporary files inside the repository. If you need temporary files use
  an OS temporary directory (e.g. a subdirectory under `/tmp`).
- Before committing or submitting changes, run `v -check` on every `.v` file to
  validate V syntax.
- Run `v fmt -w .` on every `.v` file after making changes to ensure consistent formatting.
- Run `v vet` on every `.v` file and fix all `v vet` notices and warnings. Treat
  `v vet` output as required: apply safe mechanical fixes (doc comment style,
  unused imports, trivial shadowing) or document why a notice is intentionally
  ignored.
- When compiling V programs during normal development the `-o` option is not
  required; only use `-o` when you need a non-default output path (for example,
  to produce a named binary in CI).

## Quick Examples / Pointers
- Builtins: implement translation in `plugins.v::dispatch_builtin()` and add any
  necessary usings via `t.add_using(...)`.
- Semantic fixes: prefer `frontend/ast_dump.py` for analyses like `v_annotation`.
- Fixtures: each test has a pair under `tests/cases` and `tests/expected`.

Notes:
- Use `v vet` on `.v` files to check syntax before running `v fmt -w .`.
- Use `v vet` and `v -check` outputs captured to a safe temporary location
  (e.g., `/tmp`) if you need to aggregate results — do not create temporary
  files inside the repository.

End of agent rules.
