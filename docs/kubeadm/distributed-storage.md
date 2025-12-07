# Distributed Storage for Kubernetes

Now that I have a multi-nodes Kubernetes cluster running in KVM, I want to explore
**distributed storage** solutions. Distributed storage systems are crucial for stateful
applications in Kubernetes, providing persistent volumes that survive pod restarts and
node failures.

## What is Distributed Storage?

Distributed storage in Kubernetes spreads data across multiple nodes in a cluster, providing:

- **High Availability:** Data remains accessible even if some nodes fail.
- **Replication:** Multiple copies of data across different nodes.
- **Dynamic Provisioning:** Automatic volume creation when applications request storage.
- **Data Management:** Snapshots, backups, cloning, and restoration capabilities.
- **Performance:** Load distribution across multiple storage devices.

## Available Solutions

| Solution        | Type              | License         | Storage Types       | Key Features                                        | Best For                                     |
| --------------- | ----------------- | --------------- | ------------------- | --------------------------------------------------- | -------------------------------------------- |
| **Longhorn**    | Block Storage     | Apache 2.0      | Block               | Lightweight, easy setup, web UI, snapshots, backups | Small to medium clusters, edge computing     |
| **Rook (Ceph)** | Multi-purpose     | Apache 2.0      | Block, File, Object | Enterprise-grade, highly scalable, self-healing     | Large production clusters, multi-tenant      |
| **OpenEBS**     | Multi-engine      | Apache 2.0      | Block               | Multiple storage engines, Mayastor (NVMe), LocalPV  | Flexible deployments, high-performance needs |
| **Portworx**    | Enterprise        | Commercial      | Block, File         | Auto-pilot, disaster recovery, multi-cloud          | Enterprise production, mission-critical apps |
| **StorageOS**   | Block Storage     | Commercial      | Block               | Low latency, compression, encryption                | Performance-critical workloads               |
| **MinIO**       | Object Storage    | AGPL/Commercial | Object              | S3-compatible, erasure coding, multi-cloud          | Object storage, data lakes, backup targets   |
| **GlusterFS**   | Distributed FS    | GPL             | File                | Scale-out NAS, POSIX-compliant                      | Traditional file storage needs               |
| **TopoLVM**     | LVM Manager       | Apache 2.0      | Block               | Capacity-aware scheduling, thin provisioning        | Leveraging existing LVM infrastructure       |
| **Ceph CSI**    | Block/File/Object | Apache 2.0      | Block, File, Object | Direct Ceph integration without Rook                | Existing Ceph clusters                       |

**Key Considerations:**

- **Longhorn** and **OpenEBS** are the easiest to get started with for learning and development.
- **Rook/Ceph** is the most feature-complete open-source solution but has higher complexity.
- **Portworx** and **StorageOS** offer commercial support and advanced features.
- **MinIO** is ideal when you need S3-compatible object storage.
- **TopoLVM** works well if you already have LVM configured on your nodes.

## Why I Chose Longhorn for Practice

