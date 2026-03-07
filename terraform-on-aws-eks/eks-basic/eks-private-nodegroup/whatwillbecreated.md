```
PS C:\Users\KIIT\Desktop\Everything\AWSEKS\terraform-on-aws-eks\eks-basic\eks-private-nodegroup> terraform apply
module.bastion.data.aws_ami.amazon_linux_2023: Reading...
module.vpc.data.aws_availability_zones.available: Reading...
module.vpc.data.aws_availability_zones.available: Read complete after 0s [id=ap-south-1]
module.bastion.data.aws_ami.amazon_linux_2023: Read complete after 0s [id=ami-0e267a9919cdf778f]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.bastion.aws_iam_instance_profile.bastion_instance_profile will be created
  + resource "aws_iam_instance_profile" "bastion_instance_profile" {
      + arn         = (known after apply)
      + create_date = (known after apply)
      + id          = (known after apply)
      + name        = "eks-dev-bastion-bastion-instance-profile"
      + name_prefix = (known after apply)
      + path        = "/"
      + role        = "eks-dev-bastion-bastion-ssm-role"
      + tags        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-instance-profile"
        }
      + tags_all    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-instance-profile"
        }
      + unique_id   = (known after apply)
    }

  # module.bastion.aws_iam_role.bastion_ssm_role will be created
  + resource "aws_iam_role" "bastion_ssm_role" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "ec2.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "eks-dev-bastion-bastion-ssm-role"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-ssm-role"
        }
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-ssm-role"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.bastion.aws_iam_role_policy_attachment.bastion_ssm_policy will be created
  + resource "aws_iam_role_policy_attachment" "bastion_ssm_policy" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      + role       = "eks-dev-bastion-bastion-ssm-role"
    }

  # module.bastion.aws_instance.bastion will be created
  + resource "aws_instance" "bastion" {
      + ami                                  = "ami-0e267a9919cdf778f"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = (known after apply)
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = "eks-dev-bastion-bastion-instance-profile"
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_lifecycle                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t3.micro"
      + ipv6_address_count                   = (known after apply)
      + ipv6_addresses                       = (known after apply)
      + key_name                             = (known after apply)
      + monitoring                           = (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      + placement_partition_number           = (known after apply)
      + primary_network_interface_id         = (known after apply)
      + private_dns                          = (known after apply)
      + private_ip                           = (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      + secondary_private_ips                = (known after apply)
      + security_groups                      = (known after apply)
      + source_dest_check                    = true
      + spot_instance_request_id             = (known after apply)
      + subnet_id                            = (known after apply)
      + tags                                 = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-host"
          + "Role"        = "Bastion"
        }
      + tags_all                             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-host"
          + "Role"        = "Bastion"
        }
      + tenancy                              = (known after apply)
      + user_data                            = "eaeee7c37352847d318cab3a16c1f9b481af8b07"
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = false
      + vpc_security_group_ids               = (known after apply)

      + capacity_reservation_specification (known after apply)

      + cpu_options (known after apply)

      + ebs_block_device (known after apply)

      + enclave_options (known after apply)

      + ephemeral_block_device (known after apply)

      + instance_market_options (known after apply)

      + maintenance_options (known after apply)

      + metadata_options (known after apply)

      + network_interface (known after apply)

      + private_dns_name_options (known after apply)

      + root_block_device {
          + delete_on_termination = true
          + device_name           = (known after apply)
          + encrypted             = true
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + tags                  = {
              + "Environment" = "dev"
              + "ManagedBy"   = "Terraform"
              + "Name"        = "eks-dev-bastion-bastion-volume"
            }
          + tags_all              = (known after apply)
          + throughput            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = 20
          + volume_type           = "gp3"
        }
    }

  # module.bastion.aws_security_group.bastion_sg will be created
  + resource "aws_security_group" "bastion_sg" {
      + arn                    = (known after apply)
      + description            = "Bastion host SG - no inbound needed, SSM uses outbound 443 only"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = "Allow outbound HTTPS to reach AWS SSM service endpoints"
              + from_port        = 443
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 443
            },
        ]
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = "eks-dev-bastion-bastion-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-sg"
        }
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-bastion-bastion-sg"
        }
      + vpc_id                 = (known after apply)
    }

  # module.eks.aws_eks_addon.core_dns will be created
  + resource "aws_eks_addon" "core_dns" {
      + addon_name                  = "coredns"
      + addon_version               = "v1.12.1-eksbuild.2"
      + arn                         = (known after apply)
      + cluster_name                = "eks-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + resolve_conflicts_on_update = "PRESERVE"
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
    }

  # module.eks.aws_eks_addon.ebs_csi_driver will be created
  + resource "aws_eks_addon" "ebs_csi_driver" {
      + addon_name                  = "aws-ebs-csi-driver"
      + addon_version               = "v1.45.0-eksbuild.2"
      + arn                         = (known after apply)
      + cluster_name                = "eks-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + resolve_conflicts_on_update = "PRESERVE"
      + service_account_role_arn    = (known after apply)
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
    }

  # module.eks.aws_eks_addon.kube_proxy will be created
  + resource "aws_eks_addon" "kube_proxy" {
      + addon_name                  = "kube-proxy"
      + addon_version               = "v1.33.0-eksbuild.2"
      + arn                         = (known after apply)
      + cluster_name                = "eks-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + resolve_conflicts_on_update = "PRESERVE"
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
    }

  # module.eks.aws_eks_addon.metric_server will be created
  + resource "aws_eks_addon" "metric_server" {
      + addon_name                  = "metrics-server"
      + addon_version               = "v0.7.2-eksbuild.1"
      + arn                         = (known after apply)
      + cluster_name                = "eks-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + resolve_conflicts_on_update = "PRESERVE"
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
    }

  # module.eks.aws_eks_addon.vpc_cni will be created
  + resource "aws_eks_addon" "vpc_cni" {
      + addon_name                  = "vpc-cni"
      + addon_version               = "v1.19.5-eksbuild.3"
      + arn                         = (known after apply)
      + cluster_name                = "eks-dev"
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + resolve_conflicts_on_update = "PRESERVE"
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
        }
    }

  # module.eks.aws_eks_cluster.basic_eks_cluster will be created
  + resource "aws_eks_cluster" "basic_eks_cluster" {
      + arn                           = (known after apply)
      + bootstrap_self_managed_addons = true
      + certificate_authority         = (known after apply)
      + cluster_id                    = (known after apply)
      + created_at                    = (known after apply)
      + endpoint                      = (known after apply)
      + id                            = (known after apply)
      + identity                      = (known after apply)
      + name                          = "eks-dev"
      + platform_version              = (known after apply)
      + role_arn                      = (known after apply)
      + status                        = (known after apply)
      + tags                          = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev"
        }
      + tags_all                      = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev"
        }
      + version                       = "1.33"

      + access_config (known after apply)

      + kubernetes_network_config (known after apply)

      + upgrade_policy (known after apply)

      + vpc_config {
          + cluster_security_group_id = (known after apply)
          + endpoint_private_access   = true
          + endpoint_public_access    = true
          + public_access_cidrs       = (known after apply)
          + security_group_ids        = (known after apply)
          + subnet_ids                = (known after apply)
          + vpc_id                    = (known after apply)
        }
    }

  # module.eks.aws_eks_node_group.private_node_group will be created
  + resource "aws_eks_node_group" "private_node_group" {
      + ami_type               = "AL2023_x86_64_STANDARD"
      + arn                    = (known after apply)
      + capacity_type          = (known after apply)
      + cluster_name           = "eks-dev"
      + disk_size              = 20
      + id                     = (known after apply)
      + instance_types         = [
          + "t3.medium",
        ]
      + labels                 = {
          + "role" = "system"
        }
      + node_group_name        = "eks-dev-system-ng"
      + node_group_name_prefix = (known after apply)
      + node_role_arn          = (known after apply)
      + release_version        = (known after apply)
      + resources              = (known after apply)
      + status                 = (known after apply)
      + subnet_ids             = (known after apply)
      + tags                   = {
          + "Environment"            = "dev"
          + "ManagedBy"              = "Terraform"
          + "Name"                   = "eks-dev-system-node"
          + "karpenter.sh/discovery" = "eks-dev"
        }
      + tags_all               = {
          + "Environment"            = "dev"
          + "ManagedBy"              = "Terraform"
          + "Name"                   = "eks-dev-system-node"
          + "karpenter.sh/discovery" = "eks-dev"
        }
      + version                = (known after apply)

      + node_repair_config (known after apply)

      + scaling_config {
          + desired_size = 2
          + max_size     = 2
          + min_size     = 2
        }

      + taint {
          + effect = "NO_SCHEDULE"
          + key    = "CriticalAddonsOnly"
          + value  = "true"
        }

      + update_config {
          + max_unavailable = 1
        }
    }

  # module.eks.aws_iam_role.ebs_csi_driver_role will be created
  + resource "aws_iam_role" "ebs_csi_driver_role" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "eks.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "Assumed by EBS CSI Driver addon to create and manage EBS volumes"
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "eks-dev-ebs-csi-role"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-ebs-csi-role"
        }
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-ebs-csi-role"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.eks.aws_iam_role.eks_cluster_role will be created
  + resource "aws_iam_role" "eks_cluster_role" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "eks.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "Assumed by EKS control plane to manage AWS resources in your VPC"
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "eks-dev-cluster-role"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-cluster-role"
        }
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-cluster-role"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.eks.aws_iam_role.eks_node_group_role will be created
  + resource "aws_iam_role" "eks_node_group_role" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "ec2.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "Assumed by EC2 worker nodes to join the cluster and access AWS services"
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "eks-dev-node-role"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-node-role"
        }
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-node-role"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.eks.aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy will be created
  + resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      + role       = "eks-dev-cluster-role"
    }

  # module.eks.aws_iam_role_policy_attachment.ebs_csi_AmazonEBSCSIDriverPolicy will be created
  + resource "aws_iam_role_policy_attachment" "ebs_csi_AmazonEBSCSIDriverPolicy" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      + role       = "eks-dev-ebs-csi-role"
    }

  # module.eks.aws_iam_role_policy_attachment.eks_AmazonEKSVPCResourceController will be created
  + resource "aws_iam_role_policy_attachment" "eks_AmazonEKSVPCResourceController" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
      + role       = "eks-dev-cluster-role"
    }

  # module.eks.aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy will be created
  + resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      + role       = "eks-dev-node-role"
    }

  # module.eks.aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy will be created
  + resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      + role       = "eks-dev-node-role"
    }

  # module.eks.aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore will be created
  + resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      + role       = "eks-dev-node-role"
    }

  # module.eks.aws_iam_role_policy_attachment.node_EC2ContainerRegistryReadOnly will be created
  + resource "aws_iam_role_policy_attachment" "node_EC2ContainerRegistryReadOnly" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      + role       = "eks-dev-node-role"
    }

  # module.eks.aws_security_group.private_link_sg will be created
  + resource "aws_security_group" "private_link_sg" {
      + arn                    = (known after apply)
      + description            = "Attached to the PrivateLink ENI. Allows nodes and pods to reach EKS API server on 443."
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
                # (1 unchanged attribute hidden)
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "10.0.11.0/24",
                  + "10.0.12.0/24",
                  + "10.0.13.0/24",
                ]
              + from_port        = 443
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 443
                # (1 unchanged attribute hidden)
            },
          + {
              + cidr_blocks      = []
              + from_port        = 443
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = true
              + to_port          = 443
                # (1 unchanged attribute hidden)
            },
        ]
      + name                   = "eks-dev-privatelink-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-privatelink-sg"
        }
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-privatelink-sg"
        }
      + vpc_id                 = (known after apply)
    }

  # module.vpc.aws_eip.nat-gateway-eip[0] will be created
  + resource "aws_eip" "nat-gateway-eip" {
      + allocation_id        = (known after apply)
      + arn                  = (known after apply)
      + association_id       = (known after apply)
      + carrier_ip           = (known after apply)
      + customer_owned_ip    = (known after apply)
      + domain               = "vpc"
      + id                   = (known after apply)
      + instance             = (known after apply)
      + ipam_pool_id         = (known after apply)
      + network_border_group = (known after apply)
      + network_interface    = (known after apply)
      + private_dns          = (known after apply)
      + private_ip           = (known after apply)
      + ptr_record           = (known after apply)
      + public_dns           = (known after apply)
      + public_ip            = (known after apply)
      + public_ipv4_pool     = (known after apply)
      + tags                 = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-nat-gateway-eip-1"
        }
      + tags_all             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-nat-gateway-eip-1"
        }
      + vpc                  = (known after apply)
    }

  # module.vpc.aws_internet_gateway.igw will be created
  + resource "aws_internet_gateway" "igw" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-igw"
        }
      + tags_all = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-igw"
        }
      + vpc_id   = (known after apply)
    }

  # module.vpc.aws_nat_gateway.simple-nat-gateway[0] will be created
  + resource "aws_nat_gateway" "simple-nat-gateway" {
      + allocation_id                      = (known after apply)
      + association_id                     = (known after apply)
      + connectivity_type                  = "public"
      + id                                 = (known after apply)
      + network_interface_id               = (known after apply)
      + private_ip                         = (known after apply)
      + public_ip                          = (known after apply)
      + secondary_private_ip_address_count = (known after apply)
      + secondary_private_ip_addresses     = (known after apply)
      + subnet_id                          = (known after apply)
      + tags                               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-nat-gateway-1"
        }
      + tags_all                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-nat-gateway-1"
        }
    }

  # module.vpc.aws_route_table.database_route_table will be created
  + resource "aws_route_table" "database_route_table" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = (known after apply)
      + tags             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-route-table"
        }
      + tags_all         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-route-table"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table.private_route_table[0] will be created
  + resource "aws_route_table" "private_route_table" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + cidr_block                 = "0.0.0.0/0"
              + nat_gateway_id             = (known after apply)
                # (11 unchanged attributes hidden)
            },
        ]
      + tags             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-route-table-1"
        }
      + tags_all         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-route-table-1"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table.public_route_table will be created
  + resource "aws_route_table" "public_route_table" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + cidr_block                 = "0.0.0.0/0"
              + gateway_id                 = (known after apply)
                # (11 unchanged attributes hidden)
            },
        ]
      + tags             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-route-table"
        }
      + tags_all         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-route-table"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table_association.database_route_table_association[0] will be created
  + resource "aws_route_table_association" "database_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.database_route_table_association[1] will be created
  + resource "aws_route_table_association" "database_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.database_route_table_association[2] will be created
  + resource "aws_route_table_association" "database_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private_route_table_association[0] will be created
  + resource "aws_route_table_association" "private_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private_route_table_association[1] will be created
  + resource "aws_route_table_association" "private_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private_route_table_association[2] will be created
  + resource "aws_route_table_association" "private_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public_route_table_association[0] will be created
  + resource "aws_route_table_association" "public_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public_route_table_association[1] will be created
  + resource "aws_route_table_association" "public_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public_route_table_association[2] will be created
  + resource "aws_route_table_association" "public_route_table_association" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_subnet.database[0] will be created
  + resource "aws_subnet" "database" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.21.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-subnet-1"
          + "Type"        = "Database Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-subnet-1"
          + "Type"        = "Database Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.database[1] will be created
  + resource "aws_subnet" "database" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.22.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-subnet-2"
          + "Type"        = "Database Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-subnet-2"
          + "Type"        = "Database Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.database[2] will be created
  + resource "aws_subnet" "database" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.23.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-subnet-3"
          + "Type"        = "Database Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-database-subnet-3"
          + "Type"        = "Database Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[0] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.11.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-subnet-1"
          + "Type"        = "Private Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-subnet-1"
          + "Type"        = "Private Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[1] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.12.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-subnet-2"
          + "Type"        = "Private Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-subnet-2"
          + "Type"        = "Private Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[2] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.13.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-subnet-3"
          + "Type"        = "Private Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-private-subnet-3"
          + "Type"        = "Private Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[0] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.1.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-subnet-1"
          + "Type"        = "Public Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-subnet-1"
          + "Type"        = "Public Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[1] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.2.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-subnet-2"
          + "Type"        = "Public Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-subnet-2"
          + "Type"        = "Public Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[2] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.3.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-subnet-3"
          + "Type"        = "Public Subnets"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-public-subnet-3"
          + "Type"        = "Public Subnets"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_vpc.basic-vpc will be created
  + resource "aws_vpc" "basic-vpc" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.0.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + tags                                 = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-vpc-dev"
        }
      + tags_all                             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "eks-dev-vpc-dev"
        }
    }

Plan: 48 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cluster_endpoint   = (known after apply)
  + cluster_name       = "eks-dev"
  + configure_kubectl  = "aws eks update-kubeconfig --region ap-south-1 --name eks-dev"
  + private_subnet_ids = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + public_subnet_ids  = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + vpc_id             = (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

```

