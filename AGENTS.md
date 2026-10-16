# Posemesh — AI Agent Reference

This document is the primary context file for AI agents working on Auki Labs posemesh repositories.
Read this first before exploring any service's code.

---

## What is the Posemesh?

The **posemesh** is a decentralised spatial computing network. It lets apps share persistent 3D
coordinate systems — called **domains** — so multiple devices and AI agents can agree on where
things are in physical space. Domains are created by scanning a physical space with the Domain
Management Tool (DMT) iOS app, processing those scans with computer vision, and storing the
resulting 3D map on a **domain server**.

---

## Repos in This Workspace

This workspace contains **public** reference code as git submodules under `reference-code/`.

| Folder | Language | Role |
|--------|----------|------|
| `reference-code/posemesh` | Rust / multi-platform | Posemesh protocol and SDK entrypoint |
| `reference-code/reconstruction-server` | Python + Rust | Compute node: SfM 3D reconstruction from scan data |
| `reference-code/splatter-server` | Rust + Python | Compute node: Gaussian splatting pipeline |
| `reference-code/domain-viewer` | TypeScript (Next.js / React / Three.js) | Web 3D viewer for domains: splats, meshes, portals, point clouds |
| `reference-code/domain-spatial-computer` | TypeScript (Deno) | Spatial HTTP API: pathfinding, raycast, navmesh projection, cross-sections |
| `reference-code/pathfinding` | TypeScript + Rust | Hybrid navmesh/graph pathfinding library with WASM testbed |
| `reference-code/auki_robotics` | N/A (index) | Curated links to robotics integration repositories |

---

## Example Projects

Before building something new, read a working project and copy its patterns.

### Main example: Domain Harness — https://github.com/aukilabs/domain-harness

A component-based spatial mapping prototype on the Auki SDK (Rust). A **Home** server builds a
canonical scene from calibrated peer observations and serves a Three.js viewer; **Bracketbot
runners** localize against portals and stream poses, cameras and voxel maps; an **iPhone
Annotator** (Swift/ARKit + Rust SDK bridge) aligns to a portal, places persistent annotations and
contributes LiDAR depth. Peers communicate over authenticated SDK Component protocols. Use it as
the end-to-end reference for networking, calibration and live spatial data.

Demo video (multiple phones and robots mapping a scene together in real time):
https://x.com/broodsugar/status/2110905187896529081

### Floorcraft: Blasters — https://github.com/matterless/floorcraft-blasters

