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

## Backup

Reading time…

- [_CNPG backup_](https://cloudnative-pg.io/documentation/1.27/backup/).
- [_CloudNativePG Barman Cloud CNPG-I plugin_](https://cloudnative-pg.io/plugin-barman-cloud/docs/concepts/)

CloudNativePG offers different ways to enable backups. For now, I want to enable full
backups to an `Azure Storage Account`.

/// admonition | Alternatives.
    type: example

If I wanted to store backups locally, I would check how to use _Longhorn_
and _volume snapshots_. For now, it is simpler to use an object store like Azure Storage
Account or AWS S3. There is the option of using _MinIO_, but I prefer avoiding this tool
because I am wary of the practices of its maintainers[<sup>1</sup>](https://github.com/minio/object-browser/issues/3546).

///

### Install the Barman Plugin

Install the Barman Plugin following the instructions here:

https://cloudnative-pg.io/plugin-barman-cloud/docs/installation/

Summary:

1. Verify to run a version of CloudNativePG >= `1.26.0`.
2. Verify that `cert-manager` is installed and available.

```bash
# verify it is installed…
cmctl check api
```

`cert-manager` is a tool that creates TLS certificates for workloads in Kubernetes or
OpenShift clusters and renews the certificates before they expire.

In my case, the `cert-manager` was not installed anywhere: I didn't have the client
installed in my host, nor the `cert-manager` component in my K3s cluster.

Install the client in your host:

```bash
# install…
brew install cmctl
```

After installing, I get this error because `cert-manager` is not installed in my cluster:

```bash
cmctl check api
error: error finding the scope of the object: failed to get restmapping: unable to retrieve the complete list of server APIs: cert-manager.io/v1: no matches for cert-manager.io/v1, Resource=
```

Install the component in the cluster:

1. Check what is the latest release here [on GitHub.](https://github.com/cert-manager/cert-manager/releases/).
   At the time of this writing, it's `1.19.1`.
2. Install it using the commands below.

```bash
# install
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.yaml

# verify installation…
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=60s
```

The cert-manager installation automatically creates:
- `cert-manager` namespace
- Custom Resource Definitions (CRDs) - cluster-wide
- ClusterRoles and ClusterRoleBindings - cluster-wide
- cert-manager controller pods in the `cert-manager` namespace

````bash
# Verify the API is working
cmctl check api
````

Then install the Barman plugin in `cnpg-system`:

````bash
# Install the Barman plugin in the cnpg-system namespace (where CNPG operator runs)
kubectl apply -f https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/v0.7.0/manifest.yaml -n cnpg-system
````

The output should look like:

```bash
customresourcedefinition.apiextensions.k8s.io/objectstores.barmancloud.cnpg.io unchanged
serviceaccount/plugin-barman-cloud unchanged
role.rbac.authorization.k8s.io/leader-election-role unchanged
clusterrole.rbac.authorization.k8s.io/metrics-auth-role unchanged
clusterrole.rbac.authorization.k8s.io/metrics-reader unchanged
clusterrole.rbac.authorization.k8s.io/objectstore-editor-role unchanged
clusterrole.rbac.authorization.k8s.io/objectstore-viewer-role unchanged
clusterrole.rbac.authorization.k8s.io/plugin-barman-cloud unchanged
rolebinding.rbac.authorization.k8s.io/leader-election-rolebinding unchanged
clusterrolebinding.rbac.authorization.k8s.io/metrics-auth-rolebinding unchanged
clusterrolebinding.rbac.authorization.k8s.io/plugin-barman-cloud-binding unchanged
secret/plugin-barman-cloud-7g4226tm68 configured
service/barman-cloud unchanged
deployment.apps/barman-cloud unchanged
Warning: spec.privateKey.rotationPolicy: In cert-manager >= v1.18.0, the default value changed from `Never` to `Always`.
certificate.cert-manager.io/barman-cloud-client created
certificate.cert-manager.io/barman-cloud-server created
issuer.cert-manager.io/selfsigned-issuer created
```

Verify the deployment:

```bash
kubectl rollout status deployment -n cnpg-system barman-cloud

# should be:
deployment "barman-cloud" successfully rolled out
```

### Enabling Backups

Now that the Barman Cloud Plugin is installed, I need to define an _ObjectStore_ using
my chosen backend: Azure Blob, like [documented here](https://cloudnative-pg.io/documentation/1.27/appendixes/object_stores/#azure-blob-storage).

Obtain the Storage Account connection string and create a secret in the right namespace
like in the command below:

```bash
CONNSTRING='<conn string>'

kubectl create secret generic azure-creds \
  --from-literal=AZURE_STORAGE_CONNECTION_STRING=$CONNSTRING \
  -n cnpg
```

Deploy the Barman object store like in the provided example:

```bash
# ./examples/11-cloudnativepg
kubectl apply -f barman-store.yaml
```

Enable backups in the CNPG cluster manifest:

```yaml {linenums="1" hl_lines="29-33 35-44"}
# This example is appropriate for a local development environment
# where we use a single node.
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pgcluster
  namespace: cnpg
spec:
  instances: 1
  enableSuperuserAccess: true
  storage:
    size: 2Gi
  # Enable monitoring - metrics will be available on port 9187
  monitoring:
    enablePodMonitor: true
  postgresql:
    parameters:
      pg_stat_statements.max: "10000"
      pg_stat_statements.track: all
  managed:
    services:
      additional:
        - selectorType: rw
          serviceTemplate:
            metadata:
              name: cnpg-rw
            spec:
              type: LoadBalancer
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: backup-store
---
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: daily-backup
  namespace: cnpg
spec:
  schedule: "0 0 0 * * *" # Midnight daily
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
```

The file `./examples/11-cloudnativepg/luster-03.yaml` is a working example to create
base backups and WAL archives to a Barman object store named `backup-store`.

```bash
# ./examples/11-cloudnativepg
kubectl apply -f cluster-03.yaml
```

Start a backup like [documented here](https://cloudnative-pg.io/plugin-barman-cloud/docs/usage/#performing-a-base-backup):

```bash
kubectl apply -f backup.yaml
```

Check the status:

```bash
kubectl get backup -n cnpg
NAME             AGE   CLUSTER     METHOD   PHASE    ERROR
backup-example   16s   pgcluster   plugin   failed   rpc error: code = Unknown desc = missing key AZURE_CONNECTION_STRING, inside secret azure-creds

kubectl describe backup/backup-example -n cnpg
```

It works! :tada: :tada: :tada:.

However, the CNPG dashboard doesn't show backups. To fix, you need to apply the changes
described here: https://github.com/cloudnative-pg/grafana-dashboards/issues/37

> Replace `cnpg_collector_first_recoverability_point` ➔ `barman_cloud_cloudnative_pg_io_first_recoverability_point`
> Replace `cnpg_collector_last_available_backup_timestamp` ➔ `barman_cloud_cloudnative_pg_io_last_available_backup_timestamp`

The `grafana-dashboard.json` file in the examples folder already has the correct values.

The dashboard showing healthy base backups and WAL archiving look like in the following
picture:

![CNPG Grafana Dashboard with Healthy Backups](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/b6488130f40ec813714a781cc5941985e5f04fb8/cnpg-grafana-dashboard-archive.png)

WAL archives are created every minute thanks to this configuration setting:
`archive_timeout: "60s"`, however only if there are transactions.

```yaml {hl_lines="4"}
    parameters:
      pg_stat_statements.max: "10000"
      pg_stat_statements.track: all
      archive_timeout: "60s" # Force WAL switch every minute
```

If the PostgreSQL is not used, yet, generate some activity to verify that WAL archives
are created properly:

```bash
# Create some activity to force WAL generation
PGPASSWORD=$PGPASSWORD psql -h localhost -p 5432 -U postgres postgres
```

```sql
CREATE TABLE IF NOT EXISTS test_wal_activity (id serial, data text, created_at timestamp default now());
INSERT INTO test_wal_activity (data) SELECT 'test data ' || generate_series(1,1000);
```

## Summary

This tutorial successfully demonstrates a CloudNativePG setup in K3s suitable for
non-production environments, covering three main areas: **installation**, **monitoring**,
and **backup configuration**.

### Next steps

In the future I will look into roduction deployments that include:

- Multi-node PostgreSQL clusters for high availability.
- Possibly backups using _Volume Snapshots_.

The complete setup provides a solid foundation for PostgreSQL workloads in Kubernetes
with professional-grade monitoring and backup capabilities.
