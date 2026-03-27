# Posemesh Architecture

## System Diagram

```
                         ┌─────────────────────────────────────────────────────────┐
                         │             Posemesh Console / DMT App                  │
                         │                console.auki.network                     │
                         └────┬────────────┬───────────────┬───────────────────────┘
                              │            │               │
                         user/org     domain ops       scan upload
                              │            │               │
                              ▼            ▼               │
                    ┌──────────────────────────┐           │
                    │           API            │           │
                    │  (Go · chi · PostgreSQL) │           │
                    │                          │           │
                    │ • users / organisations  │           │
                    │ • apps (key+secret→JWT)  │           │
                    │ • domain metadata        │           │
                    │ • lighthouse metadata    │           │
                    │ • wallet binding         │           │
                    │ • service token issuance │           │
                    └──────────┬───────────────┘           │
                               │ wallet verify             │
                               │                           │
                    ┌──────────▼────────────────────────────────────────────────┐
                    │                          DDS                               │
                    │            (Domain Discovery Service)                      │
                    │                   dds.auki.network                        │
                    │                                                            │
                    │ • issues JWTs (app, domain-scoped, node identity)         │
                    │ • registry of domain server instances                     │
                    │ • routes clients to the correct DS for a domain           │
                    │ • health-checks registered services                       │
                    │ • admin API: issues per-task domain tokens for DMS        │
                    └──────────┬─────────────────────────┬──────────────────────┘
                               │ register / route         │ admin: issue domain tokens
                               │                          │
                               ▼                          │
                    ┌──────────────────────────┐          │
                    │      Domain Server (DS)  │          │
                    │  (Go · chi · PostgreSQL)  │          │
                    │                          │          │
                    │ • domain data blobs       │          │
                    │   (PLY, splat, bbox, raw) │          │
                    │ • lighthouse poses        │          │
                    │ • backup / restore        │          │
                    │ • storage: FS or S3       │          │
                    │ • triggers reconstruction │          │
                    └────┬──────────────────────┘          │
                         │                                 │
                    POST /jobs                             │
                    (app JWT)                              │
                         │                                 │
                         ▼                                 ▼
                    ┌──────────────────────────────────────────────────────────┐
                    │           Domain Manager Service (DMS)                   │
                    │        (Rust · Axum · PostgreSQL)                        │
                    │                                                          │
                    │ • job DAG submission (app JWT)                           │
                    │ • task claim / heartbeat / complete / fail (node token)  │
                    │ • lease sweeper (background, 30 s interval)              │
                    │ • optional credit locking via NCS                        │
                    │ • Prometheus metrics on admin port                       │
                    └────────────────────┬─────────────────────────────────────┘
                                         │
                                claim task / report result
                                         │
                                         ▼
                    ┌──────────────────────────────────────────────────────────┐
                    │               Compute Nodes  ★ public code ★            │
                    │                                                          │
                    │  Reconstruction Server (Python SfM + Rust harness)       │
                    │  ├── posemesh-compute-node  (DDS reg, DMS polling)       │
                    │  ├── runner-reconstruction-local  (local SfM runner)     │
                    │  └── runner-reconstruction-global (global SfM runner)    │
                    │                                                          │
                    │  Splatter Server (Rust harness + Python splatting)       │
                    │  └── COLMAP → nerfstudio/splatfacto training             │
                    │                                                          │
                    │  Python pipelines (both servers)                         │
                    │  ├── hloc / SuperPoint / EigenPlaces (feature matching)  │
                    │  ├── COLMAP (structure-from-motion)                      │
                    │  ├── Ceres + Eigen (bundle adjustment, C++ extension)    │
                    │  ├── Open3D (point cloud processing)                     │
                    │  └── PyTorch + CUDA (deep learning inference)            │
                    └──────────────────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────────────────┐
                    │          Application Layer  ★ public code ★              │
                    │                                                          │
                    │  Domain Viewer (Next.js / Three.js / R3F)               │
                    │  └── browse domains: splats, meshes, portals, points     │
                    │                                                          │
                    │  Domain Spatial Computer (Deno / TypeScript)             │
                    │  └── spatial query API: pathfinding, raycast, navmesh    │
                    │                                                          │
                    │  Pathfinding (TypeScript + Rust / WASM)                  │
                    │  └── hybrid navmesh / graph path planning                │
                    │                                                          │
                    │  Auki Robotics                                           │
                    │  └── robot integration resources                         │
                    └──────────────────────────────────────────────────────────┘
```

> **Note:** Services above the "★ public code ★" line are hosted backend services whose source
> is not included in this workspace. They are documented here for architectural context.
> Services below those lines have source code under `reference-code/`.

---

## Service Responsibilities Matrix

