# minisform-kuber-cluster

## Overview

Single-node Kubernetes homelab cluster managed by **Flux CD v2.7.5**, running on a Minisforum mini PC. All cluster state is GitOps-driven from this repo. The cluster runs Kubernetes v1.35.0 on Fedora 43 Server (x86_64).

- **Node:** single control-plane node at 192.168.1.112
- **Container runtime:** containerd 2.1.6
- **Git source:** ssh://git@github.com/jay123q/minisform-kuber-cluster.git (branch: main)
- **Owner:** jay123q

---

## Repo Structure

```
.
├── .sops.yaml                          # SOPS encryption rules (age key, encrypted_regex for data/stringData only)
├── charts/                             # Local Helm charts (versioned templates, not currently deployed via Flux)
│   ├── chart-version-0-0-1/
│   └── chart-version-0-0-2/
└── clusters/my-cluster/
    ├── kustomization.yaml              # TOP-LEVEL: root Kustomization that wires everything together
    ├── flux-system/
    │   ├── gotk-components.yaml        # Flux controllers (DO NOT EDIT)
    │   ├── gotk-sync.yaml             # Flux self-management: GitRepository + Kustomization (includes SOPS decryption config)
    │   └── kustomization.yaml
    ├── apps/
    │   ├── hello-world/               # Simple test app (Deployment + Service + ConfigMap), LoadBalancer on 192.168.1.200
    │   └── minecraft-gitops.yaml      # GitRepository + 2 Kustomizations pointing to external repo (see Sub-Clusters below)
    ├── infrastructure/
    │   ├── cilium/                     # CNI - HelmRelease from HelmRepository (currently FAILING, see Known Issues)
    │   ├── metallb/                    # L2 load balancer - HelmRelease v0.15.3
    │   ├── metallb-config/            # IPAddressPool 192.168.1.200-250, L2Advertisement
    │   ├── local-path-provisioner/    # Default StorageClass for PVCs
    │   └── rennovate/                 # Renovate bot (CronJob, see Renovate section)
    └── scripts/
        └── ciliumValues.yaml          # Reference values for Cilium (not directly used by Flux)
```

---

## How Flux Manages This Cluster

### Root Kustomization (flux-system)
The `flux-system` Kustomization watches this repo at `./clusters/my-cluster` and reconciles every 10 minutes. It has:
- **Pruning enabled** (`prune: true`) — resources removed from git are removed from the cluster
- **SOPS decryption** configured via the `sops-age` secret in `flux-system` namespace

The top-level `clusters/my-cluster/kustomization.yaml` includes all infrastructure and app directories. Flux builds this with kustomize, decrypts any SOPS-encrypted files, then applies to the cluster.

### Sub-Clusters (External Repo)
The file `apps/minecraft-gitops.yaml` defines a **separate GitRepository** pointing to `jay123q/minecraft-cluster-gitops` and two Kustomizations that deploy from it:

| Kustomization | Path in minecraft-cluster-gitops | Target Namespace | Health Check |
|---|---|---|---|
| minecraft-cluster | ./cluster | minecraft | Deployment/minecraft-server |
| minecraft-cor-cluster | ./minecraft-cor-server/cluster | minecraft-cor | Deployment/minecraft-cor-server |

Both use the same `flux-system` SSH secret for git auth. Both have health checks and 5m timeouts.

**Important:** Changes to the minecraft workloads are made in the `jay123q/minecraft-cluster-gitops` repo, NOT this one. This repo only defines the Flux source and kustomization pointers.

---

## Infrastructure Components

| Component | Type | Namespace | Status | Notes |
|---|---|---|---|---|
| **Cilium** | HelmRelease | kube-system | **FAILING** | See Known Issues |
| **MetalLB** | HelmRelease v0.15.3 | metallb-system | Healthy | L2 mode, pool 192.168.1.200-250 |
| **Local Path Provisioner** | HelmRelease | local-path-storage | Healthy | Default StorageClass |
| **Renovate** | CronJob | rennovate | Healthy | See Renovate section |

### Networking
- **CNI:** Cilium with Hubble UI, envoy, eBPF LB
- **Load Balancer:** MetalLB L2 on 192.168.1.200-250
- **Service IPs in use:**
  - 192.168.1.200 — hello-world (port 80)
  - 192.168.1.201 — minecraft-server (ports 25565, 26585)
  - 192.168.1.202 — minecraft-cor-admin (port 26585)
- **K8s API:** 192.168.1.112:6443

---

## SOPS / Secrets Management

