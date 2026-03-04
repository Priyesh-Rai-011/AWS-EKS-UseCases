##### Just some basic concepts


#### What is the difference b/w Elastic IP [ EIP ] and Elastic Network Interface [ ENI ]
```
EC2 = Server brain
ENI = Network card
Private IP = Internal address
Elastic IP = Public identity
IGW = NAT router
```

#### -----------------------------------------------------------------------------------
#### Outgoing Request (EC2 → Internet)

Now EC2 runs:
```
curl google.com
```
Flow:                                                   Diagrmam:
```
1. EC2 sends packet                                          EC2
      Source = 10.0.1.25                                      │ source:10.0.1.25
                                                              ▼
2. ENI forwards to IGW                                       ENI
                                                              ▼
3. AWS NAT translates source:                               Internet Gateway
                                                              │ (SNAT)
      10.0.1.25 → 15.206.88.200                               ▼
                                                            source becomes:15.206.88.200
                                                              ▼
4. Packet goes to internet                                  Internet
```
#### -----------------------------------------------------------------------------------
#### Incoming Request (Internet → EC2)
User opens browser
```
http://15.206.88.200
```

Packet Jorney:                                              Diagram:
```
1. Internet sends packet                                    Client
                                                               │
      Destination = 15.206.88.200                              ▼
                                                            [15.206.88.200]
2. Internet Gateway receives packet                            │
                                                               ▼
3. AWS checks NAT mapping:                                  Internet Gateway
      15.206.88.200 → 10.0.1.25                                │  (DNAT)
                                                               ▼
4. Destination rewritten (DNAT happens)                     [10.0.1.25]
                                                               │
      NEW destination = 10.0.1.25                              ▼
                                                            ENI → EC2
5. Packet delivered to ENI

6. ENI → EC2 instance
```

#### ENI
An ENI is a virtual network interface attached to an EC2 instance that contains its *networking identity* including private/public IPs, MAC address, security groups, subnet, VPC association, and routing configuration. It appears inside the instance as eth0

#### The overall architectureal flow
```
                                INTERNET
                                    │
                                    │
                    ┌────────────────────────────────┐
                    │        AWS Internet Gateway    │
                    │        (Performs NAT)          │
                    └────────────────────────────────┘
                                    │
                 ┌──────────────────┴──────────────────┐
                 │                                     │
                 │  PUBLIC ADDRESS LAYER (AWS Managed) │
                 │                                     │
                 │   Elastic IP (STATIC)               │
                 │   15.206.88.200                     │
                 │        │                            │
                 │        │  1 : 1 STATIC NAT          │
                 │        ▼                            │
                 │   Private IP (10.0.1.25)           │
                 └──────────────────┬──────────────────┘
                                    │
                                    │ (inside VPC)
                                    ▼

EC2 Instance
   └── ENI (eth0)
          ├─ Private IP : 10.0.1.25
          ├─ Security Group(s)
          └─ Networking Identity {
                ├─ MAC address
                ├─ Subnet association
                ├─ VPC association

                ├─ Dynamic Public IP (OPTIONAL)
                │     3.110.45.10
                │     → Auto-assigned
                │     → Changes on stop/start
                │

                └─ Elastic IP (OPTIONAL - STATIC)
                      15.206.88.200
                      → Manually allocated
                      → Attached to ENI
                      → Never changes
                      → Overrides dynamic public IP
            }


--------------------------------------------------------------------------
An Elastic IP is a static PUBLIC IPv4 address owned by your AWS account.

```