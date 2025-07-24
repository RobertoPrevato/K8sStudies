---
title: ⚓ Kubernetes Studies
---

# Personal Kubernetes studies ⚓

This repository contains my personal notes and studies on
[**Kubernetes**](https://kubernetes.io/), including various configurations, deployments,
and other related topics.

These notes are primarily for **personal reference**, but may also be helpful for
sharing knowledge with others. Some of the information I write here will likely be wrong
or not according to best practices, because these are genuine studies, and I am still
learning.

The opinions expressed in these notes are my own and do **not** represent the views of
my employer.

## A foreword on vendor lock-in

**Kubernetes** can be a valuable tool in avoiding or mitigating vendor lock-in, particularly
in cloud environments. Its open-source nature and container orchestration capabilities
allow for greater flexibility and portability of applications across different cloud
providers or even on-premises infrastructure.

**How Kubernetes helps avoid vendor lock-in:**

- **Open Source Foundation:** Being open-source, Kubernetes is not tied to a single
vendor's interests, ensuring a degree of independence and community-driven development.

- **Abstraction:** Kubernetes abstracts away the underlying infrastructure (cloud
provider, hardware) allowing you to deploy and manage applications consistently across
different environments.

- **Containerization:** Containers package applications and their dependencies, making
them portable and able to run consistently on different platforms, further reducing
vendor dependency.

- **Multi-cloud and Hybrid Cloud:** Kubernetes facilitates multi-cloud and hybrid cloud
strategies, enabling you to distribute workloads across multiple cloud providers or
combine on-premises and cloud resources, reducing reliance on a single vendor.

- **Linux-Centric Platform:** Kubernetes is primarily designed to run on Linux, which is
  itself open-source and widely supported. This focus on Linux ensures broad
  compatibility, flexibility, and avoids dependencies on proprietary operating systems.

However, to really avoid vendor lock-in, it's essential to learn the _standard
technologies_ and tools that are not specific to any cloud provider. This means focusing
on the core Kubernetes concepts and tools like
[**kubectl**](https://kubernetes.io/docs/reference/kubectl/),
[**kubeadm**](https://kubernetes.io/docs/reference/setup-tools/kubeadm/),
[**Kind**](https://kubernetes.io/docs/tasks/tools/#kind) or
[**MiniKube**](https://kubernetes.io/docs/tasks/tools/#minikube) for local development,
and avoiding over-reliance on cloud-specific services or managed Kubernetes offerings
that introduce dependencies on a particular vendor's ecosystem.

For this reason, my notes are focused on the standard Kubernetes technologies and tools,
and how to run Kubernetes locally without relying on cloud providers.

This knowledge is anyway a useful foundation for working with managed Kubernetes offerings
like [Azure Kubernetes Service (AKS)](https://azure.microsoft.com/en-us/products/kubernetes-service),
[Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/), or
[Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine).

## Diving deeper section

The _Diving deeper_ section contains other topics related to *Docker* and *Kubernetes*,
including non-technical information and my personal view on events.

## Requirements to follow

Basic knowledge of the following technologies is required to follow my notes:

- [Bash](https://www.gnu.org/software/bash/).
- [Linux](https://ubuntu.com/).
- [Docker](https://www.docker.com/).
- [Kubernetes](https://kubernetes.io/).

Understanding of the web and networking is also helpful, as many of the examples
involve deploying web applications in Kubernetes.

Although I will try to include some quick-start guide for these technologies, I assume that
you have a basic understanding of them, as they are essential for working with Kubernetes
and containerization in general.

The [getting started guide](./getting-started.md) includes instructions to prepare a
development environment and recommended learning resources for beginners to learn the
basics of Docker and Kubernetes.
