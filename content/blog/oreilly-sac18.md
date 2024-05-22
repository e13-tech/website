---
title: "O'Reilly Software Architecture Conference: My ping from London"
description: "I attented the conference this October in London and I'm sharing my two cents here."
date: "2018-11-04"
categories: [personal]
authors: 
- Max Jonas Werner
cover:
  image: "/images/british-museum.jpg"
---

I attended O'Reilly's [Software Architecture Conference in
London](https://conferences.oreilly.com/software-architecture/sa-eu) this
October and I thought I'd share my personal wrap-up of the most striking talks
I've heard there. So buckle up for a tiny race through three days of talks and
workshops:

[sarahjwells](https://twitter.com/sarahjwells) from Financial Times gave a
great advice on how to fight code rot in your microservice architecture:
**Consider building overnight to fight code rot and keep services live and
healthy**. This is great advice since there may be services in your environment
that you'll probably won't touch for a few months and if you don't constantly
keep them building some developer having to fix a bug in one service will have a
hard time fixing outdated dependencies and stuff first.

I especially enjoyed [lizrice's](https://twitter.com/lizrice) keynote on
container security: **Scan your container images for security vulnerabilities**
and consider using `seccomp` in your containers.

[crichardson](https://twitter.com/crichardson) simply stated: **Microservices
shall not be the goal, that's an anti-pattern**. Yeah, for those of you who
didn't grasp that, already, probably.

I also attended [allenholub's](https://twitter.com/allenholub) talk on
choreographing microservices (in contrast to orchestrating them). Especially
enjoyable was his opinion on delivery: **I deploy the most simple implementation
and if nobody complains I'm done**. So true on so many levels, especially in an
enterprise environment where I work.

[nikhilbarthwal](https://twitter.com/nikhilbarthwal) shed some light on
real-world FaaS. My insight from his talk: **FaaS instances are auto-scaled but
your DB probably isn't**. As I followed the Twitter stream, though, his
opinions very passionately discussed and disputed. I liked his balanced plea
for a hybrid world of FaaS and "old-school" microservices.

[stilkov](https://twitter.com/stilkov) presented the most common software
architect's types; the one that sticked to me most is the **Disillusioned
Architect** that abstracts everything away. Stefan pointed to the term
'Architecture Astronauts' coined by Joel Spolsky.

[mikebroberts'](https://twitter.com/mikebroberts) keynote was especially
enlightening when he talk about the **four levels of adopting serverless**:

1. Serverless operations (env. reporting, Lambda as shell scripts, Slack bots,
deployment automation)

2. Cron jobs, Serverless offline tasks

3. Serverless activities (message processing, isolated microservices)

4. Serverless ecosystems (websites, web applications, serverless data pipelines)

Really great!

Less technical career advice for architects was given by JetBrains'
[trisha_gee](https://twitter.com/trisha_gee): **Everyone is an architect these
days**,  **ask questions and then LISTEN to the answers**, **be open to change
your mind**, **do pair programming not only with developers but probably with a
business analyst**, **answer Stack Overflow questions**. The last one is...
so... great.  Lay aside some time for your team to constantly be active on Stack
Overflow and it will change your attitude towards people and technologies and
you will learn A LOT!

Pivotal's [cdavisafc](https://twitter.com/cdavisafc) talked about getting rid
of the request-response paradigm in your software architecture. The punch line:
**There's a major difference between old-style messaging (aka ESB) and event
logs like Kafka (e.g. no queues, event log as single source of truth, loosely
coupled data): The former is anti-agile while the latter is agile.**

Thanks, O'Reilly for getting all those people (and me) to London. Perhaps we'll
see again next year.
