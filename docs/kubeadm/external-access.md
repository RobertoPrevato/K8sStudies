Now that I created a cluster using `kubeadm`, it lacks two components for a complete
solution supporting external access:

An **Ingress Controller** (for HTTP/HTTPS routing).

- Routes external HTTP/HTTPS traffic to services.
- Provides host/path-based routing.
- Handles TLS termination.
- Options: ~~NGINX Ingress~~, Traefik, Cilium, HAProxy.

A **Load Balancer Solution** (for **LoadBalancer** services)

- Provides external IPs for type: **LoadBalancer** services.
- Required because kubeadm clusters don't have a cloud provider.
- Options: **MetalLB** (most popular for bare metal), **kube-vip**, **Cilium**.

---

**MetalLB**, **Kube-VIP**, and **Cilium** offer different approaches to providing bare-metal
Kubernetes services, with MetalLB focusing purely on LoadBalancer Services via L2/BGP
and Kube-VIP excels at HA Control Plane & Services with simpler deployment, while Cilium
integrates load balancing into its CNI. Choose MetalLB for robust, feature-rich service
load balancing; Kube-VIP for simplicity, HA Control Plane needs, or combined use; and
Cilium for deep CNI integration.

## MetalLB

- **Best For:** Dedicated, feature-rich LoadBalancer Services on bare-metal.
- **How it Works:** Uses Layer 2 (ARP/NDP) or BGP to announce IPs for LoadBalancer
  services from a pool.
- **Pros:** Popular, robust, rich features (IPv6, dual-stack), mature, good for diverse
  bare-metal setups.
- **Cons:** Can be more complex to manage than Kube-VIP for basic needs.

## Kube-VIP

- **Best For:** HA Control Plane (VIP for masters) and simpler Service Load Balancing,
  especially in edge/small clusters.
- **How it Works:** Uses VRRP (like Keepalived) for Control Plane HA and can also handle
  services, binding IPs directly to the interface.
- **Pros:** Lightweight, simple, great for HA Control Plane, multi-arch (ARM, x86).
- **Cons:** Service load balancing can be less feature-rich than MetalLB; can conflict
  if both run for services.

## Cilium (as an alternative)

- **Best For:** When you need integrated networking (CNI, Service Mesh, Load Balancing).
- **How it Works:** Centralizes IPAM, BGP, and LB within the Cilium data plane.
- **Pros:** Unified observability, lower latency, simplified operations within a single
  CNI.

## Which to Choose?

- **If you need just LoadBalancer Services:** MetalLB is generally the go-to for its
  maturity and features.
- **If you need HA Control Plane & Services:** Kube-VIP for CP, MetalLB for Services (often
  run together).
- **For Simplicity/Edge:** Kube-VIP offers a very lightweight path.
- **For integrated CNI/LB:** Consider Cilium.

**MetalLB** is the established standard for bare-metal LoadBalancer Services;
**Kube-VIP** is excellent for HA Control Plane VIPs and simpler service needs.

---

## Installing MetalLB

MetalLB provides a network load balancer implementation for bare-metal Kubernetes
clusters. It allows you to create Kubernetes services of type `LoadBalancer` in
environments that don't have native support for load balancers (like cloud providers
do).

### Prerequisites

- A running kubeadm cluster with nodes having connectivity to each other
- IP address range available for MetalLB to use (should not conflict with existing network ranges)

### Installation Steps

**1. Install MetalLB using the manifest:**

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

This creates the `metallb-system` namespace and deploys the MetalLB controller and
speaker components.

**2. Verify the installation:**

```bash
# Check that the pods are running
kubectl get pods -n metallb-system

# You should see output similar to:
# NAME                          READY   STATUS    RESTARTS   AGE
# controller-xxxxxxxx-xxxxx     1/1     Running   0          30s
# speaker-xxxxx                 1/1     Running   0          30s
# speaker-xxxxx                 1/1     Running   0          30s
# speaker-xxxxx                 1/1     Running   0          30s
```

Wait until all pods are in `Running` state before proceeding.

**3. Configure MetalLB with an IP address pool:**

MetalLB needs to know which IP addresses it can allocate. For your KVM cluster using the
`192.168.122.0/24` network, you should choose a range that:

- Is within your virtual network subnet
- Doesn't conflict with existing static IPs (control-plane: .10, workers: .11-.13)
- Isn't used by the DHCP server

For a learning/development environment, allocate a generous range like
`192.168.122.50-192.168.122.200`, which provides 151 IP addresses. This gives you plenty
of room to experiment with multiple LoadBalancer services without running out of IPs.

For production or more constrained environments, you might use a smaller range, but for
learning purposes, it's better to have more IPs available than you think you'll need.

Create a configuration file:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.122.50-192.168.122.200
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
```

**Explanation:**

- **IPAddressPool**: Defines the range of IP addresses MetalLB can assign to
  LoadBalancer services
- **L2Advertisement**: Configures MetalLB to use Layer 2 mode (ARP/NDP) to announce the
  IPs on your local network

**4. Verify the configuration:**

```bash
# Check the IP address pool
kubectl get ipaddresspool -n metallb-system

# Check the L2 advertisement
kubectl get l2advertisement -n metallb-system
```

### Testing MetalLB

Deploy a test service to verify MetalLB is working:

```bash
# Create a simple nginx deployment
kubectl create deployment nginx-test --image=nginx

# Expose it as a LoadBalancer service
kubectl expose deployment nginx-test --port=80 --type=LoadBalancer

# Check the service - it should get an EXTERNAL-IP from the MetalLB pool
kubectl get svc nginx-test

# Example output:
# NAME         TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)        AGE
# nginx-test   LoadBalancer   10.96.123.45    192.168.122.50    80:31234/TCP   10s
```

Test accessing the service from your host machine, using the external IP obtained with
the command above. You should see the NGINX welcome page.

Clean up the test:

```bash
kubectl delete service nginx-test
kubectl delete deployment nginx-test
```

### Layer 2 Mode vs BGP Mode

MetalLB supports two modes:

**Layer 2 Mode (what we configured):**
- Simpler to set up, no router configuration needed
- Uses ARP/NDP to announce IPs
- One node responds to ARP requests for the service IP
- If that node fails, another node takes over (automatic failover)
- Good for simple networks and learning environments

**BGP Mode:**
- Requires BGP-capable routers
- Provides true load balancing across multiple nodes
- Better for production environments with proper network infrastructure
- More complex to configure

For your KVM-based learning cluster, Layer 2 mode is the recommended choice.

### Adjusting the IP Range

If you need to modify the IP address pool later:

```bash
# Edit the IPAddressPool
kubectl edit ipaddresspool default-pool -n metallb-system

# Or delete and recreate with a new range
kubectl delete ipaddresspool default-pool -n metallb-system
kubectl apply -f <new-config.yaml>
```

### Important Notes

- **IP Address Conflicts**: Ensure the MetalLB IP range doesn't overlap with:
  - Node static IPs (192.168.122.10-13 in your setup)
  - DHCP pool (check your virtual network configuration)
  - Any other services on the network

- **Network Accessibility**: The assigned IPs are accessible from:
  - The host machine
  - All cluster nodes
  - Any machine on the same virtual network

- **Persistence**: MetalLB configurations persist across cluster restarts

## Next steps

Practice with [**Ansible**](./ansible.md) and with [**Longhorn**](./longhorn.md).
