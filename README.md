# devcontainer

A script that builds and starts an Ubuntu 26.04 C++ development container using
[Apple's container framework](https://github.com/apple/container), for use with
VS Code.

The image has g++ (GCC 15, with full C++20 thread support), git and ssh. You work
as a non-root user that matches your macOS user, with passwordless `sudo`.

## Requirements

- macOS on Apple silicon
- The [`container`](https://github.com/apple/container) CLI

## Usage

```sh
./dev-container.sh [-n NAME] [-w DIR]
```

| Option | Description | Default |
|---|---|---|
| `-n NAME` | Container name | `dev` |
| `-w DIR` | Host directory to mount at `/workspace` | current directory |

What the script does:

- **No container with that name:** builds the image and starts a new container
- **Container is stopped:** restarts it as-is
- **Container is already running:** exits with an error

The container gets all of your Mac's CPUs and 75% of its memory, leaving the
rest for macOS.

## Mounts

| Container path | Source | Use it for |
|---|---|---|
| `/workspace` | Host directory (`-w`) | Source code you edit on the Mac |
| `/data` | Named volume `<name>-data` | Large data files and build output (much faster I/O) |
| `~/.ssh` | Host `~/.ssh`, read-only | Using your ssh keys for git |

The `/data` volume stays when the container is deleted.

## Common tasks

Start the default container, then attach to it from VS Code:

```sh
./dev-container.sh
```

Start a second container for another project:

```sh
./dev-container.sh -n proj2 -w ~/git/proj2
```

Open a shell in the container:

```sh
container exec -it dev bash
```

Rebuild after changing the `Dockerfile` (the `/data` volume is kept):

```sh
container stop dev && container rm dev
./dev-container.sh
```

Delete the data volume too:

```sh
container volume rm dev-data
```
