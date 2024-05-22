---
title: "The Story of a GitHub Actions Workflow"
date: 2022-11-19
authors: 
- Max Jonas Werner
cover:
  image: "/images/story-book.jpg"
  alt: "an old book laying open on a table"
  caption: "(Photo by [Aaron Burden](https://unsplash.com/@aaronburden?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/s/photos/ancient-book?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText))"
---

[Discuss this post](https://hachyderm.io/@makkes/109377473189626346)

This is the story of a seemingly simple task of creating a GitHub Actions workflow that ... escalated quickly. I hope you people can learn from my mistakes and do better (or quicker).

You'll find the tl;dr version [here](#the-lessons).

Over at Weaveworks we try to automate as many engineering processes as possible. That's especially true for the tedious work of releasing a new version of one of the components we build. One of these components is a Kubernetes controller running as part of Weave GitOps Enterprise, the enterprise version of our [OSS Weave GitOps](https://github.com/weaveworks/weave-gitops/). The controller is basically shipped in a container image and a Helm chart wrapping all the necessary manifests, Deployments, Services etc.

What we had already setup was a GitHub Actions workflow that would build and push a new container image version whenever a Git tag was pushed to the repository, nice and easy and a pretty standard workflow. However, after that image was pushed we still had to go ahead and manually update the chart version and the image version used within it. The chart building and publishing again was already properly automated.

So inbetween two tasks I was working on I wanted to spend an hour or two building a workflow that would bump the chart version and the app version within the chart whenever a new container image was pushed. It should then create a PR with those changes so we can still verify it. Sounds like a very low-hanging fruit, right? That's what I thought, too. 

## Version 1

This is the initial version I came up with. First, the trigger:

```yaml
name: Update app in chart
on:
  registry_package:
    types:
      - published
```

Simple, right? GitHub Actions provides a nice [https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#registry_package](event) that triggers a workflow whenever something is pushed to the package registry. Spoiler alert: This didn't work without changes to other workflows. More on that later. Let's look at the single job within that workflow:

```yaml
jobs:
  update-chart:
    if: ${{ github.event.registry_package.name == 'pipeline-controller' }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: bump app version
        uses: mikefarah/yq@v4.30.4
        with:
          cmd: yq -i '.appVersion = "${{ github.event.registry_package.package_version.container_metadata.tag.name }}"' charts/pipeline-controller/Chart.yaml
```

Easy; set the new app version from the image that triggered the workflow. We will see later on that like it is here it may set the `appVersion` to an empty string. More on that later.

```yaml
      - name: get chart version
        id: get_chart_version
        uses: mikefarah/yq@v4.30.4
        with:
          cmd: yq '.version' charts/pipeline-controller/Chart.yaml
      - name: increment chart version
        run: echo ${{ steps.get_chart_version.outputs.result }} awk -F. -v OFS=. '{print $1,++$2,0}'
      - name: update chart version
        uses: mikefarah/yq@v4.30.4
        with:
          cmd: yq -i '.version = "${{ steps.get_chart_version.outputs.result }}"' charts/pipeline-controller/Chart.yaml
```

These 3 steps above were supposed to extract the existing chart version, increase the minor version, set the patch version to '0' and store the new version in the `Chart.yaml`. However, there's two bugs in there, can you spot them?

```yaml
      - name: Create Pull Request
        id: cpr
        uses: peter-evans/create-pull-request@v4
        with:
          commit-message: |
            Update app version in chart
          committer: GitHub <noreply@github.com>
          author: ####### REDACTED ######
          branch: update-chart
          title: Update app version in chart
      - name: Check output
        run: |
          echo "Pull Request Number - ${{ steps.cpr.outputs.pull-request-number }}"
          echo "Pull Request URL - ${{ steps.cpr.outputs.pull-request-url }}"
```

Straightforward, create a PR from the changes so we can review and merge them. Turns out, a PR created like that couldn't be merged with the repo settings we had in place.

Almost every single step in that workflow has bugs. But were we able to spot them before actually merging the new workflow into `main`? No, because I yet have to find a way to test a workflow without actually merging and running it. Please let me know if you know of any! So we went ahead and merged that workflow file, created a new Git tag and waited until a new image version was pushed for the workflow to be triggered.

## Not Running At All

The first we observed was that the workflow wasn't even triggered at all. We already knew that you couldn't just [trigger a workflow from another workflow](https://docs.github.com/en/actions/using-workflows/triggering-a-workflow#triggering-a-workflow-from-a-workflow) but what we didn't know was that this behaviour is carried forward even for transitive actions such as an image push. We changed the other workflow pushing the new image to the registry to use a personal access token and that fixed that. The workflow was running now.

**Lesson #1:** When you want a workflow to be triggered by a new image version being pushed to GitHub's registry, make sure to not use the default workflow token for pushing that image. Otherwise workflows listening the push event won't run.

## Version 2

The next thing we noticed was that the workflow was triggered 3 times. We had no clue why but decided to fix the other issues first. One of these was the step incrementing the chart version not working. This was a simple syntax error as we forgot a pipe character:

```yaml
-        run: echo ${{ steps.get_chart_version.outputs.result }} awk -F. -v OFS=. '{print $1,++$2,0}'
+        run: echo ${{ steps.get_chart_version.outputs.result }} | awk -F. -v OFS=. '{print $1,++$2,0}'
```

Easy! Next!

## Version 3

Next we discovered that the new chart version set by the workflow was wrong. It didn't bump the version at all. Turns out the step setting the new version referenced the wrong step:

```yaml
         with:
           cmd: yq '.version' charts/pipeline-controller/Chart.yaml
       - name: increment chart version
+        id: inc_chart_version
         run: echo ${{ steps.get_chart_version.outputs.result }} | awk -F. -v OFS=. '{print $1,++$2,0}'
       - name: update chart version
         uses: mikefarah/yq@v4.30.4
         with:
-          cmd: yq -i '.version = "${{ steps.get_chart_version.outputs.result }}"' charts/pipeline-controller/Chart.yaml
+          cmd: yq -i '.version = "${{ steps.inc_chart_version.outputs.result }}"' charts/pipeline-controller/Chart.yaml
       - name: Create Pull Request
         id: cpr
         uses: peter-evans/create-pull-request@v4
```

## Version 4

Finally we wanted to find out why the workflow was triggered 3 times so I added a debug step that would just dump the complete event:

```yaml
     if: ${{ github.event.registry_package.name == 'pipeline-controller' }}
     runs-on: ubuntu-latest
     steps:
+      - name: dump event
+        run: echo ${{ toJson(github.event) }}
       - name: Checkout
         uses: actions/checkout@v3
       - name: bump app version
```

This didn't work because the `run` syntax wasn't correct but it did dump the event nevertheless. The reason for the multiple triggering was actually kind of simple: We pushed a multi-arch container image comprised of a AMD64 image and an ARM64 manifest. Another manifest list manifest ties these together then. For each of the manifests pushed, a `registry_package` event is emitted.

So we went ahead and added another condition to the job run:

## Version 5

```yaml
 jobs:
   update-chart:
-    if: ${{ github.event.registry_package.name == 'pipeline-controller' }}
+    if: ${{ github.event.registry_package.name == 'pipeline-controller' && github.event.registry_package.package_version.container_metadata.tag.name != '' }}
     runs-on: ubuntu-latest
     steps:
       - name: dump event
```

Now the `update-chart` job is only run for the event carrying the new image tag.

**Lesson #2:** When using the `registry_package` event as a trigger make sure to use proper conditions when reacting to multi-arch image pushes.

## Version 6

Now the workflow was running only once (it still shows up 3 times but the other 2 are skipped) but the new chart version still wasn't set. Turns out I didn't understand how you carry command outputs from one step to another. After reading up on this [in the docs](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter) we fixed that:

```yaml
           cmd: yq '.version' charts/pipeline-controller/Chart.yaml
       - name: increment chart version
         id: inc_chart_version
-        run: echo ${{ steps.get_chart_version.outputs.result }} | awk -F. -v OFS=. '{print $1,++$2,0}'
+        run: echo NEW_CHART_VERSION=$(echo ${{ steps.get_chart_version.outputs.result }} | awk -F. -v OFS=. '{print $1,++$2,0}') >> $GITHUB_OUTPUT
       - name: update chart version
         uses: mikefarah/yq@v4.30.4
         with:
-          cmd: yq -i '.version = "${{ steps.inc_chart_version.outputs.result }}"' charts/pipeline-controller/Chart.yaml
+          cmd: yq -i '.version = "${{ steps.inc_chart_version.outputs.NEW_CHART_VERSION }}"' charts/pipeline-controller/Chart.yaml
       - name: Create Pull Request
         id: cpr
         uses: peter-evans/create-pull-request@v4
```

**Lesson #3:** Use `GITHUB_OUTPUT` for carrying command output from one step to another.

## Version 7

Now the commit from the PR looked good but no CI checks were run. One more time the constraint of "a workflow can't trigger another workflow with the default GitHub token" kicked in. Fixing this was easy:

```yaml
         id: cpr
         uses: peter-evans/create-pull-request@v4
         with:
+          token: ${{ secrets.GHCR_TOKEN }}
           commit-message: |
             Update app version in chart
           committer: GitHub <noreply@github.com>
```

**Lesson #4:** When creating a PR using the default workflow token, no CI checks are run. You need to create a personal access token.

## Version 8

Woohoo, we got it! After creating what felt like a million Git tags to trigger the workflow over and over again and cluttering Git history with another million commits fixing the workflow, it was kicked off as expected, the PR looked fine and all CI checks were running.

But, oh no, GitHub didn't allow us to merge the PR because the commit wasn't signed. Duh! One more time:

## Version 9

```yaml
     steps:
       - name: Checkout
         uses: actions/checkout@v3
+      - name: Import GPG key for signing commits
+        uses: crazy-max/ghaction-import-gpg@v3
+        with:
+          gpg-private-key: ${{ secrets.GPG_PRIVATE_KEY }}
+          passphrase: ${{ secrets.GPG_PASSPHRASE }}
+          git-user-signingkey: true
+          git-commit-gpgsign: true
```

This additional step led to the commits created by the `create-pull-request` action to be signed and the PR to finally be in a mergeable state. Hooray!

## The Final Version

The icing on the cake was a little change to make the PR more comprehensible and basically document what it does in the description:

```yaml
           committer: GitHub <noreply@github.com>
           author:  ###### REDACTED ######
           branch: update-chart
-          title: Update app version in chart
+          title: Update app version to ${{ github.event.registry_package.package_version.container_metadata.tag.name }} in chart
+          body: |
+            This PR bumps the minor chart version by default. If it is more appropriate to bump the major or the patch versions, please amend the commit accordingly.
+
+            The workflow that this PR was created from is "${{ github.workflow }}".
       - name: Check output
         run: |
           echo "Pull Request Number - ${{ steps.cpr.outputs.pull-request-number }}"
```

This was the story of a seemingly very simple workflow we thought wouldn't take more than 1 or 2 hours and turned out to take around a full day.

## The Lessons

**Lesson #1:** When you want a workflow to be triggered by a new image version being pushed to GitHub's registry, make sure to not use the default workflow token for pushing the image. Otherwise workflows listening to the push event won't run. [Related documentation](https://docs.github.com/en/actions/using-workflows/triggering-a-workflow#triggering-a-workflow-from-a-workflow)

**Lesson #2:** When using the `registry_package` event as a trigger make sure to use proper conditions when reacting to multi-arch image pushes. I created [a PR for adding this info to the documentation](https://github.com/github/docs/pull/22092) that hopefully gets merged soon.

**Lesson #3:** Use `GITHUB_OUTPUT` for carrying command output from one step to another. [Related documentation](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter)
