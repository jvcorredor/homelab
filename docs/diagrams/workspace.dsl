// Rockingham Homelab — C4 model, rendered to SVG at docs-site build time.
//
// This file is the single source of truth for the architecture diagrams.
// Addresses and versions appear in diagram descriptions for readability;
// the files that own those values are talos/patches/nodes/ and
// terraform/bootstrap/variables.tf — update this file when they change.
//
// Views: L1 (system context), L2 (containers), Deployment, Bootstrap,
// LBTraffic, CICD. View keys determine the exported file names, which
// scripts/build-diagrams.sh maps onto stable asset names.

workspace "Rockingham Homelab" "The lab's Kubernetes cluster and its dependencies, modelled in C4." {

    model {

        operator = person "Operator" "Jack — owns the lab, operates every layer, and approves the CI deploy gate."

        rockingham = softwareSystem "Kubernetes cluster (rockingham)" "Six-node bare-metal Kubernetes cluster running Talos Linux. The floor: Talos, Cilium, Gateway API CRDs, local-path-provisioner, metrics-server (ADR-0009)." {

            talos = container "Talos Linux + Kubernetes" "Immutable node OS on all six nodes; runs the Kubernetes control plane, kubelet, and KubePrism." "Platform"
            cilium = container "Cilium" "The only data-plane component: CNI, kube-proxy replacement, LB IPAM + L2 announcements, Gateway API controller, Hubble. One Helm release (ADR-0002)." "Networking"
            gatewayapi = container "Gateway API CRDs" "Cluster-scoped CRDs applied before Cilium starts; provide HTTPRoute and Gateway resources." "Networking"
            localpath = container "local-path-provisioner" "Default and only StorageClass. Binds a PVC to a directory on the node where the consuming pod first lands." "Storage"
            metrics = container "metrics-server" "Resource metrics API behind kubectl top." "Platform"
            workloads = container "Workloads" "Everything above the floor. Applied by hand; none managed today (ADR-0009)." "Workload"

            cilium -> gatewayapi "Requires at startup (ordering enforced by tofu depends_on)"
            cilium -> talos "Runs as a DaemonSet on every node"
            workloads -> localpath "Claims volumes from the default StorageClass"
            workloads -> cilium "Services, policies, and ingress through the datapath"
        }

        github = softwareSystem "GitHub" "Repository, Actions runners, and GitHub Pages. CI plans and applies the GCP root; the docs site deploys from here." "External"
        gcp = softwareSystem "GCP project rockingham-homelab" "Project skeleton: tfstate bucket, the talos-cluster-secrets GSM container, and the CI plan/apply identities behind GitHub OIDC WIF (ADR-0004)." "External"
        gateway = softwareSystem "Optimum Gateway 6E" "Home router. Hands out DHCP for 192.168.1.11-199 and switches the LAN where the static cluster range and LB pool live." "External"
        internet = softwareSystem "Public registries" "Container image registries and Helm chart sources the cluster pulls from." "External"

        operator -> rockingham "Operates with talosctl, kubectl, helm, and tofu"
        operator -> github "Pushes, reviews, and approves deployments"
        operator -> gcp "Uploads talos-cluster-secrets versions with gcloud (manual)"
        github -> gcp "Plans and applies terraform/gcp over OIDC Workload Identity Federation"
        github -> operator "Reports CI results"
        rockingham -> gateway "Default route; ARP for LB pool addresses"
        rockingham -> internet "Pulls images and charts"
        gateway -> internet "WAN uplink"

        operator -> talos "Applies machine config with talosctl"
        operator -> gatewayapi "Applies platform manifests with tofu"
        operator -> cilium "Applies platform manifests with tofu"
        operator -> localpath "Applies platform manifests with tofu"
        operator -> metrics "Applies platform manifests with tofu"
        cilium -> gateway "Announces LB pool addresses on the LAN"
        gateway -> cilium "Forwards LB traffic to the announcing worker"
        cilium -> workloads "Delivers service traffic through the datapath"

        lan = deploymentEnvironment "Home LAN" {
            deploymentNode "Optimum Gateway 6E" "Default gateway, DHCP 192.168.1.11-199" {
                softwareSystemInstance gateway
            }
            deploymentNode "Operator workstation" "Repo checkout, talosctl, kubectl, tofu"

            deploymentNode "cp-01" "Control plane" "192.168.1.245" {
                containerInstance talos
                containerInstance cilium
            }
            deploymentNode "cp-02" "Control plane" "192.168.1.246" {
                containerInstance talos
                containerInstance cilium
            }
            deploymentNode "cp-03" "Control plane" "192.168.1.247" {
                containerInstance talos
                containerInstance cilium
            }
            deploymentNode "worker-01" "Worker" "192.168.1.241" {
                containerInstance talos
                containerInstance cilium
            }
            deploymentNode "worker-02" "Worker" "192.168.1.242" {
                containerInstance talos
                containerInstance cilium
            }
            deploymentNode "worker-03" "Worker" "192.168.1.243" {
                containerInstance talos
                containerInstance cilium
            }
        }
    }

    views {

        systemContext rockingham "L1" "System context — the lab and everything it touches" {
            include *
            include github gcp
            autolayout lr
        }

        container rockingham "L2" "Containers — the floor inside the cluster" {
            include *
            exclude operator
            autolayout lr
        }

        deployment rockingham lan "Deployment" "Deployment — the six nodes on the home LAN" {
            include *
            exclude "* -> *"
            autolayout tb
        }

        dynamic rockingham "Bootstrap" "Bring-up — from blank nodes to the floor" {
            properties {
                "plantuml.sequenceDiagram" "true"
            }

            operator -> talos "talosctl apply-config --insecure from maintenance mode, node by node"
            operator -> talos "talosctl bootstrap on cp-01 (once) forms etcd"
            operator -> talos "talosctl kubeconfig fetches the kubeconfig"
            operator -> gatewayapi "tofu apply — Gateway API CRDs must exist first"
            operator -> cilium "tofu apply — Cilium Helm release brings networking up"
            operator -> localpath "tofu apply — local-path-provisioner and the default StorageClass"
            operator -> metrics "tofu apply — metrics-server"
            operator -> cilium "just smoke runs the cilium connectivity test"
        }

        dynamic rockingham "LBTraffic" "A LoadBalancer Service — how the LB pool answers on the LAN" {
            properties {
                "plantuml.sequenceDiagram" "true"
            }

            operator -> cilium "kubectl apply a Service of type LoadBalancer"
            cilium -> gateway "Assigns the next free address from the pool and announces it via ARP from a worker"
            gateway -> cilium "Forwards that address's traffic to the announcing worker"
            cilium -> workloads "Delivers to a backend pod through the datapath"
        }

        dynamic rockingham "CICD" "CI apply path — how a terraform/gcp change reaches GCP" {
            properties {
                "plantuml.sequenceDiagram" "true"
            }

            operator -> github "Opens a PR touching terraform/gcp/"
            github -> gcp "tofu plan as tf-ci-plan (viewer-only, WIF scoped to the repository)"
            github -> operator "Posts the plan as a sticky PR comment"
            operator -> github "Reviews and merges to main"
            github -> gcp "Apply job starts and is held by the gcp environment"
            operator -> github "Approves the deployment in the gcp environment"
            github -> gcp "tofu apply as tf-ci-apply (roles/owner, WIF scoped to the environment)"
        }
    }
}
