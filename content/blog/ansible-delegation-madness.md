---
title: "Ansible delegation madness: delegate_to and variable substitution"
description: "Today I spent several hours tracking down a bug in one of our playbooks where a variable would be substituted with the wrong value if the task was delegated."
date: "2019-07-19"
authors: 
- Max Jonas Werner
categories: [personal]
cover:
  image: "/images/madness.jpg"
---

This is going to be a short piece but I really want to share this because 1)
I have to talk! It cost me several hours today to get a grip on this and 2) I
couldn't find any explanation of this Ansible behaviour on Stack Overflow or
anywhere else (I actually [posted this on
SO](https://stackoverflow.com/questions/57116025/ansible-variable-substitution-in-combination-with-task-delegation/)
to make sure it's now there). By the way, I was reminded today that it can save
you several hours of bug tracking, experimenting and general hair-tearing if you
just know to [ask. the right. question.](https://stackoverflow.com/questions/31912748/how-to-run-a-particular-task-on-specific-host-in-ansible/31912973)

Here at [Mesosphere](https://mesosphere.io) (and especially in the Cluster Ops
team I'm in) we use Ansible a lot for various stuff related to spinning up/down
and maintaining clusters. We build tools around making all of the operations of
DC/OS (and other) clusters insanely easy. Since I've joined the company recently
coming more from an application developer background and mostly developing tools
in Go here I'm not the most proficient Ansible user on this planet. So what I
had to achieve today was to run some tasks on all of the cluster's nodes and
some tasks only on one special node. What I came up with looked a bit like this:

```
01 - hosts: all
02  name: Test Play
03  gather_facts: false
04
05  tasks:
06      - name: Create output directory
07        tempfile:
08            state: directory
09            suffix: diag
10        register: output_dir
11
12      - name: Create API resources directory
13        file:
14            path: "{{ output_dir.path }}/api-resources"
15            state: directory
16        delegate_to: "{{groups['control-plane'][0]}}"
17        run_once: yes
18        register: api_resources_dir
```

The intent of this playbook was to create temporary directories on every node
(for storing some command output) and on one and only one host this temporary
directory should contain a directory named `api-resources`. When I ran this
playbook, though, that host ended up with two temporary directories, one of
which had the same name as the temporary directory on another host (and the
latter was surprisingly (or not) the one that conducted the delegation).

# What happened here?

Turns out, the expression `{{ output_dir.path }}` in the second task is
evaluated before the task is delegated to the other node. Therefore, the node
creates the `api-resources` directory in another directory as the one that is
created in the first task.

# What's the correct way to do this?

The correct way is to first figure out what you're doing wrong and why. That
took me 90% of the time today. It's probably just a matter of Ansible experience
and of not just applying the same pattern (using `delegate_to`) you've seen
elsewhere. Interestingly enough, I figured out the correct question only after I
found the answer to my problem: "How do I run a task on one specific node?". But
when you think that `delegate_to` is the right solution you don't even arrive at
asking that question (again).

There's this nice thing called `when` in Ansible that comes in handy here.
Here's the corrected playbook:

```
 1	- hosts: all
 2	  name: Test Play
 3	  gather_facts: false
 4
 5	  tasks:
 6	      - name: Create output directory
 7	        tempfile:
 8	            state: directory
 9	            suffix: diag
10	        register: output_dir
11
12	      - name: Create API resources directory
13	        file:
14	            path: "{{ output_dir.path }}/api-resources"
15	            state: directory
16	        when: inventory_hostname == groups['control-plane'][0]
17	        register: api_resources_dir
```

Nice and slick. I hope this post will save someone a bad day.

Have a great one!