For my learning environment, I decided to start with [Longhorn](https://longhorn.io/)
because:

1. **Easy Setup:** Quick installation via Helm or kubectl
2. **User-Friendly UI:** Web interface for managing volumes, snapshots, and backups
3. **Lightweight:** Minimal resource overhead, perfect for learning environments
4. **Good Documentation:** Clear guides and examples
5. **Production-Ready:** Created by Rancher (SUSE), used in production by many organizations
6. **Complete Feature Set:** Includes snapshots, backups, replicas, and disaster recovery

## When Distributed Storage in K8s is Useful

Since it is recommended to create Kubernetes clusters only using nodes with very little
network latencies between them (many recommend keeping network latency between nodes
below **10ms** for optimal performance), it is unlikely to have multi-nodes clusters
colocated in multiple regions. Google AI overview suggests the following: _A realistic
target for <10ms RTT is often within a dense metropolitan area, roughly 50-100 km (30-60
miles) between data centers using dedicated fiber_. You often still want to use an
external solution creating replicas in different regions.

**In-cluster replication with distributed storage**:

- Protects against **node failures** (disk failure, node crash).
- Protects against **pod failures**.
- Provides **high availability** within a single cluster.
- **NOT** designed for disaster recovery across geographic locations.

It does not ensure **disaster recovery (DR)** when data is only replicated within the
same datacenter:

```
Building A (Data Center)
├── Cluster 1 (3 nodes)
│   ├── Longhorn Replica 1
│   ├── Longhorn Replica 2
│   └── Longhorn Replica 3
└── NFS Backup (same building)

🔥 Fire/Flood/Power Outage → Everything Gone
```

Many question the true usefulness of distributed storage systems like Longhorn,
see this [Reddit post](https://www.reddit.com/r/kubernetes/comments/10war0o/can_someone_explain_me_the_true_benefits_of/)
for an example.

For true disaster recovery, you need off-site backups:

| Level | Type                                         | Protects Against                | Recovery Time                | Scope                 |
| ----- | -------------------------------------------- | ------------------------------- | ---------------------------- | --------------------- |
| 1     | In-Cluster HA (Distributed Storage Replicas) | Node/disk failures              | Instant (automatic failover) | Within cluster        |
| 2     | In-Cluster Backups (NFS on local host)       | Accidental deletion, corruption | Minutes                      | Within data center    |
| 3     | Off-Site Backups (External Storage)          | Data center disasters           | Hours to days                | Geographic redundancy |

Most distributed storage solutions support creating backups in various kinds of external
storage to offer DR:

- AWS S3 or S3-compatible storage.
- Azure Storage Blob Service.
- Google Cloud Storage.
- NFS mounts.
- SMB/CIFS Backupstore.

The scenario I am testing right now, which is using Virtual Machines in the same host,
is useful for learning and testing purpose.

**Key Takeaways:**

- [X] In-cluster replication = **High Availability** (not DR)
- [X] Local backups = Protection from mistakes (not DR)
- [X] Off-site backups = Disaster Recovery (true DR)
- [X] You need all three layers for comprehensive protection

### Real-World DR Strategy

For production, a typical setup combines in-cluster replication with off-site backups:

```
┌─────────────────────────────────────┐
│   Data Center A (Primary)           │
│                                     │
│   ┌─────────────────────────────┐   │
│   │ K8s Cluster                 │   │
│   │ ├── Storage (3 replicas)    │   │──┐
│   │ └── Local NFS Backups       │   │  │
│   └─────────────────────────────┘   │  │
└─────────────────────────────────────┘  │
                                         │
         ┌───────────────────────────────┘
         │ (Automated backup sync)
         ▼
┌─────────────────────────────────────┐
│   Data Center B (DR Site)           │
│   or Cloud Storage (S3, GCS, etc.)  │
│                                     │
│   ├── Off-site Backups              │
│   └── Ready for restore             │
└─────────────────────────────────────┘
```

Disaster Recovery Process:

1. **Normal operation:** Storage system replicates within cluster.
1. **Periodic backups:** System creates backups to NFS/S3/other targets.
1. **Off-site sync:** Backups automatically copied to remote location.
1. **Disaster strikes:** Primary data center is lost.
1. **Recovery:**
    1. Provision new cluster (different location).
    1. Install storage system.
    1. Configure backup target pointing to off-site storage.
    1. Restore volumes from backups.

---

## Using Longhorn

For the rest of this guide, I'll focus on practicing with **Longhorn** as my distributed
storage solution. The following sections detail the specific requirements, installation,
and configuration for Longhorn.

## Longhorn Requirements

Longhorn requires **`iscsid`**, which is the `iSCSI` (Internet Small Computer Systems
Interface) daemon that enables a Linux system to act as an iSCSI initiator - essentially
allowing it to connect to remote block storage devices over a network as if they were
locally attached disks.

### Why Longhorn Needs iscsid

Longhorn uses iSCSI as the underlying protocol to expose block
storage volumes to Kubernetes pods. Here's how it works:

1. **Volume Provisioning:** When a pod requests a **PersistentVolume**, Longhorn creates
   a block storage volume distributed across cluster nodes.
1. **iSCSI Target:** Longhorn's storage engine acts as an iSCSI target (the storage server).
1. **iSCSI Initiator:** The Kubernetes node where the pod is scheduled acts as an iSCSI
   initiator (the storage client), using iscsid to connect to the Longhorn volume.
1. **Block Device:** The iSCSI connection presents the Longhorn volume as a local block device
   (like /dev/sdb) that can be formatted and mounted into the pod.

The Flow

```
Pod → PVC → Longhorn Volume (iSCSI Target)
                      ↕ (iSCSI protocol)
              Node's iscsid (iSCSI Initiator)
                      ↕
              Local block device (/dev/sdX)
                      ↕
              Mounted into pod
```

**Why iSCSI?**

1. **Standard Protocol:** iSCSI is a mature, well-supported protocol for network block
   storage
1. **Performance:** Provides near-native block storage performance over standard TCP/IP
   networks
1. **Compatibility:** Works with standard Linux storage stack (no kernel modules needed
   beyond what's already available)
1. **Flexibility:** Allows volumes to be attached/detached from nodes dynamically as pods
   are scheduled

---

### Why NFS is useful for backups

We will also install `nfs-common`, which is useful for backup target. `nfs-common`
provides the NFS client utilities that allow your Kubernetes nodes to mount Network File
System (NFS) shares. Here's why it's needed:

When you configure an NFS backup target in Longhorn (e.g.,
`nfs://192.168.122.1:/srv/nfs/longhorn-backups`):

1. **Longhorn Manager** running on a node needs to mount the NFS share to write backup data.
1. The mount operation requires NFS client tools, which are provided by nfs-common.
1. Without nfs-common, the node cannot mount the NFS share, and backups will fail.

The package includes essential NFS client utilities:

- **mount.nfs** - Handles NFS mount operations
- **showmount** - Lists NFS exports from a server
- **rpcinfo** - Queries RPC services (used by NFS)
- **rpc.statd** - Provides file locking for NFS

The Backup Flow looks like the following:

```
Longhorn Manager (on Node)
    ↓ (needs nfs-common)
Mount NFS share using mount.nfs
    ↓
Write backup data to mounted path
    ↓
NFS Server receives and stores backup
```

Since **Longhorn Manager** pods can run on any node in a cluster, **all nodes need
`nfs-common `installed** to ensure backups work regardless of where the manager pod is
scheduled.

### Installing the requirements

Requirements could be installed with Bash using:

```bash
# Check if open-iscsi is installed on all nodes
# SSH into each node (control-plane, worker-1, worker-2, worker-3) and run:
sudo apt update
sudo apt install -y open-iscsi
sudo systemctl enable --now iscsid

# Verify it's running
sudo systemctl status iscsid

# Install nfs-common (useful for backup target)
sudo apt install -y nfs-common

# Check for available disk space on each node
df -h | grep -E '/$|/var'
```

But better options are:

- To include these tools in the VM template used to create Kubernetes nodes.
- Using [Ansible](./ansible.md) to install the required tools for Longhorn, using an
  inventory file and a _playbook_.

**Create Playbook for Longhorn Prerequisites:**

```yaml
# ./examples/14-longhorn/longhorn-prerequisites.yaml
---
- name: Install Longhorn Prerequisites
  hosts: k8s_cluster
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install open-iscsi
      apt:
        name: open-iscsi
        state: present

    - name: Enable and start iscsid service
      systemd:
        name: iscsid
        enabled: yes
        state: started

    - name: Verify iscsid is running
      systemd:
        name: iscsid
        state: started
      register: iscsid_status

    - name: Install nfs-common
      apt:
        name: nfs-common
        state: present

    - name: Check available disk space
      shell: df -h | grep -E '/$|/var'
      register: disk_space
      changed_when: false

    - name: Display disk space
      debug:
        msg: "{{ disk_space.stdout_lines }}"
```

```bash
ansible-playbook -i inventory.ini longhorn-prerequisites.yaml -K
```

## Installing Longhorn

/// tab | Using Helm.

```bash
# Add Longhorn Helm repository
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Install Longhorn
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.9.2 \
  --set defaultSettings.defaultReplicaCount=1

# Check the installation
kubectl get pods -n longhorn-system
```

///

/// tab | Using kubectl.

```bash
# From your host machine (with kubeadm-cluster context active)
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.9.2/deploy/longhorn.yaml

# Wait for Longhorn to be deployed (this takes a few minutes)
kubectl get pods -n longhorn-system --watch

# All pods should eventually be in Running state
```

///

## Accessing the Longhorn UI

/// tab | Using Ingress.

Configure an ingress (requires an [Ingress Controller](./external-access.md)).

```bash
# Apply the ingress configuration ./examples/14-longhorn/
kubectl apply -f longhorn-ingress.yaml

# Verify ingress
kubectl get ingress -n longhorn-system
```

Obtain the IP address of the ingress controller:

```bash
kubectl get svc -n traefik-system

NAME      TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                      AGE
traefik   LoadBalancer   10.103.199.179   192.168.122.52   80:30443/TCP,443:31075/TCP   47m
```

Update the hosts file to expose the ingress' external IP with the **hostname**
configured in the ingress:

```bash
# common ingress for web traffic
192.168.122.52 longhorn.local
```

Navigate with a browser to `http://longhorn.local`.

///

/// tab | Using NodePort.

Using node port:

```bash
# Expose Longhorn UI via NodePort
kubectl expose deployment longhorn-ui -n longhorn-system --type=NodePort --name=longhorn-ui-nodeport

# Get the NodePort
kubectl get svc -n longhorn-system longhorn-ui-nodeport

# Access via: http://<node-ip>:<nodeport>
# For example: http://192.168.122.11:31234
```

Navigate with a browser to `http://<node-ip>:<nodeport>`.

///

![Longhorn UI](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/420727d6dbadc0c5dbf9f14985ec166b7d5c8c4b/longhorn-ui-01.png)

## Practice Exercise

### Create a Test Application with Persistent Storage

````yaml {linenums="1" hl_lines="2 8 30-36"}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: volume-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: volume-test
  template:
    metadata:
      labels:
        app: volume-test
    spec:
      containers:
      - name: nginx
        image: nginx:stable-alpine
        volumeMounts:
        - name: longhorn-vol
          mountPath: /usr/share/nginx/html
      volumes:
      - name: longhorn-vol
        persistentVolumeClaim:
          claimName: longhorn-test-pvc
````

```bash
# Apply the configuration
kubectl apply -f examples/14-longhorn/test-app.yaml

# Check PVC status
kubectl get pvc longhorn-test-pvc

# Get the pod name (it will have a generated suffix)
kubectl get pods -l app=volume-test

# Write some data to the volume
POD_NAME=$(kubectl get pod -l app=volume-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- sh -c "echo 'Hello from Longhorn' > /usr/share/nginx/html/index.html"

# Verify the data
kubectl exec -it $POD_NAME -- cat /usr/share/nginx/html/index.html
```

Now, if you navigate to the Longhorn UI, you can see the volume and its replicas:

![Longhorn UI Volume 01](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/ab343fcb8f2fc9b177bf955f42bfd61b6ec0c2f9/longhorn-volume-01.png)
![Longhorn UI Volume 02](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/ab343fcb8f2fc9b177bf955f42bfd61b6ec0c2f9/longhorn-volume-02.png)
![Longhorn UI Volume 03](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/ab343fcb8f2fc9b177bf955f42bfd61b6ec0c2f9/longhorn-volume-03.png)

If the Longhorn UI shows that the volume is _attached_ to `worker-3`, it means the pod
is running only on that worker node.

```bash {hl_lines="3"}
$ kubectl get pods -o wide
NAME                           READY   STATUS    RESTARTS   AGE    IP            NODE       NOMINATED NODE   READINESS GATES
volume-test-5f698b7b77-8mtm4   1/1     Running   0          4m5s   10.244.3.40   worker-3   <none>           <none>       <none>
```

### Test Node Failure Resilience

This is where Longhorn shows its value over simple local storage like
`local-path-provisioner`. With local storage, if a node fails, pods can't access volumes
data in failing pods. With Longhorn's distributed storage, data is replicated across
nodes. If the node running a workload fails, Kubernetes reschedules the same workload
in a different pod, which has access to replicated data.

```bash
# First, check which node the pod is running on
kubectl get pods -l app=volume-test -o wide

# Check the volume replicas in Longhorn UI
# You should see replicas on multiple nodes (if you have >1 replica configured)

# Simulate node failure: drain the node where the pod is running
NODE_NAME=$(kubectl get pod -l app=volume-test -o jsonpath='{.items[0].spec.nodeName}')
kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data

# The pod will be rescheduled to another node
kubectl get pods -l app=volume-test -o wide --watch

# Once running on a different node, verify data is still accessible
POD_NAME=$(kubectl get pod -l app=volume-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- cat /usr/share/nginx/html/index.html
```

The Longhorn UI shows the volume as unhealthy because one of the replicas is not
available:

![Longhorn UI 04](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/ad37b53d32f8ecea2bd471df75fcd429164f905e/longhorn-volume-04.png)
![Longhorn UI 05](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/ad37b53d32f8ecea2bd471df75fcd429164f905e/longhorn-volume-05.png)

```bash
# Uncordon the node that was drained, to make it schedulable again
kubectl uncordon worker-3
```

/// details | kubectl drain…
    type: tip

`kubectl drain` is a command that safely evicts all pods from a node in preparation for
maintenance or decommissioning. Here's what it does:

**Purpose:**

- Gracefully removes pods from a node
- Marks the node as unschedulable (cordoned) so no new pods are scheduled on it
- Useful before node maintenance, upgrades, or shutdown

**What happens:**

1. Node is cordoned (marked as `SchedulingDisabled`)
2. All pods on the node are evicted (respecting PodDisruptionBudgets)
3. Pods are rescheduled on other available nodes
4. DaemonSet pods remain (unless you force deletion)

**Common usage:**

```bash
# Basic drain
kubectl drain <node-name>

# With common flags (what we used)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Force drain (dangerous - ignores PodDisruptionBudgets)
kubectl drain <node-name> --force --ignore-daemonsets --delete-emptydir-data
```

**Important flags:**

- `--ignore-daemonsets`: Required because DaemonSet pods can't be evicted (they're meant
  to run on every node)
- `--delete-emptydir-data`: Allows deletion of pods using emptyDir volumes (temporary
  storage)
- `--force`: Bypasses safety checks (use carefully)
- `--grace-period`: Time to wait before force-killing pods (default: 30s)

**After maintenance:**

```bash
# Make the node schedulable again
kubectl uncordon <node-name>
```

**Example workflow:**
```bash
# 1. Drain node for maintenance
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data

# 2. Perform maintenance (upgrade, reboot, etc.)
# ... maintenance tasks ...

# 3. Make node available again
kubectl uncordon worker-1
```

///

**What happened:**

1. Pod was running on Node A with data stored in Longhorn volume.
2. Node A was drained (simulating failure).
3. Pod rescheduled to Node B.
4. Longhorn automatically attached the volume to Node B.
5. Data remained accessible because replicas existed on other nodes.

**With local-path-provisioner:** The pod would be stuck in `Pending` state because the
volume is tied to the failed node's local disk.

**With Longhorn:** The pod starts immediately on another node with full access to the
**replicated** data.

### What if we wanted pod replicas?

Longhorn supports Deployments with replicas, but there's an important limitation:
**ReadWriteOnce (RWO) access mode** - which is what most block storage systems use - **means
only one pod can mount the volume at a time**.

**The Challenge with Multiple Pod Replicas:**

```yaml
# This WON'T work as expected with ReadWriteOnce
apiVersion: apps/v1
kind: Deployment
metadata:
  name: volume-test
spec:
  replicas: 2  # ❌ Second pod will be stuck in ContainerCreating
  template:
    spec:
      volumes:
      - name: longhorn-vol
        persistentVolumeClaim:
          claimName: longhorn-test-pvc  # RWO volume
```

**What happens:**

- The first pod starts and mounts the volume successfully.
- The second pod gets stuck in `ContainerCreating` state.
- **Error:** "Volume is already exclusively attached to one node and can't be attached to another".

#### Solutions for Multi-Pod Access

/// tab | Option 1: ReadWriteMany (RWX) with NFS.

Longhorn supports RWX through its built-in NFS provisioner:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-rwx-pvc
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods can mount
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-pod-test
spec:
  replicas: 3  # ✅ All pods can mount the same volume
  selector:
    matchLabels:
      app: multi-pod-test
  template:
    metadata:
      labels:
        app: multi-pod-test
    spec:
      containers:
      - name: nginx
        image: nginx:stable-alpine
        volumeMounts:
        - name: shared-vol
          mountPath: /usr/share/nginx/html
      volumes:
      - name: shared-vol
        persistentVolumeClaim:
          claimName: longhorn-rwx-pvc
```

///

/// tab | Option 2: StatefulSet with Multiple Volumes.

For databases or applications needing separate storage per replica:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "web"
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:stable-alpine
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:  # Each pod gets its own PVC
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: longhorn
      resources:
        requests:
          storage: 1Gi
```

///

#### Testing RWX with Multiple Pods

The following example shows how to test synchronized writes across multiple pods:

```bash
# Create RWX PVC and deployment
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-rwx-test
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rwx-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rwx-test
  template:
    metadata:
      labels:
        app: rwx-test
    spec:
      containers:
      - name: writer
        image: busybox
        command:
        - sh
        - -c
        - |
          while true; do
            echo "\$(date) - Written by \$(hostname)" >> /data/shared.log
            sleep 5
          done
        volumeMounts:
        - name: shared-data
          mountPath: /data
      volumes:
      - name: shared-data
        persistentVolumeClaim:
          claimName: longhorn-rwx-test
EOF

# Wait for all pods to be running
kubectl get pods -l app=rwx-test -w

# Check that all pods are writing to the same file
kubectl exec -it $(kubectl get pod -l app=rwx-test -o jsonpath='{.items[0].metadata.name}') -- tail -f /data/shared.log

# You should see writes from all three pod hostnames intermixed
```

```bash
$ kubectl exec -it $(kubectl get pod -l app=rwx-test -o jsonpath='{.items[0].metadata.name}') -- tail -f /data/shared.logog
Sun Dec  7 09:43:11 UTC 2025 - Written by rwx-test-54877d67c6-nzmfp
Sun Dec  7 09:43:16 UTC 2025 - Written by rwx-test-54877d67c6-xrrk8
Sun Dec  7 09:43:16 UTC 2025 - Written by rwx-test-54877d67c6-hvq7q
Sun Dec  7 09:43:16 UTC 2025 - Written by rwx-test-54877d67c6-nzmfp
Sun Dec  7 09:43:21 UTC 2025 - Written by rwx-test-54877d67c6-xrrk8
Sun Dec  7 09:43:21 UTC 2025 - Written by rwx-test-54877d67c6-hvq7q
Sun Dec  7 09:43:21 UTC 2025 - Written by rwx-test-54877d67c6-nzmfp
Sun Dec  7 09:43:26 UTC 2025 - Written by rwx-test-54877d67c6-xrrk8
Sun Dec  7 09:43:26 UTC 2025 - Written by rwx-test-54877d67c6-hvq7q
Sun Dec  7 09:43:26 UTC 2025 - Written by rwx-test-54877d67c6-nzmfp
Sun Dec  7 09:43:31 UTC 2025 - Written by rwx-test-54877d67c6-hvq7q
```

**Important Notes on RWX**

1. **Performance**: RWX is slower than RWO because Longhorn uses an NFS layer on top of
   block storage
2. **Use Cases**: Best for shared configuration files, logs, or read-heavy workloads
3. **Not for databases**: Don't use RWX for databases - they need separate volumes (use
   StatefulSet)
4. **Concurrency**: Multiple pods can write simultaneously, but your application must
   handle file locking if needed

---

**Comparison: RWO vs RWX**.

| Feature         | ReadWriteOnce (RWO)                 | ReadWriteMany (RWX)            |
| --------------- | ----------------------------------- | ------------------------------ |
| Pods per volume | 1                                   | Multiple                       |
| Performance     | Fast (direct block access)          | Slower (NFS overhead)          |
| Use with        | Deployment (1 replica), StatefulSet | Deployment (multiple replicas) |
| Best for        | Databases, single-writer apps       | Shared files, logs, config     |
| Node affinity   | Volume follows pod                  | Any pod on any node            |

---

Clean up:

```bash
# Delete the deployment and PVC
kubectl delete deployment rwx-test
kubectl delete pvc longhorn-rwx-test

# Verify deletion
kubectl get deployment rwx-test
kubectl get pvc longhorn-rwx-test
```

## Using Volume Snapshots

**Volume Snapshots** in Kubernetes are a standard way to create point-in-time copies of
persistent volumes. They're part of the Kubernetes API (not specific to any storage
provider) and provide a consistent interface for backup and recovery operations.

