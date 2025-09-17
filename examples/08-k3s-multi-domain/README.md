This example shows how to deploy two web workloads, each exposed at their own domain,
having ingress rules configured in the same namespace of the application workload.

```mermaid
graph LR
    client1["HTTP&nbsp;https:&sol;&sol;**orange**&period;neoteroi&period;xyz"] --> orange_ingress["Orange Ingress"]
    client2["HTTP&nbsp;https:&sol;&sol;**teal**&period;neoteroi&period;xyz"] --> teal_ingress["Teal Ingress"]

    subgraph "Ingress Rules"
        direction TB
        orange_ingress
        teal_ingress
    end

    subgraph "Servers"
        A["Orange Web App"]
        B["Teal Web App"]
    end

    orange_ingress -->|&nbsp;/*&nbsp;| A
    teal_ingress -->|&nbsp;/*&nbsp;| B
```

## Requirement

Set this in your `hosts` file:

```
127.0.0.1  orange.neoteroi.xyz
127.0.0.1  www.orange.neoteroi.xyz
127.0.0.1  teal.neoteroi.xyz
127.0.0.1  www.teal.neoteroi.xyz
```

On Linux, this file is located at `/etc/hosts`.
On Windows, this file is located at `C:\Windows\System32\drivers\etc\hosts`.
