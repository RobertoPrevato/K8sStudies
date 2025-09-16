Example of common ingress residing in dedicated namespace, to expose backend
each in their own namespace using `ExternalName` services.

This requires changing the defaults of Traefik to enable `ExternalName` services.

```bash
kubectl apply -f traefik-config.yaml
```

---

```bash
kubectl create namespace fortunecookies

kubectl apply -n fortunecookies -f cookies.yaml

kubectl create namespace common-ingress

cd ssl
kubectl create secret tls neoteroi-xyz-tls \
  --cert=neoteroi-xyz-tls.crt \
  --key=neoteroi-xyz-tls.key \
  -n common-ingress

cd ../
kubectl apply -n common-ingress -f common-ingress.yaml
```