| Concern | API | DS | DMS | Reconstruction Node | Splatter Server |
|---------|-----|----|-----|---------------------|-----------------|
| User identity / auth | ✅ | | | | |
| Organisation management | ✅ | | | | |
| App registration | ✅ | | | | |
| Domain metadata | ✅ | | | | |
| Lighthouse metadata | ✅ | | | | |
| Spatial data storage | | ✅ | | | |
| Lighthouse poses | | ✅ | | | |
| Domain backup/restore | | ✅ | | | |
| Job / task queue | | | ✅ | | |
| Lease management | | | ✅ | | |
| Credit locking | | | ✅ | | |
| SfM reconstruction | | | | ✅ | |
| Gaussian splatting | | | | | ✅ |
| DDS node registration | | ✅ | | ✅ | ✅ |
| JWT issuance | ✅ / DDS | | local (DMS→node) | | |

---

## Data Flows

### Flow 1: User sets up an organisation and app

```
User → POST /user/register (API)      → user created, email verification sent
User → POST /user/login    (API)      → user JWT
User → POST /organizations (API)      → organisation created
User → POST /organizations/{id}/apps  → app created, app_key + app_secret returned
App  → POST /auth          (API)      → app JWT (for downstream service calls)
```

### Flow 2: App creates a domain and uploads scan data

```
App → POST /domains              (API) → domain record created (metadata only)
App → GET domain access token    (DDS) → domain access token (scoped read/write)
App → POST /api/v1/domains/{id}/data  (DS, domain token) → scan blobs stored
App → POST /api/v1/domains/{id}/process (DS, domain token) → triggers reconstruction
```

### Flow 3: Reconstruction pipeline

```
DS   → POST {DMS_URL}/jobs             → job submitted to DMS (DS app JWT)
DMS  → stores job + tasks in Postgres

Node → GET  /tasks?capability=reconstruction_local (DMS, node identity token)
     ← DMS calls DDS admin → domain access token for this task
     ← DMS returns task details + domain access token

Node → GET  /api/v1/domains/{id}/data/* (DS, domain token) → downloads scan data
Node → runs Python SfM pipeline (CPU + GPU)
Node → POST /api/v1/domains/{id}/data/  (DS, domain token) → uploads 3D results
Node → POST /tasks/{id}/complete        (DMS) → task marked done

DMS checks if all tasks in the job are complete → marks job complete
```

### Flow 4: App localises within a domain

```
App → GET domain access token (DDS)  → token scoped to domain, data:read
App → GET /api/v1/domains/{id}/data  (DS) → fetches point cloud / splat / bbox
App uses spatial data for localisation (on-device)
App → PUT /api/v1/domains/{id}/lighthouses/{lhID} (DS, pose:write token) → contributes pose
```

### Flow 5: Spatial queries via Domain Spatial Computer

```
Client → POST /spatial/findpath (DSC, x-api-key) → path between waypoints
DSC    → fetches navmesh from API/DDS for domain
DSC    → computes path on navmesh → returns waypoint list
```

---

## Authentication Architecture

### Token types

| Token | Issuer | Used by | Validated by |
|-------|--------|---------|--------------|
| App JWT | API | Apps → DS, DMS | DS (via API public key), DMS (via DDS) |
| User JWT | API | Users → API | API |
| DDS domain access token | DDS | Apps, DS → DS, Compute nodes → DS | DS (DDS public key) |
| DDS node identity token | DDS | Compute nodes → DMS | DMS (DDS public key) |
| DMS local task token | DMS | Compute nodes ↔ DMS (per task) | DMS |
| Processing token | DS | DS → DS (internal, processing scope) | DS |

### Public key distribution

- DDS public key: fetched from `DDS_SERVICE_PUBLIC_KEY_URL` (PEM), cached with TTL.
- API public key: served at `GET /service/public-key`, fetched and cached by dependent services.

---

## Technology Stack Summary

| Component | Lang | Web framework | Auth | Build |
|-----------|------|---------------|------|-------|
| Reconstruction Server | Python 3 + Rust | — | Bearer tokens (DDS) | CMake + cargo |
| Splatter Server | Rust + Python | — | Bearer tokens (DDS) | cargo |
| Domain Viewer | TypeScript | Next.js 15, React 19, Three.js | — | npm |
| Domain Spatial Computer | TypeScript | Deno HTTP | API key | deno |
| Pathfinding | TypeScript + Rust | Vite (testbed) | — | npm / cargo |
| API (hosted) | Go 1.23 | chi v5 | JWT + Zitadel OIDC | make |
| DS (hosted) | Go 1.23 | chi v5 | JWT + DDS tokens | go build |
| DMS (hosted) | Rust 2021 | Axum | jsonwebtoken | cargo |
