---
title: "Hosting Mastodon identities at your own domain"
date: "2022-11-16"
authors: 
- Max Jonas Werner
cover:
  image: "/images/fork.jpg"
  alt: "a fork in a road with mountains in the back"
  caption: "(Photo by [Ashim D’Silva](https://unsplash.com/@randomlies?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/fork-path?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText))"
---

[Discuss this post](https://hachyderm.io/@makkes/109353563088733849)

**EDIT January 11, 2022:** In previous versions of this article I advertised the `try_files` directive which made the solution vulnerable to path traversal attacks. Using the `return` directive and sending a 301 redirect fixed this. Thanks to [Penple](https://penple.dev/) for making me aware of this vulnerability.

With Mastodon being all the rage right now and people massively moving over, new opportunities arise. One of these is that Mastodon allows you to take ownership of your identity using the [WebFinger protocol](https://docs.joinmastodon.org/spec/webfinger/). This way you can have an identitiy like `me@example.org` without actually having to host your own Mastodon server (or instance in Mastodon lingo).

Maarten Balliauw has already posted on [how to achieve this](https://blog.maartenballiauw.be/post/2022/11/05/mastodon-own-donain-without-hosting-server.html) but with a little caveat:

_"this approach works much like a catch-all e-mail address. @anything@yourdomain.com will match, unless you add a bit more scripting to only show a result for resources you want to be discoverable."_

I went ahead and solved this by tweaking the nginx configuration of one of my servers slightly (caveat here is you need access to the web server's configuration):

```
server {
    listen 80;

    location = /.well-known/webfinger {
        absolute_redirect off;
        return 301 $uri/$arg_resource;
    }
```

A WebFinger requests URL looks similar to this: `https://home.e13.dev/.well-known/webfinger?resource=acct:makkes@home.e13.dev`. Now whenever a request comes in at that URL nginx sends an HTTP 301 redirect pointing to `/.well-known/webfinger/acct:makkes@home.e13.dev` which in turn returns the contents of the requested file (if it exists). So the only thing to do is to create that file with the WebFinger details in it and store it at that location in nginx's web root.

This mitigates the "catch-all" limitation and only serves the identity or identities you want it to.
