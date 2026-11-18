# Environment Pinning — renv (audit item 7, closed 2026-11-18)

## State after remediation

- **`renv.lock`** — **207 packages pinned** under **R 4.3.3** (renv 1.3.1), snapshotted
  from the live user library: brms + Stan toolchain, glmmTMB/TMB 1.9.21, tidyverse
  2.0.0 suite, WDI 2.7.10, zoo 1.8-15, broom.mixed, patchwork, writexl, …
- **`renv/`** — `activate.R`, `settings.json`, an empty project library (skeleton
  kept for future adoption).
- **No project `.Rprofile`**: renv auto-activation is **off** (deliberate — see below).
- **`scripts/run_pipeline.R`** pins `options(repos = c(CRAN = "https://cloud.r-project.org"))`
  before its `install.packages()` fallback, so on-demand installs target a stable
  default mirror on any machine.

## Why activation was deactivated (empirical result)

1. `renv::init(bare = TRUE)` creates a `.Rprofile` that redirects every new
   R/Rscript session into `renv/library/` — **empty**, because `bare = TRUE`
   installs nothing.
2. Tested in a fresh process while active: `.libPaths()` showed only
   `renv/library/R-4.3/...` (+ renv sandbox); `requireNamespace("brms")` →
   **FALSE**. Every pipeline run would fail at its first `library()` call.
3. Within the approved "pin versions, **no library install**" scope the
   autoloader was therefore removed with `renv::deactivate()` **after** the
   lockfile write. Post-deactivation test: user library restored
   (`~/R/x86_64-pc-linux-gnu-library/4.3` first in `.libPaths()`);
   brms/glmmTMB/tidyverse → **TRUE**; `renv.lock` intact (207 packages).

Net result: **pinned, not isolated** — the workspace runs exactly as before,
while `renv.lock` records the exact executable environment.

## Verifying the environment against the lock

From the project root (renv is installed in the user library):

```r
library(renv)
renv::status()        # sync report of lockfile vs installed packages
```
As long as installed versions match the lock (they do — the lock was snapshotted
from this library), status reports no desync. To see a single key pin:

```r
packageVersion("brms"); packageVersion("glmmTMB")
```

## Making renv fully "true" later (FR decision)

```r
renv::activate()   # restores the .Rprofile autoloader
renv::hydrate()    # populates renv/library by copying/linking from the user
                   # library — local IO only: no downloads, no compilation
Rscript -e 'requireNamespace("brms", quietly = TRUE)'   # must be TRUE inside
```
`renv::restore()` is the network-based alternative (full download/rebuild;
slower). Both leave `renv.lock` as the source of truth.

## Notes and caveats

- `renv` 1.3.1 itself was bootstrapped from CRAN into the user library
  (~2 MB, pure R) — required to run anything renv-related.
- **`xlsx` is referenced somewhere in the project (outside `scripts/`) but is
  not installed** → it is not in `renv.lock`. If that reference ever becomes
  live, install and re-snapshot deliberately (xlsx pulls in Java).
- `zoo` (1.8-15) is installed and locked.
- Git-wise: `renv/library` is internally git-ignored (`vcs.ignore.library`);
  `renv.lock` / `renv/settings.json` / `renv/activate.R` are the artifacts
  intended for version control. No commit was made (FR decision parked).
- Operational lesson recorded in the session log: run `renv::snapshot()`
  with the session's library path on the REAL library (e.g.
  `Rscript --no-init-file`), otherwise an active empty project library
  produces a useless renv-only lockfile.
