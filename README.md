### Deploy nodejs-sampleapp in kuberneted
This repo has below manifests.
- ns.yaml for creating namespace
- ns-quota.yaml for creating resource quota for namespaces
- hpa (Horizontal POD autoscaler) for autoscaling
- PDB (POD distrubtion budget) to make sure always minimum container runnig
- Kubernetes service
- Ingress to access the application outside of kubernetes cluster.
