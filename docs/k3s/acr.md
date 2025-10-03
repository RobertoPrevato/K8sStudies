In this quick exercise, I want to learn how to pull images from an Azure Container
Registry inside my Kubernetes cluster on-premises. For simplicity, I will use username
and password authentication to *push* images to the registry, even though I could use
RBAC and the Azure CLI. Then I will use RBAC to *pull* images from the container
registry into Kubernetes, using an Entra ID app registration and a secret. Managed
Identities cannot be used in this scenario because the K3s cluster is running
on-premises, outside of Azure. Managed Identities only work for Azure resources (like
Azure VMs, AKS clusters, Azure Container Instances, etc.) that are running within
Azure's infrastructure.

## Create an Azure Container Registry

Create an Azure Container Registry, and give it a desired name. I leave the option that
provides a domain name `<your-acr-name>.azurecr.io`.

Navigate to *Access keys* in the Azure Portal, and enable the Admin user.

![ACR Access Keys](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/de6a659039f390cc7ed62dfa2bd2a3c062ed1944/acr-01.png)

## Push An Image

For testing purposes, I will push a Docker image to the Azure Container Registry using
the Docker CLI. I will:

1. Pull my Fortune Cookies Docker Image from Docker Hub.
2. **Tag it** properly, to support pushing to the Azure Container Registry.
3. **Push it** to the Azure Container Registry.
4. Later pull that image in my Kubernetes cluster.

Of course, the first step could be replaced by building a Docker image from a
Dockerfile.

Copy one of the two passwords from the Azure Portal, then sign-in to the Azure Container
Registry with the Docker CLI using the following commands:

```bash
service_name="<your-acr-name>"

# Docker will prompt for password…
docker login $service_name.azurecr.io --username $service_name
```

You can verify what images you have using `docker images`. For the sake of the example,
I will pull my Fortune Cookies app from Docker Hub and follow the steps described above:

```bash
docker pull robertoprevato/fortunecookies:0.0.2

# tag it so it can be pushed to the ACR…
docker tag robertoprevato/fortunecookies:0.0.2 $service_name.azurecr.io/fortunecookies:0.0.2

# push to ACR…
docker push $service_name.azurecr.io/fortunecookies:0.0.2
```

The image will be pushed to the ACR.

![ACR Repositories](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/de6a659039f390cc7ed62dfa2bd2a3c062ed1944/acr-02.png)

## Using RBAC In K8s

We _**could**_ use the admin credentials in Kubernetes to pull the images from the
Container Registry, but that would be an abomination as Kubernetes needs only read
access to pull the images. It would be an abomination in terms of security and the
_principle of least privilege_.

As described earlier, Managed Identities cannot be used in this scenario because the K3s
cluster is running on-premises, outside of Azure.

So, I will:

1. Create an **App Registration** in **Entra ID** from a computer where I have the Azure CLI
   installed, and obtain a secret for that App Registration.
1. Grant the necessary rights to *pull* images from the container registry to the
   **service principal** of the App Registration (**_Enterprise Application_**).
1. Configure the secret as **secret** inside Kubernetes.
1. Use the Application ID and secret to sign-in into Kubernetes to *pull* images from
   my ACR.
1. Create a new deployment of my Fortune Cookies app in a different namespace, this time
   pulling the image from ACR.

With PowerShell Core:

```ps1
$service_name="<your-acr-name>"

$ACR_REGISTRY_ID=$(az acr show --name $service_name --query "id" --output tsv)

# Create service principal with AcrPull role
$SP_PASSWD=$(az ad sp create-for-rbac `
  --name "$service_name-acr-sp" `
  --scopes $ACR_REGISTRY_ID `
  --role acrpull `
  --query "password" `
  --output tsv)

