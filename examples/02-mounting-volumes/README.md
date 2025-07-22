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

Funziona!

![alt text](image.png)

## After a reboot

After a reboot, the container does not work. To investigate:

```bash
kubectl get pods -n fortunecookies
```

```bash
NAME                               READY   STATUS             RESTARTS   AGE
fortune-cookies-6595576d44-6zwcv   0/1     CrashLoopBackOff   0          21h
```

What is the meaning of `CrashLoopBackOff`?

In this case, it is because the `cookies` application is using `:latest` tag and
Kubernetes will try again to pull it from Docker Hub.

To fix, as we don't need to pull the image again:

```
