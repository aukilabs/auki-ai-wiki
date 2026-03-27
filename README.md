# Auki AI Wiki

A wiki for navigating and understanding Auki Labs posemesh projects, with reference source code
included as submodules.

## Documentation

| Document | Audience | Description |
|----------|----------|-------------|
| [AGENTS.md](AGENTS.md) | AI agents | Dense technical reference: service roles, APIs, tokens, inter-service calls |
| [docs/getting-started.md](docs/getting-started.md) | Human developers | Narrative onboarding: what each service does and how to run them locally |
| [docs/architecture.md](docs/architecture.md) | Both | System diagrams, data flows, auth architecture, port/config reference |

## Prerequisites

| Tool | Version | Needed for | Install |
|------|---------|------------|---------|
| `just` | any | Repo tooling (required) | `brew install just` or `cargo install just` |
| `git` | >= 2.30 | All repos (required) | Ships with Xcode / system package manager |
| `gh` | any | `just pr` command | `brew install gh` or [cli.github.com](https://cli.github.com) |
| Rust | stable (2021 edition) | Reconstruction Server, Splatter Server, Pathfinding | [rustup.rs](https://rustup.rs) |
| Python | 3.10+ | Reconstruction Server, Splatter Server | `brew install python` or system |
| Node.js | 18+ | Domain Viewer, Pathfinding testbed | `brew install node` or [nodejs.org](https://nodejs.org) |
| Deno | latest | Domain Spatial Computer | [docs.deno.com](https://docs.deno.com/runtime/getting_started/installation) |
| Docker | Desktop or Engine + Compose | GPU compute nodes, integration tests | [docker.com](https://www.docker.com/products/docker-desktop/) |

> You don't need everything — install only what the repos you're working on require.

## Getting Started

Clone the repo and pull all submodules in one step:

```bash
git clone --recurse-submodules https://github.com/aukilabs/ai-wiki
```

If you already cloned without submodules, initialise and fetch them:

```bash
git submodule update --init --recursive
```

## Workspace Commands

This repo uses [`just`](https://github.com/casey/just) to provide a monorepo-like experience
across all submodules. Run `just` to see all available commands.

```bash
just status                     # branch + dirty state across all repos
just branch feat/my-feature     # checkout/create branch everywhere
just sync                       # pull latest from remote
just add                        # stage changes in all dirty repos
just commit "feat: thing"       # commit across repos (or just commit for interactive)
just push                       # push only repos with unpushed commits
just pr                         # create PRs for pushed feature branches
just prune                      # clean up merged branches
just log                        # recent commits across all repos
just diff                       # uncommitted diffs
```

## Reference Code

Public source repos are checked out under `reference-code/`:

| Folder | Repository | Description |
|--------|------------|-------------|
| `reference-code/posemesh` | [aukilabs/posemesh](https://github.com/aukilabs/posemesh) | Posemesh protocol and SDK entrypoint |
| `reference-code/reconstruction-server` | [aukilabs/reconstruction-server](https://github.com/aukilabs/reconstruction-server) | Compute node: SfM 3D reconstruction pipeline |
| `reference-code/splatter-server` | [aukilabs/splatter-server](https://github.com/aukilabs/splatter-server) | Compute node: Gaussian splatting pipeline |
| `reference-code/domain-viewer` | [aukilabs/domain-viewer](https://github.com/aukilabs/domain-viewer) | Web 3D viewer for domains (splats, meshes, portals) |
| `reference-code/domain-spatial-computer` | [aukilabs/domain-spatial-computer](https://github.com/aukilabs/domain-spatial-computer) | Spatial HTTP API: pathfinding, raycast, navmesh ops |
| `reference-code/pathfinding` | [aukilabs/pathfinding](https://github.com/aukilabs/pathfinding) | Hybrid navmesh/graph pathfinding library |
| `reference-code/auki_robotics` | [aukilabs/auki_robotics](https://github.com/aukilabs/auki_robotics) | Resources for robotics integration |

## Hosted Services (not included as source)

Several backend services power the posemesh but are not included as reference code in this
repository. They are documented in `AGENTS.md` and `docs/architecture.md` for context:

| Service | Production URL | Role |
|---------|---------------|------|
| API | `api.auki.network` | User/org/app management, JWT issuance |
| DDS | `dds.auki.network` | Trust authority, domain routing, node registry |
| Domain Server (DS) | Operator-hosted | Spatial data storage (point clouds, splats, poses) |
| DMS | `dms.auki.network` | Compute job queue and task orchestrator |
| NCS | Internal | Credit ledger, DAU pricing, token economics |
| Console | `console.auki.network` | Web dashboard for managing posemesh resources |

## Adding a New Reference Repo

```bash
just add-repo https://github.com/aukilabs/<repo-name>
# or with a custom folder name:
just add-repo https://github.com/aukilabs/<repo-name> custom-name
```
