# Kubernetes YAML Cookbook

A practical collection of reusable Kubernetes manifest references and small workload examples.

## How to use

1. Copy the relevant manifest or fragment into your project.
2. Replace every `<placeholder>` with environment-specific values.
3. Check API fields against your cluster version and installed controllers/CRDs.
4. Validate before applying:
   ```bash
   kubectl apply --dry-run=client -f <file>.yaml
   kubectl apply --dry-run=server -f <file>.yaml
   ```
5. Never commit real credentials. The Secret examples contain placeholders only.

## Important notes

- Files in `03-storage`, `04-configuration` fragments, `05-security` fragments, and `06-scheduling` fragments may be partial YAML intended to be inserted into a Pod or controller spec; they are not all standalone resources.
- `hostPath` in the static PV example is intended for disposable labs, not production.
- Ingress requires an installed Ingress controller. `LoadBalancer` requires provider support.
- NetworkPolicy requires a compatible CNI implementation.
- VolumeSnapshot resources require the snapshot controller and a compatible CSI driver.
- StorageClass parameters and provisioner names are driver-specific.
- The StatefulSet example requires a StorageClass and a Secret to exist; replace the image/configuration for real deployments.
- The examples are starting points, not production security or availability guarantees.

## Directory overview

- `00-basics`: namespaces, metadata, quotas
- `01-workloads`: Pods and workload controllers
- `02-networking`: Services, Ingress, policies, endpoints
- `03-storage`: PV/PVC, StorageClass, mounts, snapshots
- `04-configuration`: ConfigMaps, Secrets, environment, init containers
- `05-security`: ServiceAccounts, RBAC, security contexts
- `06-scheduling`: placement, tolerations, topology, disruption budgets
- `07-health-resources`: probes, resource sizing, autoscaling
- `08-examples`: complete small application patterns
