Previously I tested **CloudNativePG** [in Kind](../kind/cloudnativepg.md).
Now I want to try again CloudNativePG, but this time running in K3s. I am still
interested in a single-node setup, I'll keep multi-nodes setup for later.
I will also look into how to configure monitoring and backups.

## Installing CNPG

Install the CloudNativePG operator:

```bash
kubectl apply --server-side -f \
    https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.0.yaml

# check for the status
kubectl rollout status deployment -n cnpg-system cnpg-controller-manager
```

The output of the final command should say: _deployment
"cnpg-controller-manager" successfully rolled out_.

Create a deployment for local development, or suitable for DEV/TEST environments:

```bash
# ./examples/11-cloudnativepg
kubectl create namespace cnpg

kubectl apply -f cluster-01.yaml
```

## Connect to the server

List the secrets that were created:

```bash
kubectl get secret -n cnpg
```

```bash
# Get the password of the super user:
PGPASSWORD=$(kubectl get secret -n cnpg pgcluster-superuser -o jsonpath="{.data.password}" | base64 -d)

# Or get the password of the app user:
PGPASSWORD=$(kubectl get secret -n cnpg pgcluster-app -o jsonpath="{.data.password}" | base64 -d)
```

Connect using `pgsql` (if you don't have it installed, follow my previous exercise when I deployed CNPG in Kind):

```bash
PGPASSWORD=$PGPASSWORD psql -h localhost -p 5432 -U postgres postgres
```

```
$ PGPASSWORD=$PGPASSWORD psql -h localhost -p 5432 -U postgres postgres
psql (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

postgres=#
```

/// admonition | Why localhost works.
    type: warning

The `localhost` connection works because of how K3s handles LoadBalancer services.

K3s includes a built-in load balancer called **Klipper** that automatically:

1. Assigns LoadBalancer services to `localhost` (127.0.0.1)
2. Maps the service port to a random high port on the host
3. Makes the service accessible via `localhost:port`

**To see the actual mapping:**

```bash
# Check the external IP and port assigned
kubectl get svc -n cnpg cnpg-rw

# You'll see something like:
# NAME      TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
# cnpg-rw   LoadBalancer   10.43.x.x     localhost     5432:32001/TCP   5m
```

In this case, you could also connect using:
```bash
PGPASSWORD=$PGPASSWORD psql -h localhost -p 32001 -U postgres postgres
```

**In other Kubernetes distributions:**
- You'd get a real external IP (like `192.168.1.100`)
- You'd need to use that IP instead of localhost
- Or use port-forwarding: `kubectl port-forward svc/cnpg-rw 5432:5432 -n cnpg`

**K3s convenience:** K3s automatically port-forwards LoadBalancer services to localhost,
which is why your current command works. This is a K3s-specific feature that makes local
development easier.

///

## Monitoring CNPG

How can I configure my CloudNativePG to send metrics to the OpenTelemetry Collector or
directly to Prometheus in my monitoring namespace?

Read the documentation here: [_CloudNativePG Monitoring_](https://cloudnative-pg.io/documentation/1.27/monitoring/) and here
[_Quickstart Part 4: Monitor clusters with Prometheus and Grafana_](https://cloudnative-pg.io/documentation/1.27/quickstart/#part-4-monitor-clusters-with-prometheus-and-grafana).

My first attempts here didn't produce satisfying results, because in my previous
[_Monitoring_](./monitoring.md) exercise I installed the plain-vanilla Prometheus Helm
chart in Kubernetes. This requires manual configuration for many things. Make sure to
follow the section [_Improved Monitoring_](./monitoring.md#improved-monitoring), too.

Enabling monitoring is pretty simple:

```yaml {hl_lines="8-10"}
…
spec:
  instances: 1
  enableSuperuserAccess: true
  storage:
    size: 2Gi

  # Enable monitoring - metrics will be available on port 9187
  monitoring:
    enablePodMonitor: true
…
```

```bash
kubectl apply -f cluster-02.yaml
```

### Install the Grafana Dashboard

CloudNativePG offers a configuration file to create a dashboard in Grafana. It is
documented here:
[https://cloudnative-pg.io/documentation/1.27/monitoring/](https://cloudnative-pg.io/documentation/1.27/monitoring/).
The configuration file can be downloaded from :

[https://github.com/cloudnative-pg/grafana-dashboards/blob/main/charts/cluster/grafana-dashboard.json](https://github.com/cloudnative-pg/grafana-dashboards/blob/main/charts/cluster/grafana-dashboard.json)

You can import the dashboard in Grafana at: _Dashboards > New > Import_.

![CNPG Grafana Dashboard](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/14c6d63398a18a2ef7993d15d645366d79dbca56/cnpg-grafana-dashboard.png)

If you followed the instructions at [_Improved
Monitoring_](./monitoring.md#improved-monitoring), the dashboard should work immediately
when imported.

## Enabling Back-Ups

Reading time… [_CNPG backup_](https://cloudnative-pg.io/documentation/1.27/backup/).

---
