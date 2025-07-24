This page provides a brief history of **Docker**, highlighting its evolution and
significance in the containerization landscape. I also include my personal interpretation
of some events related to Docker.

## PyCon 2013

In 2013, at the _Python programming language conference_
([PyCon](https://www.pycon.org/)), [Solomon Hykes](https://x.com/solomonstre) walked
onto the stage and revealed **Docker** to the world for the first time. This project
aimed to simplify the process of deploying applications in containers, making it easier
for developers to package their applications with all dependencies included. The project
was well-received, and it quickly became one of the most influential technologies in the
world of containerization.

Docker leverages two features of the **Linux** kernel: _cgroups_ and _namespaces_.
Cgroups (control groups) allow the kernel to limit and prioritize resources for
containers, while _namespaces_ provide isolation for processes, ensuring that each
container has its own view of the system, including its own filesystem, network
interfaces, and process tree. Together, these features enable the **lightweight and
efficient virtualization** that Docker is known for.

Docker was initially developed as an internal project within **dotCloud**, a
platform-as-a-service (PaaS) startup company founded by Solomon, before it was released
as open source and eventually became the primary focus of the company.

/// note | Why PyCon?

Docker was presented at the Python programming language conference because it was
initially developed in [Python](https://www.python.org/). Later Docker was reimplemented
in [_Go_](https://go.dev/), which is an open-source programming language developed by
Google. *Go* is also known as *Golang*.

///

/// admonition | Original presentation on YouTube.
    type: info

<iframe width="560" height="315" src="https://www.youtube.com/embed/362sHaO5eGU?si=VY_A0GkuluUGeytZ" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

///

## Docker's impact

Docker has had a profound impact on the software development and deployment landscape.
By popularizing containerization, it has enabled developers to build, ship, and run
applications in a more efficient and consistent manner. Docker's emphasis on
microservices architecture has also influenced the design of modern applications,
promoting greater modularity and scalability.

In my opinion, **Docker** had a profound impact on **Microsoft**, too.

**Microsoft**, which was known for its adversion towards open-source, changed CEO and [_"felt
in love with
Linux"_](https://www.microsoft.com/en-us/windows-server/blog/2015/05/06/microsoft-loves-linux/)
shortly after Docker's introduction, and Windows was modified to
support Linux and running Docker in the same period, through the [_Windows Subsystem For Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install)_.

Talking about the previous adversion towards open-source, let's not forget, for instance:

- In *1996*, ["Embrace, extend, and extinguish" (EEE)](https://en.m.wikipedia.org/wiki/Embrace,_extend,_and_extinguish).
- In *2001*, [Steve Ballmer's famous quote](https://www.youtube.com/watch?v=2k8j6d9a3b4)
 about Linux being a cancer in an _intellectual property sense_.

/// admonition | From Wikipedia
    type: info

> "Embrace, extend, and extinguish" (EEE), also known as "embrace, extend, and exterminate", is
> a phrase that the **U.S. Department of Justice** found was used internally by
> Microsoft to describe its strategy for entering product categories involving widely
> used open standards, extending those standards with proprietary capabilities, and
> using the differences to strongly disadvantage its competitors.
>
> The strategy and phrase "embrace and extend" were first described outside Microsoft in
> a 1996 article in The New York Times titled "Tomorrow, the World Wide Web! Microsoft,
> the PC King, Wants to Reign Over the Internet", in which writer John Markoff said,
> "Rather than merely embrace and extend the Internet, the company's critics now fear,
> Microsoft intends to engulf it." The phrase "embrace and extend" also appears in a
> facetious motivational song by an anonymous Microsoft employee, and in an interview
> of Steve Ballmer by The New York Times.

///

Satya Nadella became the CEO of Microsoft in **February 4, 2014**, succeeding Steve Ballmer.
Satya Nadella first publicly declared that "Microsoft loves Linux" during a press and
analyst briefing where he used a slide with the message "Microsoft ❤️ Linux". This
happened a few months before May 6, 2015, when a [Microsoft blog post](https://www.microsoft.com/en-us/windows-server/blog/2015/05/06/microsoft-loves-linux/) highlighted the
shift in the company's approach to Linux and open source. The specific date of the
initial statement is not explicitly mentioned in the provided context, but it occurred
shortly after Nadella became CEO in February 2014.

While other factors certainly contributed to this change, I believe that Docker played a
significant role in this shift, and that someone at Microsoft realized that Docker was a
game-changer that could not be allowed to be a *Linux-only* technology, unsupported on
*Windows*.

## Connecting dots...

[timeline(./docs/diving-deeper/docker-history.yaml)]

![Connecting dots](/K8sStudies/img/connecting-dots.png)

By staying informed about events and analyzing patterns, we can gain insights into their
causes and make informed predictions.

## Docker and Kubernetes

Docker has continued to evolve since its initial release, with significant updates and
enhancements over the years.

The **CRI (Container Runtime Interface)** standard emerged as a way to decouple Kubernetes
from specific container runtimes like Docker, allowing for greater flexibility and
standardization. Initially, Kubernetes relied on Docker directly, making it
difficult to integrate new runtimes. CRI provided a standardized interface for kubelet
to communicate with any compliant runtime, promoting interoperability and encouraging
the development of new container engines.

Here's a more detailed breakdown:

**Early Kubernetes and Docker:** Kubernetes initially relied heavily on Docker for
containerization. This tight coupling made it challenging to switch container runtimes
or integrate new ones.

**The Need for Standardization:** To address this, the Container Runtime Interface (CRI) was
introduced in Kubernetes 1.5. CRI aimed to provide a consistent way for Kubernetes to
interact with various container runtimes.

**Docker's Complexity:** Docker is more than just a container runtime; it's a suite of
tools for building, managing, and running containers. Kubernetes focuses on the core
container runtime aspect.

**Dockershim and its Removal:** Because Docker wasn't originally designed with CRI in
mind, Kubernetes used a "shim" called Dockershim to bridge the gap. However, Docker's
internal architecture, including `containerd`, already supported *CRI functionality*.
Eventually, Kubernetes deprecated and removed Dockershim, encouraging users to switch
to CRI-compliant runtimes like containerd or CRI-O.

**Benefits of CRI:** The introduction of CRI brought severalbenefits:

- Enhanced Flexibility: Kubernetes users could now easily switch between different
  container runtimes without significant code changes.
- Improved Interoperability: CRI promoted compatibility across various container
  runtimes and tools. Focus on Core Runtime: Kubernetes could focus on the core
  container runtime aspects, leaving higher-level functionality to other tools.
- Modern Container Runtimes: Today, runtimes like containerd and CRI-O are widely used
  with Kubernetes, offering a more streamlined and standardized approach to container
  management.

## Podman

Podman and Docker are both popular containerization tools, but they differ in their
underlying architecture and approach to security. Docker relies on a daemon (a
background process) to manage containers, while Podman is daemonless, allowing for
rootless container execution and stronger isolation. This difference in architecture
impacts how each tool handles security, resource management, and integration with other
systems.
