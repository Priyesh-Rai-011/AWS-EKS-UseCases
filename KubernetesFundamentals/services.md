# Things I learn along the way.

```
        +----------------------------------------------------------------------------+
        | Category                 | Components                                      |
        |                          |                                                 |
        | ------------------------ | ----------------------------------------------- |
        | Core Services            | ClusterIP, NodePort, LoadBalancer, ExternalName |
        |----------------------------------------------------------------------------|
        | Routing                  | Ingress, Gateway API                            |
        |----------------------------------------------------------------------------|
        | Security                 | NetworkPolicy                                   |
        |----------------------------------------------------------------------------|
        | Service Discovery        | CoreDNS                                         |
        |----------------------------------------------------------------------------|
        | Stateful Networking      | Headless Services                               |
        |----------------------------------------------------------------------------|
        | Advanced Traffic Control | Service Mesh                                    |
        +----------------------------------------------------------------------------+
```

ClusterIP             ==           NodePort                 <>==>                    ExternalName
ClusterIP is the default one to be created. 

---

```
For users to FrontEnd --------------->   NodePort  /  LoadBalancer  /  Ingress


For FrontEnd to Backend ------------->   Cluster IP


For the Backend to database (RDS) ---->  ExternalName
```