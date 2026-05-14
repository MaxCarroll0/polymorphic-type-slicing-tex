# Polymorphic Type Slicing

This repository contains my Part III (Cambridge) dissertation on **polymorphic type slicing** for bidirectional, gradually-typed languages. It is a companion to a mechanisation in Agda: see [hazel-type-slicing-formalism](https://github.com/MaxCarroll0/hazel-type-slicing-formalism) for the machine-checked formal proofs.

Related work by the same author:
- HATRA paper, *Type Slicing for Hazel* — [hazel-type-slicing-paper](https://github.com/MaxCarroll0/hazel-type-slicing-paper).
- Previous (Part II) dissertation, *Type Error Debugging in Hazel* — [PDF](https://github.com/MaxCarroll0/Type-Error-Debugging-in-Hazel---Dissertation/blob/main/dissertation.pdf).

---

## Build instructions

Install Nix with flakes if you don't have it:

```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Then build the flake:

```
nix build github:MaxCarroll0/polymorphic-type-slicing-tex
```

Produces `result/PolymorphicTypeSlicing.pdf`.

Alternatively, clone the repo and run `nix build` within.

### Additional Formats

The `-no-marginpars` variants strip margin annotations for clean prose.

Invocation: `nix build .#<target>` (or `nix build github:MaxCarroll0/polymorphic-type-slicing-tex#<target>` remotely).

| Target                 | Output                                                            |
|------------------------|-------------------------------------------------------------------|
| `pdf` (default)        | PDF (lualatex via latexmk)                                        |
| `html`                 | standalone HTML with inline MathML                                |
| `txt`                  | pandoc plain text                                                 |
| `org`                  | pandoc org-mode                                                   |
| `md`                   | GitHub-flavoured markdown                                         |
| `html-no-marginpars`   | HTML with annotations stripped                                    |
| `all`                  | symlinkJoin: PDF + every format                                   |
| `all-no-marginpars`    | symlinkJoin: PDF + every format, no annotations                   |

Per format: `txt`, `org`, `md`, `html`, each with a `-no-marginpars` suffix.

Each build writes its artefact to `./result/` (override with `nix build .#<target> -o <dir>`).

### Customised build with `nix run`

For everything below, invoke as, with config FLAGS:

```
nix run github:MaxCarroll0/polymorphic-type-slicing-tex#build -- [FLAGS…]
```

#### Output-format flags

| Flag             | Effect                                         |
|------------------|------------------------------------------------|
| `--txt`          | also build plain text                          |
| `--org`          | also build org-mode                            |
| `--md`           | also build markdown                            |
| `--html`         | also build standalone HTML (inline MathML)     |
| `--all`          | shorthand for `--txt --org --md --html`        |
| `--no-marginpars`| strip margin mechanisation notes               |
| `--everything`   | shorthand for `--all --theorems all --figures` |

#### Theorem reference

A separate auto-generated document listing every theorem, lemma, proposition, corollary, conjecture and counterexample in the dissertation, restated with its full body, mechanisation status and the corresponding *lemma name* and source *file* in the Agda mechanisation.

| Flag                            | Effect                                                                         |
|---------------------------------|--------------------------------------------------------------------------------|
| `--theorems` / `--theorems all` | theorems / lemmas / propositions / corollaries / conjectures / counterexamples |
| `--theorems important`          | only *major* theorems                                                          |
| `--theorems counterexamples`    | only counterexamples                                                           |

Output: `./PolymorphicTypeSlicing/Reference/theorem-reference.pdf` (+ `theorem-reference.<fmt>` siblings for each requested format, in `Reference/no-marginpars/` when `--no-marginpars` is set). All other flags (`--include`, `--exclude`, `--no-marginpars`, `--html`, …) compose with this, so you can generate this in any supported file format.

#### Figures

Each `\begin{figure}` block in the included sections is also extracted as an individual SVG into `./PolymorphicTypeSlicing/Figures/<section>-fig<n>.svg`. Useful for embedding individual diagrams into talks, slides, or other documents.

| Flag           | Effect                                  |
|----------------|-----------------------------------------|
| `--figures`    | extract per-figure SVGs (default on)    |
| `--nofigures`  | skip figure extraction                  |


#### Selecting sections

Build a subset of the dissertation, useful for chapter-by-chapter review or for extracting just the formal sections. The kept sections drive the rest of the pipeline (PDF, pandoc formats, theorem reference, figures).

| Flag                       | Effect                                                  |
|----------------------------|---------------------------------------------------------|
| `--include ID,ID,…`        | build only the listed sections                          |
| `--exclude ID,ID,…`        | build everything except the listed sections             |

Section IDs:

| ID                  | Section                                              |
|---------------------|------------------------------------------------------|
| `FRONTMATTER` / `0` | Title page and abstract                              |
| 1                   | Introduction                                         |
| 2                   | Explanation by Example                               |
| 3                   | Background                                           |
| 4                   | The Core Calculus                                    |
| 5                   | Synthesis Slices                                     |
| 6                   | Analysis Slices                                      |
| 7                   | Error Marking & Type Error Debugging                 |
| 8                   | Algorithms                                           |
| 9                   | Complexity of Minimum-Size Slicing                   |
| 10                  | Relation to Other Forms of Slicing                   |
| 11                  | Conclusions                                          |
| `BIB`               | Bibliography                                         |
| `A`                 | Appendix — Marked Context Classification             |
| `B`                 | Appendix — Bounded Synthesis Slices                  |
