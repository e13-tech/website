---
title: "Kubernetes Authentication - What Actually Is a User?"
date: "2023-09-01"
people: 
- Max Jonas Werner
draft: true
---

https://github.com/luxas/kube-rebac-authorizer?tab=readme-ov-file#kubernetes-authorization

How do k8s users work? Do they exist? Why don’t they exist? How do they tie into OIDC?

## Kubernetes Authentication Overview


{{<figure src="/images/access-control-overview.png" alt="Diagram of request handling steps for Kubernetes API request" caption="API requests go through multiple stages before being fulfilled. ([diagram](https://github.com/kubernetes/website/blob/fdcc226033d510a53074c0ee6ef2b048e4b11973/static/images/docs/admin/access-control-overview.svg) by The Kubernetes Authors, licensed under [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/))">}}

- API server as central authenticator; everything goes through it.

## What Is a User? What is a Group?

> Kubernetes does not have objects which represent normal user accounts. Normal users cannot be added to a cluster through an API call.

1. Human users
2. Service accounts

### Service Accounts

- What is the benefit of SAs?
- How is an SA created?
- How are SA credentials managed (creation, expiry, renewal/rotation)?
- How do I make use of an SA?

## Internal Authentication

- How do Kubernetes components authenticate to the API server?

## What Methods of Authentication Does Kubernetes Support?

### Client certificate: User name from "Common Name" (CN) of the subject

- How to manage the CA?
- How to issue certificates? (https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#normal-user)

### Token

## How Does Kubernetes Grant Privileges to Users?

## How Does OIDC Work With Kubernetes?

## What Is Impersonation?

## Practical Example: `kubectl` with OIDC

```yaml
users:
- name: oidc
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://keycloak.example.org/realms/k8s
      - --oidc-client-id=k8s-apiserver
      command: kubectl
```

[authref]: https://kubernetes.io/docs/reference/access-authn-authz/authentication/
[ctrlacc]: https://kubernetes.io/docs/concepts/security/controlling-access/
