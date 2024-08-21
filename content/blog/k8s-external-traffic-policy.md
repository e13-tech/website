---
title: "\"My Pod doesn't see the clients' IP addresses\": Kubernetes External Traffic Policy Caveats"
date: "2024-08-21"
authors: 
- Max Jonas Werner
cover:
  image: "/images/denys-nevozhai-7nrsVjvALnA-unsplash.jpg"
  alt: "An aerial photo of a large interchange"
  caption: "Photo by [Denys Nevozhai](https://unsplash.com/@dnevozhai) on [Unsplash](https://unsplash.com/photos/aerial-photography-of-concrete-roads-7nrsVjvALnA?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash)"
---

Yesterday I had an interesting conversation with a friend who asked me how he could configure his Kubernetes deployment so that the application running in his Pods is able to see the IP addresses of the clients that issue TCP requests. Since his application was running behind a LoadBalancer service, I pointed him to the [official Kubernetes docs](https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-loadbalancer) on the topic that basically advise to set the Service's `.spec.externalTrafficPolicy` to `Local`. This will lead to requests being served from the node they arrived at and consequently preserves the clients' IP addresses. I didn't forget to mention that this may lead to an imbalance in how traffic is routed to his Pods (as the documentation also mentions [on another page](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#caveats-and-limitations-when-preserving-source-ips)). When he asked why that was the case I had to think for a second and ended up illustrating it to him with an example:

Imagine your cluster has 3 nodes and your application is deployed with 6 replicas, i.e. 6 Pods. The Pods are spread across the nodes in the following way:

- 1 Pod on Node 1
- 2 Pods on Node 2
- 3 Pods on Node 3

In the usual case you want incoming traffic to be distributed equally among the Pods, 1/6th of all requests to each node. Now with an external load balancer fronting your Kubernetes Service of type LoadBalancer, that external load balancer usually knows nothing about Pods but only about nodes (that's true e.g. for an AKS Load Balancer and presumably for GKE, EKS and on-premise LBs, too). Your external load balancer will consequently balance traffic equally across your Kubernetes nodes, 1/3rd of all requests to each node. From there, a component called kube-proxy takes over and distributes the traffic to the matching Pods of the Service.

With the default external traffic policy of `Cluster`, kube-proxy will take into account all Pods of the whole cluster and distribute traffic equally among them, no matter where they run. This is illustrated in the following diagram:

{{<figure src="/images/external-traffic-policy-cluster.svg" alt="A schematic diagram illustrating how traffic flows with cluster external traffic policy">}}

1/6th of all requests goes to each Pod. Good, that's what we want. But now that we want to reveal the clients' IP addresses to the application running inside of the Pods, we change the traffic policy to `Local` as explained in the documentation. This will lead to a significant change of how traffic flows within your cluster. With all traffic from the external load balancer still being balanced equally among all nodes (because what does LB know about Kubernetes traffic policies, anyway?), kube-proxy will no longer forward it to Pods outside of the node that it's running on, leading to the following traffic flow:

{{<figure src="/images/external-traffic-policy-local.svg" alt="A schematic diagram illustrating how traffic flows with local external traffic policy">}}

As you can see, now Pod 1 has to handle 1/3rd of all traffic, Pods 2 and 3 still handle 1/6th each and Pods 4, 5 and 6 only handle 1/9th. So Pod 1 has to handle 3 times as much traffic as Pods 4, 5 and 6. This is a huge imbalance and may lead to your application behaving very differently depending on which node handles a request.

# What You Can Do About It

There's multiple things you can do to preserve client IP addresses while still balancing traffic equally:

- Use a [Pod Topology Spread Constraint](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/) to run more or less the same amount of Pods on each node. This, of course, only makes sense if all the nodes have more or less the same resources in terms of CPU cores, RAM and network connectivity (depending on which one's important to your application).
- Use an ingress controller: Usually, ingress controllers allow for a much more fine-grained load-balancing behaviour, e.g. ingress-nginx can be configured to use a different load-balancing algorithm [per Ingress resource](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#custom-nginx-load-balancing).
- Depending on your Kubernetes cluster provider you may be able to use the Gateway API which [provides limited ways to influence the weighting of backends](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io%2fv1.BackendRef).
