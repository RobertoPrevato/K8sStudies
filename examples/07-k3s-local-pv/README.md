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
