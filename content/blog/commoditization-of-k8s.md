---
title: "The commoditization of Kubernetes"
date: "2023-06-23"
authors: 
- Max Jonas Werner
cover:
  image: "/images/outlet.jpg"
  alt: "A pair of two electrical outlets"
  caption: "Photo by [Sven Brandsma](https://unsplash.com/@seffen99?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/photos/GC1syEKyWDI?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)"
---

 There's so many rants out there about Kubernetes and container environments in general and the [most recent statements](https://github.com/readme/podcast/kelsey-hightower) by Kelsey Hightower just fueled these so I want to share why I believe Kubernetes and the cloud-native way to run apps these days is a good thing.

Back in the days when I wanted to run a server application and expose it to the Internet I rented a root server (or used one I already had), copied all the artifacts onto it using scp and started the app/web server in the background, using screen or maybe a systemd service. For an upgrade of the app I stopped and restarted the app server after updating the artifacts. Simpe workflow.

Nowadays my usual workflow is to make a container image out of the app and run it in Kubernetes. For a completely new environment I spin up a Kubernetes server, install an ingress controller, use GitOps (i.e. install Flux), encrypt Secrets with SOPS or connect to a Vault (installing external-secrets operator), install Prometheus and Grafana, setup Slack notifications for Grafana alerts and a couple of other things.

What does this change in workflows and technology tell us, I wonder? Are we all adding unnecessary overhead to our production environments? Is Kubernetes complete overkill? I don't think so and here's why:

In my opinion the new workflow represents two things: First, the mindset of what it takes to run an application reliably and securely has changed. People are much more aware of what it means to run an application in production. Users don't accept considerable downtimes; adversaries have become much more efficient and effective. Occasionally spinning up your regular Tomcat and exposing it to the Internet doesn't work, anymore. Second, the technology needed to spin up a production environment that deserves the name has become a commodity. Kubernetes plays a huge part in this commoditization. It doesn't take days or weeks to get a decent environment up and running, it takes minutes to a couple of hours now.

Part of that commoditization are the very well-defined APIs that Kubernetes ships with and that allow it to be extended through e.g. CRDs. Containers of course have also shifted deployment processes left and generally simplified things a lot.

So does Kubernetes add overhead? Of course it does. Is it unnecessary? No way! The commoditization of production deployments is a good thing. Now, software engineers with little background in system operations now have all the tools at hand to run their apps reliably and securely. There is a learning curve but it's nowhere near as steep as it was back in the days.

Kelsey is right. Kubernetes will likely go away in the future but not in the sense that some people seem to understand it: It will become even more commoditized, to the degree that most people don't have to think about it. The new mindset will stick, though, and that's good, for users and operators alike.
