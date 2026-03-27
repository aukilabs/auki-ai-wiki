# Getting Started with Posemesh Development

This guide walks you through the posemesh from a developer's perspective — what
each component does, how they fit together, and how to get the public reference code running.

---

## The Big Picture

The posemesh lets devices and AI agents share a common understanding of 3D space. A "domain" is
a persistent 3D map of a physical location — think a room, a building floor, or an outdoor area.
Apps use domains to anchor virtual objects to real-world positions that multiple users can see in
the same place.

Creating a domain involves:
1. Scanning the space with the **Domain Management Tool** (DMT) iOS app.
2. Uploading the scan data to a **Domain Server** (DS) instance.
3. Running a computer-vision pipeline (**Reconstruction Server**) to build a 3D map.
4. Storing the resulting map back on the DS.

Once a domain exists, apps can query it for spatial data, contribute new lighthouse poses
(anchor points for localization), compute navigation paths, and more.

---

## What's in This Workspace

This workspace contains **public** reference code under `reference-code/`. Several backend
services (API, DDS, DS, DMS, NCS, Console) are hosted but their source is not included here.
See [AGENTS.md](../AGENTS.md) for full architectural context of those hosted services.

### Public Repos (source included)

#### Posemesh Protocol
The master resource for the open-source posemesh project — protocol documentation,
contributor conventions, SDK pointers, and community links.

