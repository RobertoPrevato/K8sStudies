## 2025-10-21

- Improve the [_Monitoring_](./k3s/monitoring.md) exercise to include improved monitoring
  using the **kube-prometheus-stack** Helm chart for Prometheus and Grafana.
- Add the [_CloudNativePG_](./k3s/cloudnativepg.md) exercise where I share my notes on
  using CloudNative-PG in K3s, and also how to configure monitoring and backups with an
  Azure Storage Account.

## 2025-10-03

- Add the [_Azure Container Registry_](./k3s/acr.md) exercise that describes how to pull
  images from an Azure Container Registry to a Kubernetes cluster running on-premises,
  using RBAC and following the principle of least privilege (*pull* access only).

## 2025-09-24

- Add the [_K3s Monitoring_](./k3s/monitoring.md) page to describe how to deploy a
  complete monitoring stack in a single-node _K3s_ cluster using _Helm_ charts. The
  stack includes _Prometheus_ for metrics, _Grafana Loki_ for logs, _Grafana Tempo_
  for traces, and _Grafana_ for visualization. I also deployed the _OpenTelemetry
  Collector_ to receive telemetry data from applications, and showed how to configure
  a demo application to send logs and traces using the _OTLP_ protocol.

## 2025-09-17

- Add the [_K3s Index_](./k3s/index.md) page to describe my first steps with
  _K3s_, including how to install it, deploy a simple web application that uses a _Persistent Volume_, and expose it using _Traefik_.
- Add the [_K3s Ingress Per App_](./k3s/ingress-per-app.md) page to describe how to
  expose multiple web applications on different domains using _K3s_ and
  _Traefik_.

## 2025-08-09

- Add the [_CloudNativePG_](./kind/cloudnativepg.md) page to describe my
  first baby steps with _CloudNativePG_, including a brief introduction to
  _Operators_ and how they extend Kubernetes capabilities to manage complex
  applications like databases.
- Improve the mounting volumes example to use the `/home/stores/`
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