# Get the service principal ID
$SP_APP_ID=$(az ad sp list `
  --display-name "$service_name-acr-sp" `
  --query "[].appId" `
  --output tsv)
```

Take note of the service principal ID and password, in `$SP_PASSWD` and `$SP_APP_ID`.
These will be configured as secrets in Kubernetes, so it can pull images from the ACR.

For this exercise, I am going to use the namespace `acrtest` for Kubernetes.
Create the namespace and a secret using the proper values, like in the example below:

```bash
namespace="acrtest"

kubectl create namespace $namespace

kubectl create secret docker-registry acr-secret \
  --docker-server=<your-acr-name>.azurecr.io \
  --docker-username="<SP_ID>" \
  --docker-password="<SP_PASS>" \
  --namespace=$namespace
```

Include the secret in the deployment manifest, in the `template.spec` section:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: acr-secret
      containers:
        - name: your-app
          image: <your-acr-name>.azurecr.io/your-image:tag
```

A full example is provided in `./examples/10-acr/cookies.yaml`, just update it to use
the correct ACR name. **Note**: the manifest example already has the namespace "acrtest"
specified in its metadata sections.

```bash
kubectl apply -f cookies.yaml

deployment.apps/fortune-cookies-acr created
service/fortune-cookies-acr created
persistentvolumeclaim/cookies-pvc created
ingress.networking.k8s.io/fortune-cookies-acr-ingress created
```

Check if the pod is running:

```
kubectl get pods -n acrtest
NAME                                  READY   STATUS    RESTARTS   AGE
fortune-cookies-acr-85fc4c5cf-zppx7   1/1     Running   0          21s
```

Verify that the Docker Image was pulled from the private ACR:

```bash
kubectl describe pod fortune-cookies-acr-85fc4c5cf-zppx7 -n acrtest
```

The output should include this information:

```bash
Successfully pulled image "<your-acr-name>.azurecr.io/fortunecookies:0.0.2" in 787ms (787ms including waiting). Image size: 150639434 bytes.
```

Test picking a cookie:

```bash
curl -H "Host: cookies.acr.test" 'http://<YOUR_SERVER_NAME>/api/cookies/pick'
{"id":48,"text":"Quality, not quantity, is what matters."}
```

It works! :tada: :tada:

## Bonus

If you followed the exercise regarding [monitoring](./monitoring.md), you should also
see logs generated in a dedicated namespace in Grafana.

![New ACR Test in Grafana](https://gist.githubusercontent.com/RobertoPrevato/38a0598b515a2f7257c614938843b99b/raw/61569ae7ccd5d02c3de45016abcd4abfe6be1469/grafana-acrtest.png)

## Summary

This exercise demonstrates how to integrate an on-premises Kubernetes cluster with Azure
Container Registry (ACR) for secure image management. Key takeaways:

**Authentication Approaches**

- **For pushing images**: Used admin credentials for simplicity during development
- **For pulling images in K8s**: Implemented RBAC with service principals for security
- **Managed Identities**: Not available for on-premises clusters (Azure resources only)

**Security Best Practices**

- Created dedicated service principal with minimal permissions (`AcrPull` role only)
- Used Kubernetes secrets to securely store ACR credentials
- Avoided using admin credentials in production workloads

**Implementation Steps**

1. **Setup**: Created ACR and enabled admin user for initial setup
2. **Image Management**: Tagged and pushed Docker Hub image to private ACR
3. **RBAC Configuration**: Created service principal with least-privilege access
4. **K8s Integration**: Configured `imagePullSecrets` in deployment manifests
5. **Verification**: Confirmed successful image pulls and application functionality

**Benefits Achieved**

- **Private registry**: Images stored securely in a Azure subscription
- **Access control**: Fine-grained permissions via Azure RBAC
- **Audit trail**: All registry operations tracked in Azure logs
- **Integration**: Seamless workflow between on-premises K8s and Azure services

This pattern is ideal for hybrid scenarios where you want to leverage Azure's managed
container registry while maintaining on-premises Kubernetes infrastructure.

## Next Steps

A possible next step in this thread, is learning how to self-host private Docker
registries, maybe using the official [Docker Registry image](https://hub.docker.com/_/registry)
and hosting it in a dedicated Kubernetes cluster.