### Enter a value = yes

```

module.eks.aws_iam_role.eks_cluster_role: Creating...
module.bastion.aws_iam_role.bastion_ssm_role: Creating...
module.eks.aws_iam_role.ebs_csi_driver_role: Creating...
module.eks.aws_iam_role.eks_node_group_role: Creating...
module.vpc.aws_vpc.basic-vpc: Creating...
module.eks.aws_iam_role.eks_node_group_role: Creation complete after 2s [id=eks-dev-node-role]
module.eks.aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy: Creating...
module.eks.aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy: Creating...
module.eks.aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore: Creating...
module.eks.aws_iam_role_policy_attachment.node_EC2ContainerRegistryReadOnly: Creating...
module.eks.aws_iam_role.eks_cluster_role: Creation complete after 2s [id=eks-dev-cluster-role]
module.eks.aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy: Creating...
module.eks.aws_iam_role_policy_attachment.eks_AmazonEKSVPCResourceController: Creating...
module.bastion.aws_iam_role.bastion_ssm_role: Creation complete after 2s [id=eks-dev-bastion-bastion-ssm-role]
module.bastion.aws_iam_role_policy_attachment.bastion_ssm_policy: Creating...
module.bastion.aws_iam_instance_profile.bastion_instance_profile: Creating...
module.eks.aws_iam_role.ebs_csi_driver_role: Creation complete after 2s [id=eks-dev-ebs-csi-role]
module.eks.aws_iam_role_policy_attachment.ebs_csi_AmazonEBSCSIDriverPolicy: Creating...
module.eks.aws_iam_role_policy_attachment.node_EC2ContainerRegistryReadOnly: Creation complete after 1s [id=eks-dev-node-role-20260307204051604000000001]
module.eks.aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy: Creation complete after 1s [id=eks-dev-node-role-20260307204051610500000003]
module.eks.aws_iam_role_policy_attachment.node_AmazonSSMManagedInstanceCore: Creation complete after 1s [id=eks-dev-node-role-20260307204051610000000002]
module.eks.aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy: Creation complete after 1s [id=eks-dev-node-role-20260307204051611000000004]
module.eks.aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy: Creation complete after 1s [id=eks-dev-cluster-role-20260307204051655400000005]
module.eks.aws_iam_role_policy_attachment.eks_AmazonEKSVPCResourceController: Creation complete after 1s [id=eks-dev-cluster-role-20260307204051675000000006]
module.bastion.aws_iam_role_policy_attachment.bastion_ssm_policy: Creation complete after 1s [id=eks-dev-bastion-bastion-ssm-role-20260307204051725800000007]
module.eks.aws_iam_role_policy_attachment.ebs_csi_AmazonEBSCSIDriverPolicy: Creation complete after 1s [id=eks-dev-ebs-csi-role-20260307204051781600000008]
module.bastion.aws_iam_instance_profile.bastion_instance_profile: Creation complete after 8s [id=eks-dev-bastion-bastion-instance-profile]
module.vpc.aws_vpc.basic-vpc: Still creating... [00m10s elapsed]
module.vpc.aws_vpc.basic-vpc: Creation complete after 12s [id=vpc-07a2cad5634327399]
module.vpc.aws_internet_gateway.igw: Creating...
module.vpc.aws_route_table.database_route_table: Creating...
module.vpc.aws_subnet.private[0]: Creating...
module.vpc.aws_subnet.public[0]: Creating...
module.vpc.aws_subnet.database[0]: Creating...
module.vpc.aws_subnet.public[1]: Creating...
module.vpc.aws_subnet.database[1]: Creating...
module.vpc.aws_subnet.database[2]: Creating...
module.vpc.aws_subnet.private[2]: Creating...
module.vpc.aws_subnet.public[2]: Creating...
module.vpc.aws_internet_gateway.igw: Creation complete after 1s [id=igw-06ed67a5ae7254079]
module.vpc.aws_subnet.private[1]: Creating...
module.vpc.aws_route_table.database_route_table: Creation complete after 1s [id=rtb-0c1e1720d4c285e11]
module.vpc.aws_route_table.public_route_table: Creating...
module.vpc.aws_subnet.private[1]: Creation complete after 0s [id=subnet-0b50b561421f27973]
module.vpc.aws_eip.nat-gateway-eip[0]: Creating...
module.vpc.aws_subnet.database[2]: Creation complete after 1s [id=subnet-0898c545b99106da0]
module.bastion.aws_security_group.bastion_sg: Creating...
module.vpc.aws_subnet.database[0]: Creation complete after 1s [id=subnet-058d392199b512813]
module.vpc.aws_subnet.private[0]: Creation complete after 1s [id=subnet-00a087a10eb835a5b]
module.vpc.aws_subnet.private[2]: Creation complete after 1s [id=subnet-01f28058c825500a2]
module.eks.aws_security_group.private_link_sg: Creating...
module.vpc.aws_subnet.database[1]: Creation complete after 1s [id=subnet-04f14d6ece52bda6f]
module.vpc.aws_route_table_association.database_route_table_association[0]: Creating...
module.vpc.aws_route_table_association.database_route_table_association[1]: Creating...
module.vpc.aws_route_table_association.database_route_table_association[2]: Creating...
module.vpc.aws_route_table_association.database_route_table_association[1]: Creation complete after 1s [id=rtbassoc-02e71a885a656bb28]
module.vpc.aws_route_table.public_route_table: Creation complete after 1s [id=rtb-097a781c9adf91d06]
module.vpc.aws_route_table_association.database_route_table_association[0]: Creation complete after 1s [id=rtbassoc-0b838986d944f3649]
module.vpc.aws_route_table_association.database_route_table_association[2]: Creation complete after 1s [id=rtbassoc-091a65572ce7d8016]
module.vpc.aws_eip.nat-gateway-eip[0]: Creation complete after 1s [id=eipalloc-0f28bad8a9bf42da5]
module.bastion.aws_security_group.bastion_sg: Creation complete after 2s [id=sg-0b78c987ca8ba5adb]
module.eks.aws_security_group.private_link_sg: Creation complete after 3s [id=sg-0fcd02776b7f1bc2f]
module.eks.aws_eks_cluster.basic_eks_cluster: Creating...
module.vpc.aws_subnet.public[0]: Still creating... [00m10s elapsed]
module.vpc.aws_subnet.public[2]: Still creating... [00m10s elapsed]
module.vpc.aws_subnet.public[1]: Still creating... [00m10s elapsed]
module.vpc.aws_subnet.public[2]: Creation complete after 11s [id=subnet-00162c953115db371]
module.vpc.aws_subnet.public[1]: Creation complete after 12s [id=subnet-0d7fbde1e8ccc7ed4]
module.vpc.aws_subnet.public[0]: Creation complete after 12s [id=subnet-0f17a6542318da17b]
module.vpc.aws_route_table_association.public_route_table_association[1]: Creating...
module.vpc.aws_route_table_association.public_route_table_association[0]: Creating...
module.vpc.aws_route_table_association.public_route_table_association[2]: Creating...
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Creating...
module.bastion.aws_instance.bastion: Creating...
module.vpc.aws_route_table_association.public_route_table_association[1]: Creation complete after 0s [id=rtbassoc-045c2d8b5f5bf736a]
module.vpc.aws_route_table_association.public_route_table_association[0]: Creation complete after 0s [id=rtbassoc-028f848815422368d]
module.vpc.aws_route_table_association.public_route_table_association[2]: Creation complete after 0s [id=rtbassoc-0216b4e50b071f7ff]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [00m10s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [00m10s elapsed]
module.bastion.aws_instance.bastion: Still creating... [00m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [00m20s elapsed]
module.bastion.aws_instance.bastion: Creation complete after 12s [id=i-0bb9c8b3ab0538d36]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [00m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [00m30s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [00m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [00m40s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [00m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [00m50s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [00m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [01m00s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [01m00s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [01m10s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [01m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [01m20s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [01m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [01m30s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [01m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [01m40s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [01m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [01m50s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Still creating... [01m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [02m00s elapsed]
module.vpc.aws_nat_gateway.simple-nat-gateway[0]: Creation complete after 1m54s [id=nat-080c419052e850f11]
module.vpc.aws_route_table.private_route_table[0]: Creating...
module.vpc.aws_route_table.private_route_table[0]: Creation complete after 1s [id=rtb-0b40867e7abda1860]
module.vpc.aws_route_table_association.private_route_table_association[2]: Creating...
module.vpc.aws_route_table_association.private_route_table_association[1]: Creating...
module.vpc.aws_route_table_association.private_route_table_association[0]: Creating...
module.vpc.aws_route_table_association.private_route_table_association[2]: Creation complete after 0s [id=rtbassoc-00706ff72b6439df4]
module.vpc.aws_route_table_association.private_route_table_association[0]: Creation complete after 0s [id=rtbassoc-0dc99db06412bd51c]
module.vpc.aws_route_table_association.private_route_table_association[1]: Creation complete after 0s [id=rtbassoc-0beb8dc49eb018d8e]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [02m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [02m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [02m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [02m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [02m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [03m00s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [03m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [03m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [03m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [03m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [03m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [04m00s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [04m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [04m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [04m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [04m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [04m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [05m00s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [05m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [05m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [05m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [05m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [05m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [06m00s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [06m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [06m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [06m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [06m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [06m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [07m00s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [07m10s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [07m20s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [07m30s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [07m40s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [07m50s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Still creating... [08m00s elapsed]
module.eks.aws_eks_cluster.basic_eks_cluster: Creation complete after 8m2s [id=eks-dev]
module.eks.aws_eks_addon.vpc_cni: Creating...
module.eks.aws_eks_addon.kube_proxy: Creating...
module.eks.aws_eks_node_group.private_node_group: Creating...
module.eks.aws_eks_addon.vpc_cni: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.kube_proxy: Still creating... [00m10s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.vpc_cni: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.kube_proxy: Still creating... [00m20s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.vpc_cni: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.kube_proxy: Still creating... [00m30s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.vpc_cni: Still creating... [00m40s elapsed]
module.eks.aws_eks_addon.kube_proxy: Still creating... [00m40s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [00m40s elapsed]
module.eks.aws_eks_addon.kube_proxy: Creation complete after 45s [id=eks-dev:kube-proxy]
module.eks.aws_eks_addon.vpc_cni: Creation complete after 45s [id=eks-dev:vpc-cni]
module.eks.aws_eks_node_group.private_node_group: Still creating... [00m50s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [01m00s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [01m10s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [01m20s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [01m30s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [01m40s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [01m50s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [02m00s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [02m10s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [02m20s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [02m30s elapsed]
module.eks.aws_eks_node_group.private_node_group: Still creating... [02m40s elapsed]
module.eks.aws_eks_node_group.private_node_group: Creation complete after 2m50s [id=eks-dev:eks-dev-system-ng]
module.eks.aws_eks_addon.core_dns: Creating...
module.eks.aws_eks_addon.metric_server: Creating...
module.eks.aws_eks_addon.ebs_csi_driver: Creating...
module.eks.aws_eks_addon.core_dns: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.metric_server: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.ebs_csi_driver: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.core_dns: Creation complete after 14s [id=eks-dev:coredns]
module.eks.aws_eks_addon.ebs_csi_driver: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.metric_server: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.ebs_csi_driver: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.metric_server: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.ebs_csi_driver: Still creating... [00m40s elapsed]
module.eks.aws_eks_addon.metric_server: Still creating... [00m40s elapsed]
module.eks.aws_eks_addon.metric_server: Creation complete after 45s [id=eks-dev:metrics-server]
module.eks.aws_eks_addon.ebs_csi_driver: Creation complete after 45s [id=eks-dev:aws-ebs-csi-driver]

Apply complete! Resources: 48 added, 0 changed, 0 destroyed.
```

## Output

```
cluster_endpoint = "https://FC81A3F53BD6B736AB9568ED2EEC46A6.gr7.ap-south-1.eks.amazonaws.com"
cluster_name = "eks-dev"
configure_kubectl = "aws eks update-kubeconfig --region ap-south-1 --name eks-dev"
private_subnet_ids = [
  "subnet-00a087a10eb835a5b",
  "subnet-0b50b561421f27973",
  "subnet-01f28058c825500a2",
]
public_subnet_ids = [
  "subnet-0f17a6542318da17b",
  "subnet-0d7fbde1e8ccc7ed4",
  "subnet-00162c953115db371",
]
vpc_id = "vpc-07a2cad5634327399"
```