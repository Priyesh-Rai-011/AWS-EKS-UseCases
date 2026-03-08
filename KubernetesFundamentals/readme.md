<!--we -->
## Let's understand the kubernetes fundamentals. [   Things I learned along the way   ]

### 1. Kubernetes PODs

- pods generally have one to one relationship with containers.
- To scale up the application -> we create new pods.
- TO scale down the application -> we delete the pods.

- We DO NOT have multiple containers of same kind in a single POD.
- Example : Tow NGINX container

#### But can we have multiple containers in a single POD? : YES ..!!

- Kubernetes natively support multiple identical containers sharing the same:
    - IP/port namespace.
    - Both Nginx instances would bind to ports 80/443 on the pod's single IP (e.g., 10.244.1.5), handle requests via **kernel load balancing**, and share volumes/signals. 
Use case: temporary redundancy, A/B testing same app version, or horizontal scaling within a pod.
<!-- ```
Pod Reality (Multi-Container Native):
+------------------------------------------------------------------------------------+
| Pod: ecommerce-frontend                                                            |
|                                                                                    |
|  +---------------+  +---------------+           +---------------+  +-------------+ |
|  | Container 1   |  | Container 1   |           | Container 2   |  | Container 3 | |
|  | nginx:1.25    |  | nginx:1.25    |           | istio-proxy   |  | fluentd     | |
|  | (web server)  |  | (web server)  |← Both on  | (envoy)       |  | (logs)      | |
|  +---------------+  +---------------+  pod IP   +---------------+  +-------------+ |                   |
|                                          |                                         |
| Shared: 10.244.1.5 IP, localhost:80 → kernel LB                                    |
|                                                                                    |
|  ALL share: 10.244.1.5 IP, /data volume, signals                                   |
+------------------------------------------------------------------------------------+
``` -->
---


<table>
<tr>
<td><b>Pod Reality (Visual)</b></td>
<td><b>Pod Specification (YAML)</b></td>
</tr>
<tr><td><pre>

```
Pod: ecommerce-frontend

Pod Reality (Multi-Container Native):
+------------------------------------------------------------------------------------+
| Pod: ecommerce-frontend                                                            |
|                                                                                    |
|  +---------------+  +---------------+           +---------------+  +-------------+ |
|  | Container 1   |  | Container 1   |           | Container 2   |  | Container 3 | |
|  | nginx:1.25    |  | nginx:1.25    |           | istio-proxy   |  | fluentd     | |
|  | (web server)  |  | (web server)  |← Both on  | (envoy)       |  | (logs)      | |
|  +---------------+  +---------------+  pod IP   +---------------+  +-------------+ |
|                                          |                                         |
| Shared: 10.244.1.5 IP, localhost:80 → kernel LB                                    |
|                                                                                    |
|  ALL share: 10.244.1.5 IP, /data volume, signals                                   |
+------------------------------------------------------------------------------------+
```
</pre></td>
<td>

```
apiVersion: v1
kind: Pod
metadata:
  name: dual-nginx
spec:
  containers:
  - name: nginx-1
    image: nginx:1.25
    ports: [{containerPort: 80}]
  - name: nginx-2  
    image: nginx:1.25
    ports: [{containerPort: 80}]
```
</td></tr>
</table>
<!-- -----------=============================================================================================-------------------------- -->
Industry standards favor one main app container per pod for production scalability and high availability, using multi-container pods mainly for tightly coupled helpers like proxies (Istio Envoy), loggers (Fluentd), or adapters—not duplicates of the same app image.



- We can have multiple containers in a single POD, provided they are **not of same kind (service)**
- Helper conatiner (  Side-Cars  )
    - Data-pullers : Pull data required by many containers
    - Data-pushers : Push data to the service conatianer from main container (logs)
    - Proxies      : Writes static data to HTML files using. 
                     Helper container and reads using main container.

                     Istio is a very good example of Service mesh Envoy Proxy.
      <img width="26%" height="26%" alt="Image" src="https://github.com/user-attachments/assets/73a8c5db-c7e7-4f19-abe4-cb6d479562a9" />


- #### What is a Sidecar?
  A sidecar is an extra container in the same Kubernetes pod as your main app container, sharing the same network namespace but running separately. It "sits beside" your app to handle auxiliary tasks like proxying traffic (Envoy in Istio), logging, or monitoring—your app talks normally, but all traffic routes through the sidecar.


<table>
<tr>
<td><b>Pod Reality (Visual)</b></td>
<td><b>How these side car containers are defined :</b></td>
</tr>
<tr><td><pre>

```
Kubernetes Pod (one unit scheduled together)
+------------------------------------------------------+
| Pod: my-app-pod                                      |
|                                                      |
|  +----------------------------+  +----------------+  |
|  | Main App Container         |  | Sidecar        |  |
|  |                            |  | (Envoy Proxy)  |  |
|  | - Runs your business logic |  | - Intercepts   |  |
|  |                            |  |   all traffic  |  |
|  |    (e.g., Node.js app)     |  | - Applies      |  |
|  |                            |  |   Istio rules  |  |
|  +----------------------------+  +----------------+  |
|                                                      |
|  Shared: localhost network, IPC, volumes             |
+------------------------------------------------------+
Traffic Flow: External → Sidecar → Main App → Sidecar → Other Services
```
</pre></td>
<td>

```
Example Pod with Istio Sidecar (YAML snippet view):
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  containers:
  - name: main-app          # Your app (e.g., Node.js)
    image: myapp:1.0
  - name: istio-proxy       # Auto-injected sidecar
    image: envoyproxy/envoy  # Handles traffic/security
---    
Result: Multi-container pod runs both seamlessly.
```

</td></tr>
</table>