https://medium.com/@gayatripawar401/deploy-prometheus-and-grafana-on-kubernetes-using-helm-5aa9d4fbae66

## Installing Helm

---


RobertoPrevato: How can I access Prometheus UI after installing it in K3s with the community Helm?

GitHub Copilot: After installing Prometheus in K3s using the community Helm chart, you can access the Prometheus UI by port-forwarding the Prometheus server service to your local machine. Here’s how:

1. **Find the Prometheus server service name:**
   ```sh
   kubectl get svc -n monitoring
   ```
   (Assuming you installed Prometheus in the `monitoring` namespace.)

2. **Port-forward the service to your local machine:**
   ```sh
   kubectl port-forward -n monitoring svc/prometheus-server 9090:80
   ```
   - If the service is named differently (e.g., `prometheus-kube-prometheus-prometheus`), adjust the command accordingly.

3. **Access the UI:**
   - Open your browser and go to: [http://localhost:9090](http://localhost:9090)

**Tip:** If you used a different namespace or Helm release name, update the commands to match your setup.

RobertoPrevato: How can I use ingress to permanently expose the server instead of using port forwarding?

GitHub Copilot: To expose Prometheus permanently using an Ingress in K3s, follow these steps:

1. **Ensure an Ingress controller is installed**
   K3s comes with Traefik as the default Ingress controller. If you disabled it, install an Ingress controller first.

2. **Install Prometheus with Ingress enabled**
   If you haven’t installed Prometheus yet, you can enable Ingress via Helm values:
   ```sh
   helm install prometheus prometheus-community/prometheus \
     --namespace monitoring --create-namespace \
     --set server.ingress.enabled=true \
     --set server.ingress.hosts={prometheus.local}
   ```
   Replace `prometheus.local` with your desired hostname.

   If Prometheus is already installed, you can upgrade with:
   ```sh
   helm upgrade prometheus prometheus-community/prometheus \
     --namespace monitoring \
     --set server.ingress.enabled=true \
     --set server.ingress.hosts={prometheus.local}
   ```

3. **Update your local DNS (for testing)**
   Add an entry to hosts:
   ```
   127.0.0.1 prometheus.local
   ```
   (Or use your cluster’s external IP if available.)

4. **Access Prometheus**
   Open [http://prometheus.local](http://prometheus.local) in your browser.

**Note:**
- For production, configure a real DNS record and TLS as needed.
- You can customize the Ingress further using Helm values (e.g., `server.ingress.annotations` for Traefik or NGINX-specific settings).

RobertoPrevato: Is it possible to do something similar with Grafana when installing with:
helm install grafana grafana/grafana

?

GitHub Copilot: Yes, you can expose Grafana using an Ingress when installing with Helm. Here’s how:

**1. Install Grafana with Ingress enabled:**
```sh
helm install grafana grafana/grafana \
  --namespace monitoring --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hosts={grafana.local}
```
Replace `grafana.local` with your preferred hostname.

**2. Update your hosts (for local testing):**
```
127.0.0.1 grafana.local
```

**3. Access Grafana:**
Open [http://grafana.local](http://grafana.local) in your browser.

**Notes:**
- You can customize the Ingress further with `ingress.annotations` and `ingress.tls` Helm values.
- For production, use a real DNS name and configure TLS as needed.

```bash

```

```
helm install grafana grafana/grafana \
  --namespace monitoring --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hosts={grafana.local}

helm upgrade grafana grafana/grafana \
  --set ingress.enabled=true \
  --set ingress.hosts={grafana.local} \
  --set persistence.enabled=true \
  --set persistence.size=10Gi
```
