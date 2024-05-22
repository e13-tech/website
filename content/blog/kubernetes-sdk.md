---
title: "Kubernetes is your Operations Development Kit"
date: "2024-05-10"
authors: 
- Max Jonas Werner
cover:
  image: "/images/simon-kadula-8gr6bObQLOI-unsplash.jpg"
  alt: "A pair of two electrical outlets"
  caption: "Photo by [Simon Kadula](https://unsplash.com/@simonkadula?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash) on [Unsplash](https://unsplash.com/photos/a-factory-filled-with-lots-of-orange-machines-8gr6bObQLOI?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash)"
---

Ever since I first dipped my toes into the Kubernetes waters, there were people arguing against Kubernetes along the lines of "you can run your stuff on a single EC2 instance much cheaper and simpler". Here I want to lay out why I believe this is a short-sighted and incomprehensive perspective. Hear me out! 😉

Most people think of Kubernetes as a mere container orchestrator, a component so deep down in your application's operational stack that developers don't have to think about it as the target platform for the applications they build. Just build a container from your code and run it. And yes, that's what Kubernetes does: it runs your containers. If Deployment/Pod is where you stop using Kubernetes' machinery, then you are likely better off running your containers on an EC2 instance indeed. But I highly doubt this is where anyone stops even in a development or integration environment. I will give you a real-world example of a customer engagement where we were asked to create an offer for deploying and running a certain business application. The ask by the customer was explictly to have the application running on virtual machines.

The application the customer needed to operate was a critical part of a multi-tenant messaging bus so it had to be highly available and be properly monitored for outages. The application itself needs access to a database and an AMQP broker. This is what we came up with:

- 2 VMs for each instance of the application itself for high availability/failover scenarios
- 2 VMs for the database (primary + replica)
- 2 VMs for the AMQP broker (deployed as cluster for high availability)
- 1 VM for monitoring
- 1 VM for logging

## Step 1 - The Path Towards Containers

That's 8 VMs for running and monitoring a single business application. What's the potential to drive down the cost for this setup? Sure, start with consolidating applications onto one VM. For our architecture proposal, we decided to put the monitoring and logging components onto the same VM. We then put the DB and the AMQP broker on the same VM, too. What's the consequence of this consolidation? 37,5% percent cost reduction (minus 3 VMs). Good. But honestly, we separated the VMs by application domain on purpose to begin with. One of the reasons is better isolation for security purposes, e.g. for the case where one of the instances gets compromised. You simply reduce the potential to move laterally across the infrastructure.

How do I properly isolate the applications to keep fulfilling this security goal when they're sharing the same VM? I insert an isolation layer. How do I do this in Linux? **Using containers**! That's step 1.

## Step 2 - Kubernetes to the Rescue

Now I have several VMs running that in turn run several containers each. Great! But I still need to properly manage network traffic flowing between each instance of my landscape. With containers I would use the runtime's networking features to do this, probably create several container networks and allow traffic to flow from certain parts of the landscape towards other parts (e.g. let the each business application instance open a TCP port to the database). I'll probably have to do some host-side iptables/nftables tweaking, too.

Next challenge: Deploying all these containers. Since I need to run multiple containers across several VMs, a solution such as Docker Compose isn't feasible, anymore. I will have to start scripting my own deployment machinery. But even now that I have all the containers running, I still need to deploy additional services such as a load balancer/reverse proxy to balance traffic between the two business application instances. I need to build a way to automatically fail over as soon as one of the VMs goes down. I need to manage access to the VMs for different roles, i.e. create user accounts, deploy SSH keys etc. etc.

But there's more: Maybe the application needs access to some sort of secret store, e.g. Hashicorp Vault or cloud-native solutions such as AWS/GCP KMS or Azure Key Vault. That's another thing I need to manually set up or better build some kind of custom automation for.

At this point I assume you see where this is leading: Running an application in production rarely means spinning up a single VM and putting a JAR file onto it. There's a lot of auxiliary components at play. And this is where we will now take a step back and see what the operational challenges are that we need to solve in this specific scenario:

- Orchestrate multiple containers across multiple machines (deploy, auto-restart, update, undeploy)
- Manage network traffic flowing between containers and between machines
- Balance traffic between instances and reverse-proxy services and manage failover scenarios
- Manage machine access for different roles and users
- Manage secret access from container instances

Experienced, senior ops people will have built or bought the proper tooling to do all of this for them over the many years they've been working in the space. They will have every tool and every process at hand to solve all of the problems stated above. These are not new problems, after all.

But what if there was a software out there that solved all of these challenges in a declarative, standardized way so that every ops person in the world could easily understand any environment operated by that software to a certain degree? A software that provides a common API with standardized syntax and semantics? An operational development kit if you will, flexible enough to adapt to the myriad of different operational environments out there.

Well, **this operational development kit is Kubernetes**! See for yourself:

| Challenge | Kubernetes API |
| --------- | -------------- |
| Orchestrate containers | [Deployments/StatefulSets/DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/) |
| Manage network traffic | [NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) |
| Balance traffic/reverse-proxy/failover | [Service/LoadBalancer/Ingress](https://kubernetes.io/docs/concepts/services-networking/) |
| Manage machine access | [RBAC (Role, ClusterRole, RoleBinding and ClusterRoleBinding)](https://kubernetes.io/docs/concepts/security/controlling-access/) |
| Manage secret access | RBAC + [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) + [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) |

Kubernetes provides all the building blocks for the operational challenges you're facing, anyway, out of the box. The overhead it brings in terms of operational complexitiy (it's not an easy task to keep a Kubernetes cluster up and running in production) is easily compensated by the simplicity of managing workloads running on it. So easy, in fact, that many development teams within companies can be handed a `kubeconfig` file and manage their applications themselves. I know because I've been on such a team in the past.

Kubernetes shifts work I'd be doing myself in a classical VM-based environment to software operators running in the cluster so that I can focus on more important work. It makes my application landscape transparent and reproducible if I add GitOps to the mix and store all the infrastructure in a repository. That's the real power of Kubernetes and why I like it so much.
