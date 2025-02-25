---
draft: true
title: "Managing Thousands of Clusters and Their Workloads with Flux"
date: "tbd"
people: 
- Max Jonas Werner
cover:
  image: "tbd"
---

Kubernetes is evolving as the de facto standard in enterprise IT settings, but slowly. Many bigger companies are still in the process of ramping up their Kubernetes deployments, mainly exploring single-cluster experiences. There, the day 2 operations are already very mature. Some of those big organisations are ahead of the market by dipping their toes into the waters of multi-cluster Kubernetes. When you are deeply involved in Kubernetes you might think this is already the norm but from what I've been learning over the past years serving enterprise customers at D2iQ, the majority of them is still in the very early stages of multi-cluster Kubernetes deployments, even more so when it comes to day 2 operations that follow the stage of exploration (day 0), then setup (day 1). At day 2, your job as an ops person is to make sure the clusters run stable, perform well, are well maintained and monitored and easy to consume by your downstream users, the developers running their workloads on them.

As soon as you start on your journey on managing more than one cluster for an organisation, you want to make sure to do it right from the beginning:

* Treat your clusters as cattle, making creation of new clusters as easy as creating a Deployment on an existing one.
* Deploy a fixed set of management components onto them for central monitoring and alerting, logging, cost and access management.
* Provide a centrally managed application catalog for downstream consumers to pick from.
* Make it easy for consumers to deploy their own workloads onto their clusters in addition to any centrally managed components.

## GitOps Provides No Blueprint

GitOps is quickly becoming the deployment model of choice for such environments as it provides several benefits, among those central storage of application and configuration data, providing easy rollbacks, automated pull reconciliation and auditability. Translating these requirements to an implementation that leverages the GitOps model of deployment bears several challenges to be solved:

* You can't exclusively rely on Kubernetes RBAC any longer, but need to extend your authentication and authorization models to Git. To many companies this isn't even a real challenge as they're using Git for application development already and have all the building blocks in place to e.g. define and assign teams to repositories.
* You need to employ multiple repositories for the different target groups (cluster managers, cluster consumers etc.) because there's no way to provide fine-grained access control to a single repository.
* Each application may need to be configured differently depending on which cluster it is deployed to (per-cluster configuration).
* You need to isolate tenants from each other on each individual cluster.

One principle of a GitOps approach to cluster management should be that you don't need to give users direct access to the Kubernetes API, anymore, at least not for writing (create, update, delete).

Unfortunately, multi-cluster management is still kind of a fresh topic and each project and each vendor do it differently. No common best practices have been established, yet. The [OpenGitOps CNCF](https://opengitops.dev/) project set out to serve as the home for such best practices and I hope that the industry can converge on common principles and best practices soon. This article hopefully adds to the discussion and provides some common, vendor-neutral principles for multi-cluster management.

## A Multi-Cluster Management Template

Putting the principles outlined above to practice requires defining the workflows and associated personas first. 

### Workflows

The following workflows are derived from common practices in the industry.

#### Deploying a Management Cluster

One Kubernetes cluster serves as a management cluster for a single pane of glass into all managed clusters and workloads. This cluster is running components that, among other duties, roll up metrics from all managed clusters and provide a user interface into for easy inspection of all clusters. This cluster is typically installed and operated by a dedicated team.

#### Adopting a Cluster

Letting the management cluster take over management of another cluster's lifecycle and workloads is what I call "adoption". The details of adoption depend on the service model: For self-service, the management cluster could run a Web user interface allowing users to put in the details of the cluster to be adopted. In a more centrally managed scenario, an operator with elevated privileges would be provided with those details and put them into a central Git repository consumed by the management cluster. Adoption would lead to common workloads being deployed to the managed cluster to support centralized use cases such as cost management and monitoring.

#### Deploying Workloads to Groups of Clusters (Workspaces)

In many scenarios clusters need to be grouped so that a centrally managed group of applications is deployed onto each cluster of a group. An example of a group might be a department that employs a staged approach to application lifecycle management and uses clusters for development, staging and production, respectively. To provide those three clusters with the same set of applications and configuration, they would be put into the same group. In this article these groups are called "Workspaces". The assignment of a cluster to a certain group is done upon adoption of the cluster.

#### Configuring a Workload per Cluster

In some scenarios, a cluster-specific configuration is necessary for workloads deployed from a group. One example application with this requirement is MetalLB where the address range must be adapted to each cluster's network configuration.

#### Deploying Custom Workloads Onto a Cluster

Each development team deploying applications onto clusters needs to be provided with the means to do this on a per-cluster basis in addition to the grouping outlined above, e.g. an application shall be installed on a dev cluster on each push to the application's repository but only go into production after all end-to-end tests ran successfully. Development teams need to have the ability to deploy any workloads to any of their clusters in a self-service manner.

### Personas

From the workflows outlined above, the following personas are identified.

#### Management Cluster Administrator

This persona is responsible for installing and operating the management cluster. They have administrative access to that cluster and its Git repositories. In the absence of a self-service user interface for adopting a cluster, they are the ones actually adopting a cluster by creating the necessary resources on the management cluster (by means of pushing them to the central management Git repository). Management cluster administrators typically have cluster-level privileges on each managed cluster in that they need to be able to deploy services to different workspaces and e.g. create CRDs.

#### Workspace Administrator

Workspace administrators manage the workloads deployed onto clusters in a certain workspace. Each workspace is managed by a discrete Git repository holding all manifests deployed onto clusters of the workspace. Applications of a workspace are constrained to a single, dedicated Namespace so that workspace administrators don't have cluster-wide access to managed clusters.

#### Managed Cluster Administrator

Managed cluster administrators deploy applications onto an individual cluster (by pushing to a cluster-specific Git repository). The have cluster-level access so that they are able to create CRDs or other cluster-scoped resources. In a hard multi-tenancy environment this persona would apply to the individual team assigned to the respective cluster.

## Implementing it with Flux

Up until now all of the concepts were independent of a particular GitOps implementation. For the sake of demonstrating how it would work, I created [a repository](https://github.com/makkes/flux-mc-control-plane/) that is supposed to serve as a template for implementing what I described above. It is mostly comprised of manifests in different directories and branches plus some scripts for facilitating the task of creating a management cluster (with kind), creating a cluster for attachment (also with kind) and attaching/detaching a particular cluster. The underlying GitOps implementation is [Flux](https://fluxcd.io) which provides a set of components for source reconciliation, Kubernetes object management (using kustomize), Helm release management, image update automation and more.