- **Repo:** `reference-code/posemesh`
- **Repository:** [aukilabs/posemesh](https://github.com/aukilabs/posemesh)

#### Reconstruction Server
Compute node that processes raw scans into 3D representations. Runs a structure-from-motion
(SfM) pipeline on scan data and uploads results (point clouds, splats, bounding boxes) to DS.

- **Technology:** Python (SfM pipeline) + Rust (task harness), NVIDIA CUDA required
- **Repo:** `reference-code/reconstruction-server`
- **Runs on:** any machine with a compatible NVIDIA GPU (≥ 8 GiB VRAM)

#### Splatter Server
Compute node that runs Gaussian splatting (COLMAP → nerfstudio/splatfacto-style training).
Same DDS/DMS integration pattern as reconstruction server.

- **Technology:** Rust (service) + Python (training pipeline), NVIDIA CUDA required
- **Repo:** `reference-code/splatter-server`

#### Domain Viewer
Web application to explore posemesh domains in 3D — renders point clouds, navigation/occlusion
meshes, portals, and Gaussian splats. Supports FPS camera mode.

- **Technology:** TypeScript, Next.js 15, React 19, Three.js / React Three Fiber
- **Repo:** `reference-code/domain-viewer`

#### Domain Spatial Computer
High-performance spatial computing API providing pathfinding, raycasting, navigation mesh
projection, and cross-section generation for 3D environments.

- **Technology:** TypeScript, Deno
- **Repo:** `reference-code/domain-spatial-computer`

#### Pathfinding
Hybrid graph + navmesh pathfinding library for navigation and robotics. Includes a TypeScript
npm package, a Rust crate, and a React + Vite WASM testbed.

- **Technology:** TypeScript + Rust
- **Repo:** `reference-code/pathfinding`

#### Auki Robotics
Curated collection of resources for integrating robots with the posemesh.

- **Repo:** `reference-code/auki_robotics`

### Hosted Services (source not included)

| Service | Role | Production URL |
|---------|------|---------------|
| **API** | User/org/app management, JWT issuance | `api.auki.network` |
| **DDS** | Trust authority, domain routing, node registry | `dds.auki.network` |
| **Domain Server (DS)** | Spatial data storage (point clouds, splats, poses) | Operator-hosted |
| **DMS** | Compute job queue and task orchestrator | `dms.auki.network` |
| **NCS** | Credit ledger, DAU pricing, token economics | Internal |
| **Console** | Web dashboard for managing posemesh resources | `console.auki.network` |

---

## How the Services Connect

```
DMT app scans a space
        │
        │  upload scan data
        ▼
  Domain Server (DS)
        │
        │  POST /jobs  ──►  Domain Manager Service (DMS)
        │                          │
        │                          │  task available
        │                          ▼
        │                  Compute Nodes (★ public code)
        │                  • Reconstruction Server
        │                  • Splatter Server
        │                  (claim task from DMS,
        │                   download scan from DS,
        │                   run SfM / splatting pipeline,
        │◄──────────────────upload 3D map to DS)
        │
        ▼
  3D domain data stored
        │
        ├──►  Domain Viewer — browse in browser
        ├──►  Domain Spatial Computer — spatial queries
        └──►  Apps localise within the domain
```

**Authentication at each hop:**

| Step | Token type |
|------|-----------|
| App → API | App key + secret → API-issued JWT |
| App/DS → DDS | App JWT → DDS-signed domain access token |
| DS → DMS | App JWT (DS acts as an app) |
| DMS → DDS admin | Service-to-service (DMS issues per-task tokens) |
| Compute Node → DDS | Node registers with `REG_SECRET` → node identity token |
| Compute Node → DMS | Node identity token (DDS-signed) |
| Compute Node → DS | Domain access token (issued by DDS admin via DMS) |

---

## Running Public Repos Locally

### Prerequisites

All GPU-dependent repos need Docker. Install Docker from https://www.docker.com/get-started.

### Reconstruction Server

Requires an NVIDIA GPU with ≥ 8 GiB VRAM and CUDA 12.8+.

**Option 1 — Docker (recommended):**
```bash
# Create .env file:
cat > .env <<EOF
REG_SECRET=<from Posemesh Console → Manage Nodes>
SECP256K1_PRIVHEX=<hex private key of staked EVM wallet>
EOF

docker pull aukilabs/reconstruction-node:stable
docker run --gpus all --shm-size 512m --env-file .env \
  --name reconstruction-node -d aukilabs/reconstruction-node:stable

# Verify:
docker logs reconstruction-node   # should show DDS registration + DMS polling
docker exec reconstruction-node nvidia-smi
```

**Option 2 — Dev container:**
1. Open `reference-code/reconstruction-server` in VS Code or Cursor.
2. Command Palette → **Dev Containers: Reopen in Container**.
3. The post-create script builds C++ extensions and the Rust binary automatically.
4. Create `.env`, then inside the container:
   ```bash
   source .devcontainer/apply_env_file.sh
   ./compute-node
   ```

**Getting credentials:**
1. Log in at https://console.auki.network/
2. Go to **Manage Nodes** → create a compute node → copy the `REG_SECRET`.
3. Go to **Staking** → stake $AUKI → export your wallet private key as `SECP256K1_PRIVHEX`.

### Domain Viewer

```bash
cd reference-code/domain-viewer
npm install
npm run dev
# Open http://localhost:3000
```

### Domain Spatial Computer

```bash
cd reference-code/domain-spatial-computer
touch .env   # Add AUKI_APP_KEY, AUKI_APP_SECRET, DSC_API_KEY
deno task dev

# Swagger UI: http://localhost:8000/swagger
# Run tests:
deno test
```

### Pathfinding (TypeScript testbed)

```bash
cd reference-code/pathfinding
npm install
npm run dev
```

---

## Development Workflow Tips

### Swagger / OpenAPI

Services with Swagger UIs:
- Domain Spatial Computer: `http://localhost:8000/swagger`

Hosted services also expose Swagger during development but require local source.

### Health checks

Compute nodes register with DDS and poll DMS. Check Docker logs to verify registration
and task polling are working.

### Logs

- Reconstruction node: `LOG_FORMAT=text` for human-readable output
- Domain Spatial Computer: standard Deno console output

---

## Useful Links

- Posemesh Console: https://console.auki.network/
- Auki Labs Whitepaper: https://auki.gitbook.io/whitepaper/
- Reconstruction Server on Docker Hub: https://hub.docker.com/r/aukilabs/reconstruction-node
- DMT App (iOS): https://apps.apple.com/app/domain-management-tool/id6499270503
- Developer documentation: https://www.auki.com/developers/welcome
