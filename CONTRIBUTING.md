# Contributing to raspbian-ua-netinst

Thank you for your interest in making raspbian-ua-netinst better :+1:

There are currently 2 ways in which you can contribute:
- [Reporting issues](#reporting-issues)
- [Submitting Pull Requests](#submitting-pull-requests)

This document outlines how to best report issues you may encounter and the way we prefer pull requests.

## Reporting issues
First, search through the existing [issues](https://github.com/debian-pi/raspbian-ua-netinst/issues) to see whether your issue is already known. If it is, add your details to the existing report. The more details we have, the better the chance for a fix.
An existing issue may also provide a (temporary) workaround.

In order for us to help with an issue, it's useful if you provide as much detail as possible.
That starts with a clear descriptive title. It is likely that at any given time there are a number of issues open. A clear title helps us (and others) to easily locate a certain issue.
Then provide the steps you took in order to accomplish a certain task. The following can be used as a template for it:

1. What did you try to accomplish?
2. What steps did you take in order to accomplish that?
3. What did you expect to happen?
4. What actually happened?

Furthermore, it helps if you provide the configuration files you used, such as `installer-config.txt`. Make sure to remove/replace sensitive information, if present. The installer also creates a log file, which is either located in `/boot/` or when the installation finished, in `/var/log/`. If you can provide those, that helps too.

## Submitting Pull Requests
We currently have 2 development branches, v1.1.x, which is used for the v1.1.X releases and v1.2.x for new feature developments.  
The v1.0.x branch was used for the v1.0.X releases but is no longer used.  
The master branch is synced with the latest stable release, but can include documentation updates.  
Since we follow [semantic versioning](http://semver.org/), that means that pull requests that require a new (configuration) parameter need to be submitted to the v1.2.x branch. Pull requests that don't need a new parameter, such as a bug fix, should be submitted to the v1.1.x branch.

When you want to create a pull request, the best way to do that is by creating a [topic branch](https://github.com/dchelimsky/rspec/wiki/topic-branches), branched off of either v1.1.x or v1.2.x according to the criteria outlined above, preferably with a name describing what the branch is about. When you're writing the code for your pull request, we prefer smaller (atomic) commits over 1 commit with a lot of 'unrelated' changes.
Each commit should have a clear message saying what has changed. If you want to provide more context to your commit, that's an excellent candidate for the second line of your commit message.
An example is the following commit: [Add filesystem packages so fsck can be run from initramfs.](https://github.com/debian-pi/raspbian-ua-netinst/commit/a7e80f0dba793cd38945b596a9fd4b3b843d7bbb)

A pull request is generally reviewed according to the following rules:

- What's the added value, in other words is there a (good) use case for it
- Your change shouldn't have a negative effect on the rest of the code
- It should not (needlessly) complicate the code
- The code should be in line with the rest of the existing code, for example a boolean true is represented as a '1' (at least in the v1.x branches), like the `usbroot` configuration parameter.
- It shouldn't fundamentally change the way the installer works. At least not during the v1.x series. We don't know in what ways the installer is used currently, but we don't want to break those uses.  
Such changes *could* be considered for a v2.x series, but there are no plans for that right now.

Note that most, if not all, of us do this in our free time, so sometimes you get a quick response and in other times it may take longer. You should also be willing to update your code if one of the collaborators think it's needed.  
We assume that you've read GitHub's help page [regarding pull request](https://help.github.com/articles/using-pull-requests/).