Source of Floorcraft (https://www.auki.com/solutions/software/floorcraft), a multiplayer
shared-AR racing game in Unity — scan a QR code to join friends' arena in the same physical space.
**Built on the deprecated ConjureKit Unity SDK**: use it as a reference for shared-AR gameplay and
QR session joining, not as the SDK to start new work on.

### Helper repos and other examples

| Repo | Use it for |
|------|------------|
| https://github.com/aukilabs/auki-sdk | The SDK — helper functions, tools and docs for networking, calibration, marker detection, etc. |
| https://github.com/aukilabs/qr-lab | Just the QR code tooling |
| https://github.com/aukilabs/pnp-lab | Helpers for PnP calibration |
| https://github.com/aukilabs/experimental-modules | Authentication helpers — use the App Key / Secret from the console |
| https://github.com/aukilabs/domain-viewer | Example 3D web viewer for domain data |
| https://github.com/aukilabs/auki_robotics | Index of robotics integrations (general robots and Unitree G1) |
| https://github.com/aukilabs/auki_robotics_domain_calibrator | Calibrate a robot into a domain |
| https://github.com/aukilabs/auki_robotics_map_utils | Robot map utilities |
| https://github.com/aukilabs/auki_robotics_g1_humanoid_ros2 | Unitree G1 humanoid ROS 2 integration |
| https://github.com/aukilabs/domain-spatial-computer | Spatial queries on domain data — pathfinding, raycast, navmesh projection |
| https://github.com/aukilabs/pathfinding | Navmesh/graph pathfinding library |

---

## Hosted Services (source not included)

The following backend services are **not** checked out in this workspace but are documented here
for architectural context. Agents should understand how the public repos interact with them.

| Service | Production URL | Language | Role |
|---------|---------------|----------|------|
| **API** | `api.auki.network` | Go | Identity layer: users, orgs, apps, domain metadata, JWTs |
| **DDS** (Domain Discovery Service) | `dds.auki.network` | Go | Trust authority: JWT issuance, domain server registry, routing |
| **Domain Server (DS)** | Operator-hosted | Go | Spatial data layer: stores 3D domain data & lighthouse poses |
| **DMS** (Domain Manager Service) | `dms.auki.network` | Rust | Compute orchestrator: job queue for reconstruction tasks |
| **NCS** (Network Credit Service) | Internal | Go | Financial layer: credit ledger, DAU pricing, token economics |
| **Console** | `console.auki.network` | TypeScript/React | Web dashboard: org/app/domain/node management UI |

### DDS (Domain Discovery Service)

DDS is the central trust authority of the posemesh. It runs in production at `dds.auki.network`.

- Issues signed JWTs (domain access tokens, service tokens, node identity tokens via SIWE wallet auth).
- Maintains a registry of domain server instances; health-checks them via background jobs.
- Routes clients to the correct domain server for a given domain (`POST /api/v1/domains/{id}/auth`).
- Manages node and server registration (both domain servers and compute nodes).
- Owns domain and lighthouse records at the discovery layer (CRUD, transfers, access control).

Every other service validates DDS-signed JWTs. The public signing key is served at
`GET /service/public-key` and `GET /service/public-key.pem`, fetched and cached by each consumer.

### API

User and resource ownership management: registration, login, organisations, apps
(`app_key` + `app_secret` → JWT via `POST /auth`), domain metadata, lighthouse metadata,
wallet binding (EVM), and service token issuance.

### Domain Server (DS)

Stateful spatial data server. Stores domain data blobs (point clouds, gaussian splats,
bounding boxes), lighthouse poses, supports backup/restore, and triggers reconstruction
by submitting jobs to DMS.

### Domain Manager Service (DMS)

Job queue and task orchestrator. Models work as a DAG of tasks. Accepts job submissions
from any authorized app via DDS-signed app JWTs. Compute nodes claim tasks, heartbeat to
extend leases, and mark complete/failed. Issues per-task domain access tokens via DDS admin API.

### Network Credit Service (NCS)

Financial backbone: $AUKI credit ledger, credit locks/debits for compute jobs,
participation rewards, DAU receipts, token economics (price oracle, supply, burns).

---

## Architecture

```
 ┌────────────────────────────────────────────────────────────────┐
 │          Console (React SPA)  console.auki.network             │
 │  • org / app / domain / lighthouse / server management UI      │
 │  • credit balance, DAU, staking, NFTs via blockchain (Wagmi)   │
 └──┬──────────────┬───────────────────┬──────────────────────────┘
    │ auth/crud     │ credits/DAU        │ domains/servers
    ▼               ▼                   ▼
 ┌─────────┐  ┌──────────────┐  ┌──────────────────────────────────┐
 │   API   │  │     NCS      │  │  DDS (Domain Discovery Service)  │
 │  (Go)   │  │    (Go)      │  │  dds.auki.network                │
 │         │◄─┤  credits &   │  │                                  │
 │ users   │  │  token econ  │  │  • issues JWTs                   │
 │ orgs    │  │  DAU pricing │  │  • domain server registry        │
 │ apps    │  │  locks/debit │  │  • routes clients to correct DS  │
 │ domains │  │  grants      │  │  • node/server registration      │
 │ l.houses│  │  receipts    │  │  • domain + lighthouse records   │
 └────┬────┘  └──────┬───────┘  │  • background healthcheck jobs   │
      │ wallet       │ DAU/      └─────────────────┬────────────────┘
      │ verify       │ receipt                      │ routes + healthchecks
      └──────────────▼                              ▼
                    DDS ◄───────────────  Domain Server (DS)
                                          • stores 3D spatial data
                                          • stores lighthouse poses
                                          • triggers reconstruction jobs ─►
                                          • registered with DDS on startup
                                                    │ POST /jobs  (app JWT)
                                                    ▼
                                          Domain Manager Service (DMS)
                                          • any authorized app submits jobs
                                          • compute nodes claim tasks
                                          • issues per-task domain tokens
                                          • sweeps expired leases
                                                    │ claim → complete
                                                    ▼
                                          ┌─────────────────────────────┐
                                          │  Compute Nodes (public code)│
                                          │  • Reconstruction Server    │
                                          │  • Splatter Server          │
                                          │  • polls DMS for tasks      │
                                          │  • runs SfM / splatting     │
                                          │  • downloads/uploads on DS  │
                                          └─────────────────────────────┘

                    ┌──────────────────────────────────────────────────┐
                    │  Application-Layer (public code)                  │
                    │  • Domain Viewer — browse domains in browser      │
                    │  • Domain Spatial Computer — spatial query API    │
                    │  • Pathfinding — navmesh/graph path planning      │
                    │  • Auki Robotics — robot integration resources    │
                    └──────────────────────────────────────────────────┘
```

---

## Public Repo Details

### 1. Posemesh (`reference-code/posemesh`)

Master resource for the open-source posemesh project. Contains protocol documentation,
contributor conventions (WebKit C++ style, Conventional Commits), SDK pointers, and
community links. Start here to understand the overall vision and contribution guidelines.

- **Repository:** [aukilabs/posemesh](https://github.com/aukilabs/posemesh)

---

### 2. Reconstruction Server (`reference-code/reconstruction-server`)

**Languages:** Python 3 (SfM pipeline) + Rust (compute node harness)
**GPU:** NVIDIA CUDA required (≥ 8 GiB VRAM)

**Purpose:** Compute node that processes raw scans into 3D representations of physical spaces.

**Architecture:**
```
compute-node (Rust binary)
 ├── posemesh-compute-node crate   # DDS registration, DMS task polling, lifecycle
 ├── runner-reconstruction-local   # Rust runner: invokes Python for local refinement
 └── runner-reconstruction-global  # Rust runner: invokes Python for global refinement
        │
        └── Python pipeline (main.py / local_main.py / global_main.py)
             ├── hloc              # image matching / feature extraction
             ├── COLMAP            # structure-from-motion
             ├── Open3D            # point cloud processing
             ├── PyTorch           # deep learning models (EigenPlaces, etc.)
             └── Ceres / Eigen     # bundle adjustment (C++ extension)
```

**Processing types:**
- `local_refinement` — refines a single scan (per-session SfM).
- `global_refinement` — merges multiple scans into a unified map.
- `local_and_global_refinement` — both in sequence.

**Task flow:**
1. Node registers with DDS using `REG_SECRET` + `SECP256K1_PRIVHEX`.
2. Rust engine polls DMS (`GET /tasks?capability=reconstruction_*`).
3. Claims a task, receives a domain access token from DMS (issued by DDS admin).
4. Downloads scan data from DS using the domain access token.
5. Runs Python SfM pipeline.
6. Uploads results (PLY point cloud, gaussian splat, bounding box) back to DS.
7. Calls `POST /tasks/{id}/complete` on DMS.

**Required credentials (`.env`):**
```
REG_SECRET=<from Posemesh Console, Manage Nodes>
SECP256K1_PRIVHEX=<hex EVM private key of staked wallet>
```

**Running (production):**
```bash
docker pull aukilabs/reconstruction-node:stable
docker run --gpus all --shm-size 512m --env-file .env -d aukilabs/reconstruction-node:stable
```

**Dev container:** Open in VS Code/Cursor → "Dev Containers: Reopen in Container".
The post-create script builds C++ and Rust components automatically.

> This service has its own agent instructions at
> `reference-code/reconstruction-server/AGENTS.md` if present.

---

### 3. Splatter Server (`reference-code/splatter-server`)

**Languages:** Rust (service harness) + Python (Gaussian splatting training)
**GPU:** NVIDIA CUDA required

**Purpose:** Compute node that runs Gaussian splatting (COLMAP → nerfstudio/splatfacto-style
training) as part of the reconstruction pipeline. Registers with DDS and polls DMS for
splatting tasks, similar to the reconstruction server.

- **Repository:** [aukilabs/splatter-server](https://github.com/aukilabs/splatter-server)

---

### 4. Domain Viewer (`reference-code/domain-viewer`)

**Language:** TypeScript · **Framework:** Next.js 15, React 19, Three.js / React Three Fiber · **UI:** Tailwind CSS, Jotai, React Query

**Purpose:** Web application to explore posemesh domains in 3D. Renders point clouds,
navigation/occlusion meshes, portals, and Gaussian splats. Supports FPS camera mode.
Loads domain data from API / DDS / DS backends.

- **Repository:** [aukilabs/domain-viewer](https://github.com/aukilabs/domain-viewer)

**Local dev:**
```bash
cd reference-code/domain-viewer
npm install
npm run dev
```

---

### 5. Domain Spatial Computer (`reference-code/domain-spatial-computer`)

**Language:** TypeScript · **Runtime:** Deno

**Purpose:** High-performance spatial computing API providing pathfinding, raycasting,
navigation mesh projection, and cross-section generation for 3D environments. Connects
to Auki API/DDS backends for domain data. Protected by API key (`x-api-key` header).

- **Repository:** [aukilabs/domain-spatial-computer](https://github.com/aukilabs/domain-spatial-computer)

**Key endpoints:**
```
GET  /ping                        # health check (no auth)
POST /spatial/findpath            # find path between waypoints
POST /spatial/findoptimizedpath   # optimized path with route optimization
POST /spatial/restricttonavmesh   # restrict point to navigation mesh
POST /spatial/raycast             # raycast against occlusion geometry
POST /spatial/crosssection        # generate 2D cross-section maps
```

**Local dev:**
```bash
cd reference-code/domain-spatial-computer
touch .env   # add AUKI_APP_KEY, AUKI_APP_SECRET, DSC_API_KEY
deno task dev
deno test
```

---

### 6. Pathfinding (`reference-code/pathfinding`)

**Languages:** TypeScript (npm package `auki-pathfinding-js`) + Rust (`auki-pathfinding-rs`)
**Testbed:** React + Vite WASM app

**Purpose:** Hybrid graph + navmesh pathfinding library for navigation and robotics.
Uses earcut triangulation and recast-navigation-js. The TypeScript package can be used
directly in browser/Node environments; the Rust crate compiles to WASM.

- **Repository:** [aukilabs/pathfinding](https://github.com/aukilabs/pathfinding)

---

### 7. Auki Robotics (`reference-code/auki_robotics`)

**Purpose:** Curated collection of resources and links for integrating robots with the
posemesh — includes pointers to map utilities, Unitree G1 ROS2 integration, and Padbot
robot integration repositories.

- **Repository:** [aukilabs/auki_robotics](https://github.com/aukilabs/auki_robotics)

---

## Key Concepts

| Term | Definition |
|------|-----------|
| **Domain** | A persistent 3D coordinate frame anchored to a physical space. Has an ID, name, and lives on a DS instance. |
| **Lighthouse** | A named 6-DOF pose within a domain, used for localization. Metadata in API, actual pose in DS. |
| **Domain data** | Arbitrary blobs attached to a domain: point clouds, splats, raw scan images, etc. Stored in DS. |
| **DDS token** | A JWT issued by DDS. App access tokens allow managing orgs/domains. Domain access tokens are scoped to a specific domain and resource (data/pose, read/write). Node identity tokens identify compute nodes. |
| **App** | A registered client with `app_key` + `app_secret`. Obtains a bearer JWT from `POST /auth` on the API. |
| **Job / Task** | DMS concepts. A Job is a unit of compute work, broken into Tasks (nodes in the DAG). Compute nodes claim and execute Tasks. |
| **NCS** | Network Credit Service — $AUKI credit ledger, DAU pricing, participation rewards. DMS calls its admin API to lock/debit credits per job. |
| **DAU** | Daily Active User — an app submits a DAU receipt to NCS when a user interacts with a domain; NCS debits credits at the configured price. |
| **Credit lock** | A temporary credit hold created by DMS on NCS when a job starts. Released if the job is cancelled; debited on completion. |
| **MAC Address** | A device MAC address associated with a domain for discovery. Stored on DDS. Not globally unique — same MAC can appear in multiple domains. |

---

## Token Flow

```
1. App auth:
   App → POST /auth (API) → API-signed JWT

2. Domain access:
   App JWT → POST /service/domains-access-token (API) → DS access token (API-signed)
   OR
   User/App → DDS token endpoint → DDS-signed domain access token

3. Node identity:
   Compute node registers with DDS → DDS issues node identity token
   DMS validates this token on task endpoints

4. Per-task domain token:
   Compute node claims task → DMS calls DDS admin → returns domain access token
   Node uses this token to read/write domain data on DS
```

---

## Inter-Service Calls

| Caller | Callee | Purpose |
|--------|--------|---------|
| Console | API | Auth, org/app/domain/lighthouse management |
| Console | NCS | Credit balance, grants, DAU averages |
| Console | DDS | Domain v2 / portal / server queries |
| Console | Ethereum | Staking, NFT, token contracts (via Wagmi) |
| API | DDS | Wallet binding verification |
| DS | DDS | Node registration + re-registration on startup |
| Any authorized app (DS, client apps, etc.) | DMS | `POST /jobs` — job submission with task `inputs_cids` as DS data URLs (DDS app JWT) |
| DDS | DS | Healthcheck pings, lighthouse size sync, domain deletion |
| DDS | NCS | Domain server / compute participation aggregation |
| DMS | DDS admin | Issue per-task domain access tokens for compute nodes |
| DMS | NCS admin | Create credit lock on job start; debit on completion; release on cancel |
| Reconstruction Node | DDS | SIWE wallet auth → node identity token |
| Reconstruction Node | DMS | Claim tasks, heartbeat, complete/fail |
| Reconstruction Node | DS | Download scan data, upload 3D results |
| Splatter Server | DDS / DMS / DS | Same pattern as reconstruction node for splatting tasks |
| Domain Viewer | API / DDS / DS | Load domain data for 3D rendering |
| Domain Spatial Computer | API / DDS | Fetch domain data for spatial queries |

---

## Working in This Repo

This repo uses `just` (a command runner) to provide a monorepo-like experience across git
submodules. All commands operate on the parent repo **and** all submodules simultaneously.

### Prerequisites

| Tool | Version | Required by | Install |
|------|---------|-------------|---------|
| `just` | any | Repo tooling | `brew install just` / `cargo install just` |
| `git` | ≥ 2.30 | All repos | Ships with Xcode / system package manager |
| `gh` | any | `just pr` | `brew install gh` / [cli.github.com](https://cli.github.com) |
| Rust | stable (2021 edition) | Reconstruction Server, Splatter Server, Pathfinding | [rustup.rs](https://rustup.rs) |
| Python | 3.10+ | Reconstruction Server, Splatter Server | `brew install python` / system |
| Node.js | 18+ | Domain Viewer, Pathfinding testbed | `brew install node` / [nodejs.org](https://nodejs.org) |
| Deno | latest | Domain Spatial Computer | [docs.deno.com](https://docs.deno.com/runtime/getting_started/installation) |
| Docker | Desktop or Engine + Compose | GPU compute nodes, integration tests | [docker.com](https://www.docker.com/products/docker-desktop/) |

> Not all tools are needed for every submodule. If you're only working on one repo, install
> only what it requires (see the per-repo sections above).

### Workspace Commands

Use `just` to run commands across all repos. Run `just` with no arguments to see all available recipes.

**Branching & navigation:**

```bash
just status                     # show branch + dirty state across all repos
just branch feat/my-feature     # checkout/create branch in all repos
just sync                       # fetch + pull --ff-only everywhere
just log                        # last 5 commits per repo (just log 10 for more)
just diff                       # uncommitted diffs across all repos
```

**Staging, committing, pushing:**

```bash
just add                        # git add -A in all dirty repos
just commit "feat: my feature"  # same commit message across all repos with staged changes
just commit                     # interactive: per-repo diff preview + commit message prompt
just push                       # push only repos with unpushed commits
just pr                         # create GitHub PRs for repos with pushed feature branches
```

**Maintenance:**

```bash
just prune                      # delete local branches whose remote was merged & deleted
just add-repo <url>             # add a new GitHub repo as a submodule
```

### Important Notes for Agents

- **Detached HEAD:** `just status` shows `(detached!)` as a warning. Use `just branch <name>`
  to get onto a named branch — it uses `--track` to prevent detached HEAD on remote branches.
- **Branch scope:** `just branch` creates the branch in **all** submodules, but `commit`,
  `push`, and `pr` only operate on repos with actual changes.
- **Staged changes:** `just commit` operates on **staged** changes only. Run `just add` first
  or stage files manually with `git add`.
- **PR creation:** `just pr` uses `gh pr create --fill` and requires `gh` to be authenticated
  (`gh auth login`).
- **Default branches vary:** The parent repo defaults to `develop`. Most submodules default to
  `main` or `develop` — check each repo.

---

## Adding a New Service

To add another repo as reference code:
```bash
just add-repo https://github.com/aukilabs/<repo-name>
```

Then document it in this file under "Repos in This Workspace" and in `docs/architecture.md`.
