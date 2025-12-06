Now that I have a multi-nodes Kubernetes cluster running in KVM, I want to practice with
[Longhorn](https://longhorn.io/). Longhorn is a lightweight, reliable distributed block
storage system for Kubernetes. Created by the same authors of K3s,
[Rancher](https://www.rancher.com/index.php/products/longhorn). Longhorn provides:

- **Distributed storage** across your cluster nodes.
- **Volume replication** for high availability.
- **Backup and restore** capabilities.
- **Snapshots** for point-in-time recovery.
- **Web UI** for easy management.

## Requirements

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

Using node port:

```bash
# Expose Longhorn UI via NodePort
kubectl expose deployment longhorn-ui -n longhorn-system --type=NodePort --name=longhorn-ui-nodeport

# Get the NodePort
kubectl get svc -n longhorn-system longhorn-ui-nodeport

# Access via: http://<node-ip>:<nodeport>
# For example: http://192.168.122.11:31234
```

Or, for a permanent solution, configure an ingress:

```bash
# Apply the ingress configuration
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

Update the hosts file this way:

```bash
# common ingress for web traffic
192.168.122.52 longhorn.local
```

Navigate with a browser to `http://longhorn.local`.

![Longhorn UI](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/420727d6dbadc0c5dbf9f14985ec166b7d5c8c4b/longhorn-ui-01.png).

## Practice Exercise

### Create a Test Application with Persistent Storage

````bash {hl_lines="8"}
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
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
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
kubectl apply -f examples/14-longhorn/01-test-pvc.yaml

# Check PVC status
kubectl get pvc longhorn-test-pvc

# Write some data to the volume
kubectl exec -it volume-test -- sh -c "echo 'Hello from Longhorn!' > /usr/share/nginx/html/index.html"

# Verify the data
kubectl exec -it volume-test -- cat /usr/share/nginx/html/index.html
```

### Test Data Persistence

```bash
# Delete the pod
kubectl delete pod volume-test

# Recreate the pod (using the same PVC)
kubectl apply -f examples/14-longhorn/01-test-pvc.yaml

# Verify data survived pod deletion
kubectl exec -it volume-test -- cat /usr/share/nginx/html/index.html
```

### Create Volume Snapshots

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
kubectl apply -f examples/14-longhorn/02-snapshot.yaml

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

### Configure Backup Target

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

## Key Concepts to Explore

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

## Troubleshooting

```bash
# Check Longhorn system logs
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100

# Check volume status
kubectl get pv,pvc -A

# Describe a specific volume
kubectl describe pvc longhorn-test-pvc
```

## Clean Up

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
