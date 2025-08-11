Now I want to try the Zalando PostgreSQL operator, which is another interesting
operator for managing PostgreSQL clusters in Kubernetes. I headed towards the
[_Quickstart guide_](https://opensource.zalando.com/postgres-operator/docs/quickstart.html),
and tried following the steps to use it in a kind cluster.

```bash
kind create cluster --name zalandopg

kubectl cluster-info --context kind-zalandopg
```

## Quickstart

### Install the operator

I decided to use the manual way of installing the operator and using the
_Kustomize_, like documented:

```bash
kubectl apply -k github.com/zalando/postgres-operator/manifests
```

Check if the operator pod starts:

```bash
watch kubectl get pod -l name=postgres-operator
```

In case of issues, check the logs of the operator pod:

```bash
kubectl logs "$(kubectl get pod -l name=postgres-operator --output='name')"
```

/// details | About Kustomize.

Kustomize is a tool that allows you to customize Kubernetes YAML configurations
without the need to modify the original files. It is built into `kubectl` and
provides a way to manage Kubernetes resources in a more flexible and reusable
manner. Kustomize allows you to create overlays, which are modifications to the
base configurations, enabling you to apply different settings for different
environments or use cases without duplicating the entire configuration.

Read more about Kustomize in the [Kustomize documentation](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/).

///

### Create a PostgreSQL Cluster

Create a cluster using the minimal example:

```bash
kubectl apply -f https://raw.githubusercontent.com/zalando/postgres-operator/refs/heads/master/manifests/minimal-postgres-manifest.yaml
```

At the time of this writing, the minimal manifest looks like this:

```yaml
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: acid-minimal-cluster
spec:
  teamId: "acid"
  volume:
    size: 1Gi
  numberOfInstances: 2
  users:
    zalando:  # database owner
    - superuser
    - createdb
    foo_user: []  # role for application foo
  databases:
    foo: zalando  # dbname: owner
  preparedDatabases:
    bar: {}
  postgresql:
    version: "17"
```

After several seconds, you should see running pods:

```bash {hl_lines="3-4"}
kubectl get pods
NAME                                 READY   STATUS    RESTARTS      AGE
acid-minimal-cluster-0               1/1     Running   0             3m37s
acid-minimal-cluster-1               1/1     Running   0             40s
postgres-operator-849bdbdbd8-2r2pz   1/1     Running   1 (10m ago)   11m
```

### Connect to the cluster

Connecting to the cluster using `port-forward` proved to be more complicated
than expected. At first I tried to obtain the list of services, and use
`kubectl port-forward` to connect to the PostgreSQL service, but that fails
with: _error: cannot attach to *v1.Service: invalid service
'acid-minimal-cluster': Service is defined without a selector_.

I read about this issue in the Zalando documentation and GitHub issues, which explains that
Zalando PostgreSQL clusters do not expose a service for the master pod by
default. Instead, you need to connect directly to the master pod.

The following command is used to forward the PostgreSQL port from the Zalando PostgreSQL cluster to the local machine:

```bash
cluster_name="acid-minimal-cluster"

kubectl port-forward $(kubectl get pod -l cluster-name=$cluster_name,spilo-role=master -o jsonpath='{.items[0].metadata.name}') 5432:5432
```

In another terminal:

```bash
cluster_name="acid-minimal-cluster"
# obtain the password:
user="zalando"
export PGPASSWORD=$(kubectl get secret $user.$cluster_name.credentials.postgresql.acid.zalan.do -o 'jsonpath={.data.password}' | base64 -d)

# connect to the database using psql
psql -h localhost -U $user -d foo
```

You should enter the PostgreSQL shell, and you can run `\l` to list the databases:

```sql
psql (17.5 (Ubuntu 17.5-1.pgdg24.04+1), server 17.2 (Ubuntu 17.2-1.pgdg22.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

foo=# \l
                                                      List of databases
   Name    |   Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
-----------+-----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 bar       | bar_owner | UTF8     | libc            | en_US.utf-8 | en_US.utf-8 |        |           |
 foo       | zalando   | UTF8     | libc            | en_US.utf-8 | en_US.utf-8 |        |           |
 postgres  | postgres  | UTF8     | libc            | en_US.utf-8 | en_US.utf-8 |        |           |
 template0 | postgres  | UTF8     | libc            | en_US.utf-8 | en_US.utf-8 |        |           | =c/postgres          +
           |           |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres  | UTF8     | libc            | en_US.utf-8 | en_US.utf-8 |        |           | =c/postgres          +
           |           |          |                 |             |             |        |           | postgres=CTc/postgres
(5 rows)
```

Let's create a table and insert some data:

```sql
CREATE TABLE cookie (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL
);

INSERT INTO cookie (text) VALUES ('You will eat more cookies today.');

INSERT INTO cookie (text) VALUES ('Sleep more.');

SELECT * FROM cookie;
```

### Verify replication

Now let's verify that the replication works by connecting to the second pod in
the cluster, to verify that the `cookie` table is replicated:

```bash
# inspect the labels of the pods
kubectl get pods --show-labels

cluster_name="acid-minimal-cluster"
kubectl port-forward $(kubectl get pod -l cluster-name=$cluster_name,spilo-role=replica -o jsonpath='{.items[0].metadata.name}') 5432
```

The table was replicated, and we can see the data:

```
psql -h localhost -U zalando -d foo
psql (17.5 (Ubuntu 17.5-1.pgdg24.04+1), server 17.2 (Ubuntu 17.2-1.pgdg22.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

foo=# \dt
         List of relations
 Schema |  Name  | Type  |  Owner
--------+--------+-------+---------
 public | cookie | table | zalando
(1 row)

foo=# select * from cookie;
 id |               text
----+----------------------------------
  1 | You will eat more cookies today.
  2 | Sleep more.
(2 rows)
```

Verify that you are connected to the replica pod:

```sql {hl_lines="2"}
foo=# INSERT INTO cookie (text) VALUES ('This should not work.');
ERROR:  cannot execute INSERT in a read-only transaction
```

Wonderful!

## Reading time…

The first impressions are great, and

## Include a Load Balancer

To include a Load Balancer with Zalando PostgreSQL operator, you should modify
the operator's configuration to expose the `master` instance. This
documentation describes how to configure the operator:
[Configuration parameters](https://opensource.zalando.com/postgres-operator/docs/reference/operator_parameters.html),
and the setting of interest in this case is:
`enable_master_load_balancer`, that must be set to `true` in the
`postgres-operator` configuration.

To follow more easily, clone the Zalando's repository, using
`--depth` to avoid downloading the entire history:

```bash
git clone --depth 10 https://github.com/zalando/postgres-operator.git
```

### Modify the operator configuration

Navigate to the `manifests` directory in the cloned repository:

```bash
cd postgres-operator/manifests
```

Edit the file `configmap.yaml` file to enable a load balancer:

```yaml
  enable_master_load_balancer: "true"
```

Apply the modified configuration:

```bash
# examples/07-zalandopg
kubectl apply -f configmap.yaml
```

Now, I was wondering if the operator would automatically pick up the new
configuration, and the answer is **no**, because of the issue described here:
[Operator ignores OperatorConfiguration changes #1315](https://github.com/zalando/postgres-operator/issues/1315).

To apply the new configuration, you can force the recreation of the operator pod:

```bash
kubectl delete pod -l name=postgres-operator
```

Remember to run the `cloud-provider-kind` in a different terminal, so that the
new Load Balancer can receive an _External IP_. Then check the services:

```bash {hl_lines="3"}
$ kubectl get svc
NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
acid-minimal-cluster          LoadBalancer   10.96.104.207   172.18.0.5    5432:31691/TCP   8h
acid-minimal-cluster-config   ClusterIP      None            <none>        <none>           8h
acid-minimal-cluster-repl     ClusterIP      10.96.22.218    <none>        5432/TCP         8h
kubernetes                    ClusterIP      10.96.0.1       <none>        443/TCP          8h
postgres-operator             ClusterIP      10.96.116.206   <none>        8080/TCP         8h
```

Let's try to connect to the PostgreSQL cluster using the Load Balancer:

```bash
LB_IP=$(kubectl get svc acid-minimal-cluster -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

export PGPASSWORD=$(kubectl get secret zalando.acid-minimal-cluster.credentials.postgresql.acid.zalan.do -o 'jsonpath={.data.password}' | base64 -d)

psql -h $LB_IP -U zalando -d foo
```

And... :boom: :boom:! It doesn't work. I needed to investigate why the connection
fails. I couldn't find the information in the documentation, but I
found the answer looking at GitHub issues. The best instruction was here:
[_issue #2365_](https://github.com/zalando/postgres-operator/issues/2365).

Modify the `minimal-postgres-manifest.yaml` file to include the desired allowed
[CIDR ranges](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing):

```yaml {linenums=1 hl_lines="7-8"}
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: acid-minimal-cluster
spec:
  teamId: "acid"
  allowedSourceRanges:
  - 0.0.0.0/0  # allow all IPs to connect
  volume:
    size: 1Gi
  numberOfInstances: 2
  users:
    zalando:  # database owner
    - superuser
    - createdb
    foo_user: []  # role for application foo
  databases:
    foo: zalando  # dbname: owner
  preparedDatabases:
    bar: {}
  postgresql:
    version: "17"
```

For **local development** purposes, I am allowing all IPs (`0.0.0.0/0`).
Apply the modified manifest:

```bash
# examples/07-zalandopg
kubectl apply -f minimal-postgres-manifest.yaml
```

Now try to connect again, it should work:

```bash
psql -h 172.18.0.5 -U $user -d foo
psql (17.5 (Ubuntu 17.5-1.pgdg24.04+1), server 17.2 (Ubuntu 17.2-1.pgdg22.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

foo=#
```

Hurray! :tada:

## Share storage for local development

I wanted to try again what I wanted to do with [_CloudNativePG_](./cloudnativepg.md#share-storage-for-local-development),

```mermaid
flowchart TD
    subgraph Host Machine
        direction LR
        subgraph /home/pgdata/
            A1[/instance-1/]
            A2[/instance-2/]
            A3[/instance-3/]
        end
    end

    subgraph "Kubernetes Cluster (Kind)"
        direction LR
        P1["**Pod: 1**<br/>(PostgreSQL Instance 1)"]
        P2["**Pod: 2**<br/>(PostgreSQL Instance 2)"]
        P3["**Pod: 3**<br/>(PostgreSQL Instance 3)"]
    end

    P1 ---|volume mount| A1
    P2 ---|volume mount| A2
    P3 ---|volume mount| A3
```




## The documentation is not great

The documentation is not great. :fontawesome-regular-thumbs-down: I needed to
google and rely on GitHub issues to learn more about how configuration changes
are applied and how to configure a useful load balancer. The documentation is
not very detailed.

## Confusing configuration

What is the difference between *pooler* and not **pooler** load balancer?

- `enable_replica_load_balancer`
- `enable_replica_pooler_load_balancer`

And these two:

- `enable_master_load_balancer`
- `enable_master_pooler_load_balancer`

## A look at GitHub issues

- [Operator ignores OperatorConfiguration changes #1315](https://github.com/zalando/postgres-operator/issues/1315).
- [Question: Can load balancers only be accessed from outside via node port?](https://github.com/zalando/postgres-operator/issues/2365).
