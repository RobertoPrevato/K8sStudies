After exploring [K3s](../k3s/index.md) and [Kind](../kind/index.md) in previous exercises,
I want to practice with **`kubeadm`**. Using [**`kubeadm`**](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), you can create a minimum viable
Kubernetes cluster that conforms to best practices. In this page I describe how to
install `virt-manager` on a host running Ubuntu 24.04 and how to create a group of
virtual machines as a foundation to start studying `kubeadm`.

- [X] Using `virt-manager` to create virtual machines in Linux using KVM.
- [X] Creating nodes for Kubernetes using `virt-manager`.
- [X] Cloning and configuring VMs manually, to understand each step.
- [X] Cloning the VMs more efficiently, using `virt-sysprep` (best for automation).
- [X] Getting started with `kubeadm`.

## Reference documentation

- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).
- [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

## K3s vs kubeadm

**K3s** is a lightweight, batteries-included Kubernetes distribution that comes
pre-configured with many components (`Traefik` ingress controller, local storage
provider, etc.). It's production-ready and designed for simplicity, minimal resource
usage, and ease of management—especially suited for edge computing, IoT, and
resource-constrained environments.

**kubeadm** is the standard tool for bootstrapping Kubernetes clusters. It provides a
more manual, modular approach where you need to:

- Choose and install your own CNI (Container Network Interface) plugin
- Set up your own ingress controller
- Configure storage providers
- Make more infrastructure decisions

**Why practice with kubeadm?**

Both K3s and kubeadm are production-ready, but learning `kubeadm` gives:

- A deeper understanding of Kubernetes components and how they work together
- Experience with the standard cluster bootstrap process used in traditional enterprise
  deployments
- Knowledge applicable to managed Kubernetes services (EKS, AKS, GKE) which follow
  similar architectural patterns
- Skills needed for Kubernetes certifications (CKA, CKAD, CKS)

## Preparing the nodes

To practice with `kubeadm`, you need multiple nodes. One approach would be to work with
multiple physical computers. For instance, there are many tutorials on the web
explaining how to create Kubernetes clusters using Raspberry Pis. But for learning, I
think it's best using virtual machines. Using virtual machines allows you to delete and
recreate nodes more freely, to focus on the objective to study Kubernetes, and it
doesn't require dedicating physical space and purchasing additional hardware (assuming
that you have at least one good development computer). In the past I used `Virtual Box`
to create virtual machines on Ubuntu, but after reading a little on today's options, I
decided to use `virt-manager` instead.

For this exercise, I am using a **Lenovo P15 Gen 1** with 12 CPU cores, 32GB of RAM,
2.6 TB SSD, and running **Ubuntu Desktop 24.04**.

```bash
sudo apt install virt-manager
```

### Overview

This is an overview of what I want to achieve:

1. Installing `virt-manager` on the host.
2. Preparing virtual machines on the host, to have the nodes for Kubernetes.
3. Installing the necessary tools on the nodes, and creating the cluster using `kubeadm`.

To use kubeadm to install a Kubernetes controller on a VM, you first need to install
kubeadm, kubelet, and kubectl, along with a container runtime, on the VM. Then, run
kubeadm init on that VM to initialize the control plane, and install a CNI plugin for
pod networking. Then join worker nodes.

The following diagram provides more details.

```mermaid
flowchart TD
    Start([**Start: Kubeadm Cluster Setup**]) --> VM1[Install **virt-manager** on the host]
    VM1 --> VM2[Download Ubuntu Server ISO]
    VM2 --> VM3[Create Ubuntu Server VM<br/>4GB RAM, 1-2 CPU, 20GB disk]
    VM3 --> VM4[Install prerequisites on the VM:<br/>- containerd<br/>- kubeadm<br/>- kubelet<br/>- kubectl]
    VM4 --> VM6[Disable swap on VM]
    VM6 --> VM8[Shutdown Template VM]

    VM8 --> Clone[Clone Template VM]
    Clone --> N1[Control Plane Node]
    Clone --> N2[Worker Node 1]
    Clone --> N3[Worker Node 2]

    N1 --> CP1[Update hostname:<br/>**control-plane**<br/>Optional: set static IP.]
    N2 --> W1[Update hostname:<br/>**worker-1**<br/>Optional: set static IP.]
    N3 --> W2[Update hostname:<br/>**worker-2**<br/>Optional: set static IP.]

    CP1 --> CP2[Start all VMs]
    W1 --> CP2
    W2 --> CP2

    CP2 --> CP3[On Control Plane:<br/>kubeadm init --pod-network-cidr=10.244.0.0/16]
    CP3 --> CP4[Configure kubectl for user:<br/>Copy /etc/kubernetes/admin.conf]
    CP4 --> CP5[Install CNI Plugin<br/>e.g., Flannel, Calico, or Cilium]
    CP5 --> CP6[Get join command:<br/>kubeadm token create --print-join-command]

    CP6 --> Join[On Worker Nodes:<br/>Run kubeadm join command]

    Join --> Verify[Verify cluster:<br/>kubectl get nodes]
    Verify --> Complete([Cluster Ready!])
```