- **Encryption:** age key `age1zj4wa4h4z44jh0ftwahr7h3dghkw34caqenvteesvvh32cwv9dxs0aq7hp`
- **Key location on node:** ~/.config/sops/age/keys.txt
- **Cluster secret:** `sops-age` in `flux-system` namespace (key: `age.agekey`)
- **Encryption rules** (`.sops.yaml`): only encrypts `data` and `stringData` fields (via `encrypted_regex`), leaving apiVersion/kind/metadata in plaintext
- **Decryption:** configured on the `flux-system` Kustomization via `spec.decryption.provider: sops`
- **Tools on node:** sops 3.9.4 + age 1.2.1 installed at ~/.local/bin/

### Editing encrypted secrets
```bash
cd ~/Documents/github/minisform-kuber-cluster
sops clusters/my-cluster/infrastructure/rennovate/secret.yaml
# Opens in editor, auto-re-encrypts on save
```

**CRITICAL LESSON LEARNED:** The `gotk-sync.yaml` decryption config must also be applied to the live cluster object via `kubectl patch` — Flux does NOT self-apply changes to its own Kustomization spec from git. If SOPS decryption stops working after a cluster rebuild, run:
```bash
kubectl patch kustomization flux-system -n flux-system --type merge   -p '{spec:{decryption:{provider:sops,secretRef:{name:sops-age}}}}'
```

---

## Renovate (Dependency Management)

Self-hosted Renovate running as a Kubernetes CronJob in the `rennovate` namespace.

- **Schedule:** `0 */6 * * *` (every 6 hours) — NOTE: previously had a bug with `* */6 * * *` which fires every minute during those hours
- **Image:** renovate/renovate:latest
- **Autodiscover:** enabled, filtered to `jay123q/minisform-kuber-cluster` and `jay123q/minecraft-cluster-gitops`
- **Config:** mounted from ConfigMap at /config/config.json
- **Auth:** GitHub fine-grained PAT stored in SOPS-encrypted secret `renovate-env`
- **Log level:** debug

### PAT Permissions Required
The fine-grained GitHub PAT needs these repository permissions for ALL target repos:
- **Contents:** Read and write
- **Issues:** Read and write (Renovate queries issues via GraphQL — this caused "platform-unknown-error" when missing)
- **Pull requests:** Read and write
- **Metadata:** Read

### Common Renovate Debugging
- **"Could not parse config file"**: config.json does NOT support comments. No `#` or `//` in the JSON.
- **"platform-unknown-error"**: usually a PAT permission issue. Check the debug logs for the specific GraphQL field that's FORBIDDEN.
- **"bad-credentials" / 401**: PAT was regenerated but the k8s secret still has the old token. Re-encrypt with sops and push.
- **Manual test run:** `kubectl create job --from=cronjob/renovate renovate-test -n rennovate`
- **Check logs:** `kubectl logs -n rennovate -l job-name=renovate-test --tail=50`

---

## Known Issues

### Cilium HelmRelease Failing
```
Helm upgrade failed: values don't meet the specifications of the schema(s):
cilium: at '/agent': got object, want boolean
```
The `agent` key in `cilium-helmrelease.yaml` values is set as an object (`agent.podSecurityContext.enabled: true`) but Cilium 1.18.6 expects `agent` to be a boolean. The cluster still functions because Cilium was previously installed successfully — the failed upgrade just means it's running an older config. To fix: check the Cilium 1.18.x values schema and restructure the values block.

---

## Workloads Summary

| Namespace | Workload | Type | Storage | Managed By |
|---|---|---|---|---|
| default | hello-world | Deployment (1 replica) | none | this repo |
| minecraft | minecraft-server | Deployment (1 replica) | 10Gi PVC (local-path) | minecraft-cluster-gitops |
| minecraft-cor | minecraft-cor-server | Deployment (1 replica) | 20Gi PVC (local-path) | minecraft-cluster-gitops |
| minecraft-cor | minecraft-cor-backup | CronJob (daily 3am) | uses minecraft-cor PVC | minecraft-cluster-gitops |
| rennovate | renovate | CronJob (every 6h) | none | this repo |

---

## Quick Reference Commands

```bash
# Force Flux to pull latest and reconcile
flux reconcile source git flux-system && flux reconcile kustomization flux-system

# Check all Flux resources
flux get all

# Check why a kustomization is failing
flux get kustomization flux-system

# View kustomize-controller logs (SOPS errors show here)
kubectl logs -n flux-system deploy/kustomize-controller --tail=50

# Validate kustomize build locally before pushing
cd clusters/my-cluster/infrastructure/rennovate && kubectl kustomize .

# Trigger manual renovate run
kubectl create job --from=cronjob/renovate renovate-test -n rennovate
```