Volume Snapshots in Kubernetes are a standard way to create point-in-time copies of persistent volumes. They're part of the Kubernetes API (not specific to any storage provider) and provide a consistent interface for backup and recovery operations.

| Element                   | Description                                                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| **VolumeSnapshot**        | A request for a snapshot of a volume by a user. Similar to how a PVC is a request for storage.                            |
| **VolumeSnapshotContent** | The actual snapshot data, similar to how a PV is the actual storage. Created automatically when a VolumeSnapshot is made. |
| **VolumeSnapshotClass**   | Defines properties for snapshots (like StorageClass does for volumes), including the CSI driver and deletion policy.      |

```
User creates VolumeSnapshot
         ↓
Kubernetes calls CSI driver (Longhorn, Ceph, etc.)
         ↓
Storage system creates snapshot
         ↓
VolumeSnapshotContent is created
         ↓
VolumeSnapshot shows Ready=true
```

Common use cases of volume snapshots are:

1. **Backup before changes**: Take a snapshot before deploying new code or schema changes.
2. **Clone volumes**: Create new PVCs from snapshots for testing/development.
3. **Disaster recovery**: Regular scheduled snapshots for data protection.
4. **Testing**: Create snapshots of production data for testing environments.

An example workflow is:

```bash
# 1. Create a snapshot
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: longhorn
  source:
    persistentVolumeClaimName: my-pvc

# 2. Restore from snapshot (create new PVC)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Requirements for using snapshots:**

- **CSI Driver**: Your storage provider must support CSI snapshots (Longhorn, Ceph/Rook,
  AWS EBS, GCE PD, etc.)
- **Snapshot Controller**: Usually installed by default in modern Kubernetes clusters
- **VolumeSnapshotClass**: Must be configured for your storage provider

### Snapshot vs Backup

| Feature           | Volume Snapshot           | Backup (to external storage) |
| ----------------- | ------------------------- | ---------------------------- |
| Speed             | Very fast (copy-on-write) | Slower (full data transfer)  |
| Location          | Same storage system       | External storage (S3, NFS)   |
| Disaster Recovery | No (same infrastructure)  | Yes (off-site)               |
| Use Case          | Quick rollback, cloning   | DR, long-term retention      |

/// admonition | Important Notes on Snapshots
    type: warning

- Snapshots are **not backups** - they usually live on the same storage infrastructure.
- For true DR, use both snapshots (fast recovery) and backups (off-site protection).
- Snapshot size and retention depend on your storage system's implementation.
- Most systems use copy-on-write, so initial snapshots are very small.

///

Volume Snapshots are essentially a Kubernetes-standard way to tell your storage system
"save the current state of this volume so I can restore it later or create copies from
it.".

````bash
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: longhorn-test-snapshot
spec:
  volumeSnapshotClassName: longhorn
  source:
    persistentVolumeClaimName: longhorn-test-pvc
````

```bash
# Create a snapshot
kubectl apply -f examples/14-longhorn/test-volume-snapshot.yaml

