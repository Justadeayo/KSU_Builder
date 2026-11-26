# Reporting Security Issues

This repository holds build workflows and scripts. It doesn't hold KernelSU or SUSFS source code.

- **Problems in these workflows or scripts** (for example a secret that could leak from a build, or a script that runs untrusted input): open a GitHub Issue on this repository. If the report contains details that should stay private, use GitHub's private vulnerability reporting for this repository, if the owner has enabled it.
- **Vulnerabilities in KernelSU itself**: report them to the KernelSU project, using its [Security Advisory tab](https://github.com/tiann/KernelSU/security/advisories/new) or by contacting the maintainer directly, as described in the upstream repository.
- **Vulnerabilities in SUSFS, BakaSU, NoMount or AnyKernel3**: report them to those projects' own repositories.

Builds from this repository are experimental and aren't signed with production certificates. See [`LICENSE`](LICENSE) for the terms that apply to artifacts.
