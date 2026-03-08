<!--we -->
## Let's understand the kubernetes fundamentals. [   Things I learned along the way   ]

#### 1. Kubernetes PODs

- pods generally have one to one relationship with containers.
- To scale up the application -> we create new pods.
- TO scale down the application -> we delete the pods.

- We DO NOT have multiple containers of same kind in a single POD.
- Example : Tow NGINX container

#### But can we have multiple containers in a single POD? : YES ..!!

- We can have multiple containers in a single POD, provided they are **not of same kind (service)**
- Helper conatiner (  Side-Cars  )
    - Data-pullers : Pull data required by many containers
    - Data-pushers : Push data to the service conatianer from main container (logs)
    - Proxies      : Writes static data to HTML files using. 
                     Helper container and reads using main container.

                     Istio is avery good example of Service mesh Envoy Proxy.
      <img width="550" height="429" alt="Image" src="https://github.com/user-attachments/assets/73a8c5db-c7e7-4f19-abe4-cb6d479562a9" />