# Check snapshot status
kubectl get volumesnapshot

# View in Longhorn UI: Volume → Select volume → Create Snapshot
```

### Restore from Snapshot

````bash
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  dataSource:
    name: longhorn-test-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi
````

```bash
# Restore from snapshot
kubectl apply -f examples/14-longhorn/03-restore-from-snapshot.yaml

# Create a pod using the restored volume
kubectl run restored-pod --image=nginx:stable-alpine --overrides='
{
  "spec": {
    "containers": [{
      "name": "nginx",
      "image": "nginx:stable-alpine",
      "volumeMounts": [{
        "mountPath": "/usr/share/nginx/html",
        "name": "restored-vol"
      }]
    }],
    "volumes": [{
      "name": "restored-vol",
      "persistentVolumeClaim": {
        "claimName": "restored-pvc"
      }
    }]
  }
}'

# Verify data was restored
kubectl exec -it restored-pod -- cat /usr/share/nginx/html/index.html
```

## Using Backups in Longhorn

For this, you'll need an S3-compatible storage or NFS server. For learning, you can set up MinIO:

````bash
apiVersion: v1
kind: Namespace
metadata:
  name: minio
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
spec:
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: "minioadmin"
        - name: MINIO_ROOT_PASSWORD
          value: "minioadmin"
        ports:
        - containerPort: 9000
        - containerPort: 9001
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
spec:
  type: NodePort
  ports:
  - port: 9000
    targetPort: 9000
    protocol: TCP
    name: api
  - port: 9001
    targetPort: 9001
    protocol: TCP
    name: console
  selector:
    app: minio
````

```bash
# Deploy MinIO
kubectl apply -f examples/14-longhorn/04-minio-backup.yaml