---

### Creating a VM using virt-manager

For practice, I start by creating an Ubuntu Server 24.04 virtual machine.
I downloaded the ISO of Ubuntu Server 24.04 from the [official site](https://ubuntu.com/download/server).

Use the controls in the graphical user interface to select the downloaded ISO file and
follow the steps to configure and install Ubuntu Server. The screenshots below show the
passages I followed.

For now, I assign:

- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 20 GB

![virt-manager 01](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-01.png)

![virt-manager 02](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-02.png)

![virt-manager 03](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-03.png)

![virt-manager 04](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-04.png)

![virt-manager 05](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-05.png)

![virt-manager 06](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-06.png)

![virt-manager 06b](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-06b.png)

![virt-manager 07](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/cea31b01e02e2e6f015aa33abf2f10a112fe0639/virt-manager-07.png)

After installing Ubuntu Server, navigate to the VM details, select the CD ROM device and
remove the installation medium clicking on the icon to clear the source path and click
the 'Apply' button.

During the installation of Ubuntu Server, I enabled OpenSSH. It is possible to import public keys for SSH
authentication from two sources, including GitHub. Otherwise, configure `authorized_keys`
using the CLI once the machine is ready. This will make installing tools easier, as we
can SSH from the host into the virtual machine.

### Virtual Networks

With `virt-manager`, it is possible to configure virtual networks.
To configure virtual networks, you can use the main menu and navigate to: `Edit > Connection Details > Virtual Networks`.
However, for now, I will stick to the default virtual network `192.168.122.0/24`.

### Installing tools

We could install tools directly in the virtual machines using the console provided by
`virt-manager`, but to do this comfortably we would need to enable clipboard support
(to copy commands from the host and paste them into the virtual machine).
A more comfortable option, in my opinion, is to SSH from the host into the virtual
machine.

Obtain the IP address of the VM from within, using the console in `virt-manager`, to
then SSH into the VM from a regular terminal.

```bash
# on the vm…
hostname -I
```

```bash
# from the host…
ssh ro@192.168.122.116
```

Once on the VM, we need to follow the instructions at [_Installing kubeadm_](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

**Install containerd.**

```bash
# Install containerd
sudo apt update
sudo apt install -y containerd

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Enable SystemdCgroup (required for kubeadm)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verify status
sudo systemctl status containerd
```

**Disable swap.**

```bash
# Disable swap…
sudo swapoff -a

# Comment out swap entries in /etc/fstab
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Check current swap status (should be empty)
sudo swapon --show

# Comment the swap line in /etc/fstab, adding #
sudo nano /etc/fstab
```

**Install kubeadm, kubelet and kubectl.**

- **kubeadm**: the command to bootstrap the cluster.
- **kubelet**: the component that runs on all of the machines in your cluster and does
  things like starting pods and containers.
- **kubectl**: the command line util to talk to your cluster.

```bash
sudo apt-get update

sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

**Ensure that cgroup drivers are configured.**

It's necessary to ensure the cgroup driver matches between `containerd` and `kubelet`.

Kubernetes requires that the container runtime (`containerd`) and `kubelet` use the same
cgroup driver. There are two options:

- `systemd` Recommended for systemd-based Linux distributions (like Ubuntu)
- `cgroupfs` Legacy option

By default, containerd uses cgroupfs `SystemdCgroup = false`; and kubeleto on
Ubuntu 24.04 with systemd, defaults to systemd cgroup driver.
This mismatch causes problems, so you need to configure containerd to use systemd.

Always set `SystemdCgroup = true` in containerd config on systemd-based systems like
Ubuntu. This is the recommended configuration in the official Kubernetes documentation
and what you've correctly included in your notes.

```bash
# the following should return SystemdCgroup = true
grep SystemdCgroup /etc/containerd/config.toml
```

---

## Configuring VMs manually

This section of the page describes how to configure VMs manually, using the `virt-manager`
graphical user interface and entering each VM using `SSH`. This is useful as a learning
exercise and to understand each step. However, it's pretty boring and inefficient if
done too often. If you wish, skip this part and go directly to the section describing
how to configure VMs in a more automation-friendly manner, at [_Using virt-sysprep_](./index.md#using-virt-sysprep).

---

Once the base VM template is ready, clone it three times into:

- **control-panel**
- **worker-1**
- **worker-2**

![Virt manager ](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/2411475a25e92030d5a560ef58259d86cba8431e/virt-manager-vms.png)

Start each of them one by one, and ssh into them to configure a hostname and optionally
a static IP for each node.

```bash
# change the hostname, for example, on the hostname
sudo hostnamectl set-hostname control-plane

# verify…
hostnamectl

# update /etc/hosts
127.0.1.1 control-plane
```

### Assign a static IP

Ubuntu Server 24.04 uses **Netplan** for network configuration.

**Find your network interface name:**
```bash
ip a
# Look for interface like enp1s0, ens3, etc.
```

**Edit netplan configuration:**

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

**Replace the content with:**

```yaml
network:
  version: 2
  ethernets:
    enp1s0:  # Replace with your actual interface name
      dhcp4: false
      addresses:
        - 192.168.122.10/24  # Control plane: .10, Worker-1: .11, Worker-2: .12
      routes:
        - to: default
          via: 192.168.122.1
      nameservers:
        addresses:
          - 192.168.122.1
          - 8.8.8.8
```

**Apply the configuration:**

```bash
sudo netplan apply

# Verify
ip a
```

/// admonition | The SSH connection will drop after changing IP.
    type: info

If you apply `sudo netplan apply` using an SSH session from the host, the connection
will be lost. Open a new one using the new ip.

///

Update hosts on all nodes (this is fine for learning and small environments).
On the host and **each VM**, add entries for all cluster nodes:

```bash
sudo nano /etc/hosts
```

```
192.168.122.10  control-plane
192.168.122.11  worker-1
192.168.122.12  worker-2
```

This allows nodes to communicate using hostnames.

Reboot to Ensure Changes Persist:

```bash
sudo reboot
```

Do it for each VM:

**Control Plane (192.168.122.10):**
```bash
sudo hostnamectl set-hostname control-plane
sudo nano /etc/hosts  # Update 127.0.1.1 line
sudo nano /etc/netplan/50-cloud-init.yaml  # Set IP to 192.168.122.10
sudo netplan apply
sudo nano /etc/hosts  # Add all cluster nodes
sudo reboot
```

**Worker-1 (192.168.122.11):**
```bash
sudo hostnamectl set-hostname worker-1
sudo nano /etc/hosts  # Update 127.0.1.1 line
sudo nano /etc/netplan/50-cloud-init.yaml  # Set IP to 192.168.122.11
sudo netplan apply
sudo nano /etc/hosts  # Add all cluster nodes
sudo reboot
```

**Worker-2 (192.168.122.12):**
```bash
sudo hostnamectl set-hostname worker-2
sudo nano /etc/hosts  # Update 127.0.1.1 line
sudo nano /etc/netplan/50-cloud-init.yaml  # Set IP to 192.168.122.12
sudo netplan apply
sudo nano /etc/hosts  # Add all cluster nodes
sudo reboot
```

### Verify Configuration

After rebooting each node:

```bash
# Check hostname
hostname

# Check IP
ip a | grep inet

# Test connectivity to other nodes
ping -c 2 control-plane
ping -c 2 worker-1
ping -c 2 worker-2
```

This ensures each VM has a unique hostname and static IP that persists across reboots,
which is essential for a stable Kubernetes cluster.

## Using virt-sysprep

Manual configuration like the one above is terribly boring. It is _OK_ as a learning
exercise and understand each step. A better alternative is using **`virt-sysprep`** to
prepare virtual machines from templates. It automates cleanup and customization, making
it much better than manual changes after cloning.

**`virt-sysprep`** removes machine-specific configuration from VMs to prepare them as
templates:

- Removes SSH host keys (regenerated on first boot)
- Clears machine-id
- Removes network configuration (MAC addresses, DHCP leases)
- Clears logs and temporary files
- Can set hostname, static IPs, and more

Install on the host:

```bash
# On the host
sudo apt install libguestfs-tools
```

Basic Workflow:

1. Create and Configure Your Base VM Template
2. Clean the Template VM

```bash
# Basic cleanup (removes machine-specific data)
sudo virt-sysprep -d ubuntu-server24.04-a
```
3. Clone VMs

```bash
# Clone in virt-manager GUI, or via command line:
sudo virt-clone --original ubuntu-server24.04-a \
  --name control-plane \
  --auto-clone

sudo virt-clone --original ubuntu-server24.04-a \
  --name worker-1 \
  --auto-clone

sudo virt-clone --original ubuntu-server24.04-a \
  --name worker-2 \
  --auto-clone
```
4. Customize Each Clone with virt-sysprep

**Control Plane:**
```bash
sudo virt-sysprep -d control-plane \
  --hostname control-plane \
  --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
  --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
  --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts'
```

**Worker-1:**
```bash
sudo virt-sysprep -d worker-1 \
  --hostname worker-1 \
  --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
  --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
  --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts'
```

**Worker-2:**
```bash
sudo virt-sysprep -d worker-2 \
  --hostname worker-2 \
  --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
  --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
  --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts'
```

## Set Static IPs with virt-sysprep

Create netplan config files and inject them, use the `control-plane-netplan.yaml`
provided in `./examples/12-virt-manager`:

```yaml
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      addresses:
        - 192.168.122.10/24
      routes:
        - to: default
          via: 192.168.122.1
      nameservers:
        addresses:
          - 192.168.122.1
          - 8.8.8.8
```

**Apply with virt-sysprep:**
```bash
sudo virt-sysprep -d worker-3 \
  --hostname worker-3 \
  --copy-in worker-3-netplan.yaml:/etc/netplan/ \
  --run-command 'mv /etc/netplan/worker-3-netplan.yaml /etc/netplan/50-cloud-init.yaml' \
  --run-command 'sed -i "s/127.0.1.1.*/127.0.1.1 worker-3/" /etc/hosts' \
  --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
  --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
  --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts' \
  --run-command 'echo "192.168.122.13 worker-3" >> /etc/hosts'
```

Create a script to automate the entire process:

```bash
#!/bin/bash

# Clone VMs
for VM in control-plane worker-1 worker-2; do
  sudo virt-clone --original ubuntu-server24.04-a \
    --name $VM \
    --auto-clone
done

# Configure control-plane
sudo virt-sysprep -d control-plane \
  --hostname control-plane \
  --run-command 'sed -i "s/127.0.1.1.*/127.0.1.1 control-plane/" /etc/hosts' \
  --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
  --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
  --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts'

# Configure worker-1
sudo virt-sysprep -d worker-1 \
  --hostname worker-1 \
  --run-command 'sed -i "s/127.0.1.1.*/127.0.1.1 worker-1/" /etc/hosts' \
  --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
  --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
  --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts'

# Configure worker-2
sudo virt-sysprep -d worker-2 \
  --hostname worker-2 \
  --run-command 'sed -i "s/127.0.1.1.*/127.0.1.1 worker-2/" /etc/hosts' \
  --run-command 'echo "192.168.122.10 control-plane" >> /etc/hosts' \
  --run-command 'echo "192.168.122.11 worker-1" >> /etc/hosts' \
  --run-command 'echo "192.168.122.12 worker-2" >> /etc/hosts'

echo "VMs cloned and configured. Start them with:"
echo "  sudo virsh start control-plane"
echo "  sudo virsh start worker-1"
echo "  sudo virsh start worker-2"
```
