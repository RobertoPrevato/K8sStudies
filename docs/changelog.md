## 2025-08-06

- Add the [_CloudNativePG_](./kind/cloudnativepg.md) page to describe my
  first baby steps with _CloudNativePG_, including a brief introduction to
  _Operators_ and how they extend Kubernetes capabilities to manage complex
  applications like databases.
- Improve the mounting volumes example to use the `/tmp/stores/`
  folder on the host machine, instead of a user-specific home folder.

## 2025-08-02

- Improve the [_PostgreSQL_](./kind/postgresql.md) page to describe how to connect
  to a _PostgreSQL_ server running in Kind using a Load Balancer, from a Docker
  container that is not part of the Kubernetes cluster (e.g. to use `psql` or
  `pgAdmin` from a standalone Docker container).

## 2025-07-30

- Improve the [_Getting Started_](./getting-started.md) page to include information
  about more _Kubernetes_ distributions: `Minikube, MicroK8s, Kubeadm, Kind, K3s`,
  at [_Other Kubernetes Distributions_](./getting-started.md#other-kubernetes-distributions).
- Add an exercise about running a single [_PostgreSQL Server_](./kind/postgresql.md) in
  plain Docker and in Kubernetes, for local development.

## 2025-07-27

- Add [_Kind Multi Nodes_](./kind/multi-nodes.md) example and notes.
- Add a [_CHANGELOG_](./changelog.md).
- Improve the [_Mounting a Volume_](./kind/mounting-volumes.md) example to include
  information about _PersistentVolume_ vs _hostPath_.
- Improve the [_Web Hosting_](./kind/web-hosting.md) example to describe the
  _kubectl create secret …_ command

## 2025-07-22

- Initial docs.