# Get MinIO console NodePort
kubectl get svc -n minio minio

# Access MinIO console at http://<node-ip>:<console-nodeport>
# Create a bucket called "longhorn-backups"

# Configure Longhorn backup target in the UI:
# Settings → General → Backup Target
# s3://longhorn-backups@us-east-1/
# Backup Target Credential Secret: minio-secret
```

### Key Concepts to Explore

1. **Replicas**: Longhorn replicates data across nodes. Check the Longhorn UI to see replicas for each volume.

2. **Storage Classes**: Longhorn creates a default `longhorn` storage class. You can create custom classes with different replica counts:

````bash
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-replicas-2
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880"
  fromBackup: ""
````

3. **Volume Expansion**: Longhorn supports expanding volumes without downtime.

4. **Disaster Recovery**: Practice backing up volumes and restoring them.

### Troubleshooting

```bash
# Check Longhorn system logs
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100

# Check volume status
kubectl get pv,pvc -A

# Describe a specific volume
kubectl describe pvc longhorn-test-pvc
```

### Clean Up

```bash
# Delete test resources
kubectl delete -f examples/14-longhorn/01-test-pvc.yaml
kubectl delete pvc restored-pvc
kubectl delete volumesnapshot longhorn-test-snapshot

# Uninstall Longhorn (if needed)
kubectl delete -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml

