After the previous exercise, where I configured nodes for a Kubernetes cluster:
one control plane and three workers, I need a way to administer all machines at once,
when I want to install additional tools into nodes. I decided to learn more about
**Ansible**.

This is a follow-up of my previous exercise in which I started practicing with
[_KVM and kubeadm_](./index.md).

**Starting all VMs:**

```bash
for VM in control-plane worker-1 worker-2 worker-3; do
  echo "Starting VM: $VM"
  sudo virsh start $VM
done

```

**Stopping all VMs:**

```bash
for VM in control-plane worker-1 worker-2 worker-3; do
  echo "Stopping VM: $VM"
  sudo virsh shutdown $VM
done
```

## Ansible

**Install Ansible on the Ubuntu 24.04 Host:**

```bash
# On your Ubuntu 24.04 host
sudo apt update
sudo apt install -y ansible

# Verify installation
ansible --version
```

**Create the Ansible Inventory File:**

```ini
[control_plane]
control-plane ansible_host=192.168.122.10 ansible_user=ro

[workers]
worker-1 ansible_host=192.168.122.11 ansible_user=ro
worker-2 ansible_host=192.168.122.12 ansible_user=ro
worker-3 ansible_host=192.168.122.13 ansible_user=ro

[k8s_cluster:children]
control_plane
workers

[k8s_cluster:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

**Test Ansible Connectivity:**

```bash
$ ansible -i inventory.ini k8s_cluster -m ping
worker-3 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
worker-1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
worker-2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
control-plane | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**Useful Ansible Example Commands:**

```bash
# Run a command on all nodes
ansible -i inventory.ini k8s_cluster -a "hostname -I"

# Check disk usage on all nodes
ansible -i inventory.ini k8s_cluster -a "df -h"

# Check if open-iscsi is installed
ansible -i inventory.ini k8s_cluster -m shell -a "dpkg -l | grep open-iscsi"

# Check service status
ansible -i inventory.ini k8s_cluster -m shell -a "systemctl status iscsid" -b

# Run commands only on workers
ansible -i inventory.ini workers -a "uptime"

# Copy a file to all nodes
ansible -i inventory.ini k8s_cluster -m copy -a "src=/local/file dest=/remote/path" -b
```

**Advantages of Using Ansible**

Ansible provides several key benefits for infrastructure management. Commands run in
parallel across all nodes simultaneously, significantly reducing execution time. The
platform is idempotent, making it safe to run operations multiple times without causing
issues. Playbooks serve as living documentation for your infrastructure, making it easy
to understand and reproduce configurations. Once created, playbooks are reusable across
different environments and projects. Additionally, playbooks can be stored in git
alongside your project, enabling collaboration and change tracking.

## Next steps

Practice with [distributed object stores and backups](./distributed-storage.md).
