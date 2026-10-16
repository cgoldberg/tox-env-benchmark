# tox-env-benchmark

### Benchmark tox environment provisioning across Git commits

- Copyright (c) 2026 [Corey Goldberg](https://github.com/cgoldberg)
- License:
  [MIT](https://raw.githubusercontent.com/cgoldberg/tox-env-benchmark/refs/main/master/LICENSE)

----

## About

Benchmark [tox](https://tox.wiki/) environment provisioning for Python projects
across two Git commits using [Hyperfine](https://github.com/sharkdp/hyperfine).

This helps identify provisioning performance improvements or regressions caused
by changes to Python dependencies, tox configuration, or package installation.

The script maintains two local working copies of a repository, one for each
commit, and compares three scenarios:

- Existing tox environments with a warm package cache
- Fresh tox environments with a warm package cache
- Fresh tox environments with a cold package cache

Provisioning includes dependency resolution, virtual environment creation, and
package installation, but does not run commands within the environments.

## Requirements

- Bash
- Git
- Hyperfine
- Python
- tox
- uv (optional, used to clear the cache if tox uses uv)

## Usage

```bash
./tox-env-benchmark.sh <repo_url> <old_commit> [new_commit] [branch]
```

#### Arguments

- `repo_url` — Git repository URL
- `old_commit` — Older commit to benchmark
- `new_commit` — Newer commit to benchmark (default: HEAD)
- `branch` — Remote branch to fetch (default: remote's default branch)

#### Examples

```bash
# Compare a commit against HEAD on the default branch
./tox-env-benchmark.sh https://github.com/example/project.git abc123

# Compare two commits on the develop branch
./tox-env-benchmark.sh https://github.com/example/project.git abc123 def456 develop
```

## How it works

The script creates or reuses two local working copies named `<repo-name>-old`
and `<repo-name>-new`. It fetches the specified remote branch and resets each
copy to its target commit. Existing clones are reused between runs.

Hyperfine runs each benchmark three times by default. Package caches and tox
environments are prepared according to the scenario being measured.

### Screenshot

![Screenshot](https://raw.githubusercontent.com/cgoldberg/tox-env-benchmark/refs/heads/main/screenshot.png)