# Or with Helm
helm uninstall longhorn -n longhorn-system
```

This should give you a solid foundation for learning Longhorn! The web UI is particularly helpful for visualizing storage operations.

RobertoPrevato: I don't want to use MinIO. Tell me more about the option of using a NFS server.

GitHub Copilot: # Using NFS as Longhorn Backup Target

Using an NFS server is a simpler alternative to MinIO for Longhorn backups. Here's how to set it up.

## Option 1: NFS Server on Your Host Machine

The easiest approach is to set up an NFS server directly on your Ubuntu host machine.

### Install and Configure NFS Server on Host

```bash
# On your host machine (Ubuntu 24.04)
sudo apt update
sudo apt install -y nfs-kernel-server

# Create a directory for Longhorn backups
sudo mkdir -p /srv/nfs/longhorn-backups
sudo chown nobody:nogroup /srv/nfs/longhorn-backups
sudo chmod 777 /srv/nfs/longhorn-backups

# Configure NFS exports
# Allow access from your VM network (192.168.122.0/24)
echo "/srv/nfs/longhorn-backups 192.168.122.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Apply the configuration
sudo exportfs -ra

# Restart NFS server
sudo systemctl restart nfs-kernel-server

# Verify NFS is running
sudo systemctl status nfs-kernel-server

# Check exports
sudo exportfs -v
```

### Test NFS Mount from a Node

```bash
# From any worker node, test mounting the NFS share
sudo mkdir -p /mnt/test-nfs
sudo mount -t nfs 192.168.122.1:/srv/nfs/longhorn-backups /mnt/test-nfs

# Write a test file
echo "NFS test" | sudo tee /mnt/test-nfs/test.txt

# Unmount
sudo umount /mnt/test-nfs

# Verify on host that file exists
cat /srv/nfs/longhorn-backups/test.txt
```

### Configure Longhorn to Use NFS Backup Target

```bash
# From your host machine
# Access Longhorn UI via port-forward or NodePort
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Open browser: http://localhost:8080
# Navigate to: Setting → General → Backup Target
# Set Backup Target to:
# nfs://192.168.122.1:/srv/nfs/longhorn-backups
```

Or configure via kubectl:

```bash
kubectl -n longhorn-system patch settings.longhorn.io backup-target \
  --type merge \
  --patch '{"value": "nfs://192.168.122.1:/srv/nfs/longhorn-backups"}'
```

## Option 2: NFS Server as a Pod in Kubernetes

If you prefer to keep everything within Kubernetes, you can deploy an NFS server as a
pod.

### Deploy NFS Server in Kubernetes

````yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nfs-server
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
  namespace: nfs-server
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-server
  namespace: nfs-server
spec:
  selector:
    matchLabels:
      app: nfs-server
  template:
    metadata:
      labels:
        app: nfs-server
    spec:
      containers:
      - name: nfs-server
        image: itsthenetwork/nfs-server-alpine:latest
        ports:
        - name: nfs
          containerPort: 2049
        - name: mountd
          containerPort: 20048
        - name: rpcbind
          containerPort: 111
        securityContext:
          privileged: true
        env:
        - name: SHARED_DIRECTORY
          value: /exports
        volumeMounts:
        - name: nfs-storage
          mountPath: /exports
      volumes:
      - name: nfs-storage
        persistentVolumeClaim:
          claimName: nfs-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nfs-server
  namespace: nfs-server
spec:
  type: ClusterIP
  ports:
  - name: nfs
    port: 2049
    targetPort: 2049
  - name: mountd
    port: 20048
    targetPort: 20048
  - name: rpcbind
    port: 111
    targetPort: 111
  selector:
    app: nfs-server
````

```bash
# Deploy NFS server
kubectl apply -f examples/14-longhorn/05-nfs-server.yaml

# Wait for NFS server to be ready
kubectl get pods -n nfs-server -w

# Get the NFS service cluster IP
NFS_SERVER_IP=$(kubectl get svc -n nfs-server nfs-server -o jsonpath='{.spec.clusterIP}')
echo "NFS Server IP: $NFS_SERVER_IP"

# Configure Longhorn backup target
kubectl -n longhorn-system patch settings.longhorn.io backup-target \
  --type merge \
  --patch "{\"value\": \"nfs://${NFS_SERVER_IP}:/exports\"}"
```

## Testing Backups

Once you've configured the NFS backup target, test the backup functionality:

### Create a Backup

```bash
# Create a test volume if you haven't already
kubectl apply -f examples/14-longhorn/01-test-pvc.yaml

# Write some data
kubectl exec -it volume-test -- sh -c "echo 'Important data!' > /usr/share/nginx/html/backup-test.txt"

# In Longhorn UI:
# 1. Go to Volume tab
# 2. Select your volume (pvc-xxx)
# 3. Click "Create Backup"
# 4. Add a label (optional)

# Or via kubectl (create a backup using snapshot first)
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Backup
metadata:
  name: test-backup
  namespace: longhorn-system
spec:
  snapshotName: snapshot-$(date +%s)
  volumeName: pvc-xxxxx  # Replace with actual volume name
EOF
```

### List Backups

```bash
# Via kubectl
kubectl get backups -n longhorn-system

# Check NFS share on host
ls -la /srv/nfs/longhorn-backups/backupstore/
```

### Restore from Backup

```bash
# In Longhorn UI:
# 1. Go to Backup tab
# 2. Select your backup
# 3. Click "Restore"
# 4. Name the restored volume

# Create a PVC from the restored volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-from-backup
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  volumeName: restored-volume-name  # Use the volume name from Longhorn UI
  resources:
    requests:
      storage: 2Gi
EOF
```

## Advantages of NFS for Learning

1. **Simplicity**: Easy to set up and understand.
2. **No cloud dependencies**: Works entirely on your local machine.
3. **Easy inspection**: You can directly browse backup files on the host.
4. **Cost**: Free, no cloud storage costs.

## NFS Backup Structure

Longhorn creates a structured backup format on NFS:

```
/srv/nfs/longhorn-backups/
└── backupstore/
    ├── volumes/
    │   └── pvc-xxxxx/
    │       ├── volume.cfg
    │       ├── backup_backup-xxxxx.cfg
    │       └── blocks/
    └── locks/
```

## Monitoring and Maintenance

```bash
# Check backup target status
kubectl -n longhorn-system get settings.longhorn.io backup-target -o yaml

# View backup storage usage on host
du -sh /srv/nfs/longhorn-backups/

# Clean up old backups (in Longhorn UI or via kubectl)
kubectl delete backup <backup-name> -n longhorn-system
```

## Troubleshooting NFS Issues

```bash
# On host: Check NFS server logs
sudo journalctl -u nfs-kernel-server -f

# On host: Verify NFS exports
sudo exportfs -v

# On node: Test NFS connectivity
showmount -e 192.168.122.1

# Check Longhorn manager logs for NFS-related errors
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100 | grep -i nfs
```

The NFS approach is much simpler than MinIO for learning purposes and gives you direct access to backup files for inspection!

RobertoPrevato: For my host, is there any GUI utility for Ubuntu 24.04 to see all NFS shares on the system?

GitHub Copilot: Yes, there are several GUI options for managing and viewing NFS shares on Ubuntu 24.04:

## Option 1: GNOME Disks (Pre-installed)

The simplest option that's already available on Ubuntu Desktop 24.04:

```bash
# Launch from command line
gnome-disks
```

Or search for "Disks" in your applications menu. However, this primarily shows mounted filesystems rather than NFS exports configuration.

## Option 2: NFS-Ganesha Manager (Recommended for NFS Management)

For dedicated NFS management with a GUI:

```bash
# Install Webmin (web-based system administration)
wget https://prdownloads.sourceforge.net/webadmin/webmin_2.111_all.deb
sudo apt install ./webmin_2.111_all.deb

# Access at: https://localhost:10000
# Login with your system credentials
# Navigate to: Servers → NFS Exports
```

## Option 3: System-config-nfs (Lightweight GUI Tool)

```bash
# Install system-config-nfs
sudo apt update
sudo apt install -y system-config-nfs

# Launch the application
sudo system-config-nfs
```

This provides a simple GUI to:
- View existing NFS exports
- Add/remove NFS shares
- Configure export options (rw, sync, no_root_squash, etc.)

## Option 4: Nautilus (File Manager) - View Mounted Shares

For viewing mounted NFS shares (from client perspective):

```bash
# Open file manager
nautilus

# Go to: Other Locations → Connect to Server
# Enter: nfs://192.168.122.1/srv/nfs/longhorn-backups
```

## Option 5: Custom Script with Zenity (Quick View)

Create a simple script to view NFS exports:

````bash
#!/bin/bash

# Get NFS exports
exports=$(sudo exportfs -v)

# Display in GUI dialog
zenity --text-info \
    --title="NFS Exports on $(hostname)" \
    --width=800 \
    --height=600 \
    --filename=<(echo "$exports")
````

```bash
# Make executable
chmod +x scripts/view-nfs-exports.sh

# Run it
./scripts/view-nfs-exports.sh
```

## Best Recommendation for Your Use Case

For **viewing and managing NFS exports** on your host, I recommend **system-config-nfs** because it:

1. ✅ Is lightweight and simple
2. ✅ Shows all NFS exports clearly
3. ✅ Allows easy editing of export options
4. ✅ Doesn't require a web browser
5. ✅ Integrates well with Ubuntu Desktop

```bash
# Quick install and launch
sudo apt install -y system-config-nfs
sudo system-config-nfs
```

Alternatively, if you just want to **quickly check your exports** without installing anything:

```bash
# View in terminal
sudo exportfs -v

# Or with better formatting
sudo cat /etc/exports
```

For your Longhorn backup scenario, you can verify your NFS export is working with:

```bash
# Check if NFS server is running
sudo systemctl status nfs-kernel-server

# View active exports
sudo exportfs -v

# Test from another machine
showmount -e 192.168.122.1
```

## Alternatives

| Solution        | Type              | License         | Storage Types       | Key Features                                        | Best For                                     |
| --------------- | ----------------- | --------------- | ------------------- | --------------------------------------------------- | -------------------------------------------- |
| **Longhorn**    | Block Storage     | Apache 2.0      | Block               | Lightweight, easy setup, web UI, snapshots, backups | Small to medium clusters, edge computing     |
| **Rook (Ceph)** | Multi-purpose     | Apache 2.0      | Block, File, Object | Enterprise-grade, highly scalable, self-healing     | Large production clusters, multi-tenant      |
| **OpenEBS**     | Multi-engine      | Apache 2.0      | Block               | Multiple storage engines, Mayastor (NVMe), LocalPV  | Flexible deployments, high-performance needs |
| **Portworx**    | Enterprise        | Commercial      | Block, File         | Auto-pilot, disaster recovery, multi-cloud          | Enterprise production, mission-critical apps |
| **StorageOS**   | Block Storage     | Commercial      | Block               | Low latency, compression, encryption                | Performance-critical workloads               |
| **MinIO**       | Object Storage    | AGPL/Commercial | Object              | S3-compatible, erasure coding, multi-cloud          | Object storage, data lakes, backup targets   |
| **GlusterFS**   | Distributed FS    | GPL             | File                | Scale-out NAS, POSIX-compliant                      | Traditional file storage needs               |
| **TopoLVM**     | LVM Manager       | Apache 2.0      | Block               | Capacity-aware scheduling, thin provisioning        | Leveraging existing LVM infrastructure       |
| **Ceph CSI**    | Block/File/Object | Apache 2.0      | Block, File, Object | Direct Ceph integration without Rook                | Existing Ceph clusters                       |

**Key Considerations:**

- **Longhorn** and **OpenEBS** are the easiest to get started with for learning and development.
- **Rook/Ceph** is the most feature-complete open-source solution but has higher complexity.
- **Portworx** and **StorageOS** offer commercial support and advanced features.
- **MinIO** offers an S3-compatible object storage.
- **TopoLVM** works well if you already have LVM configured on your nodes.

## Next Steps
