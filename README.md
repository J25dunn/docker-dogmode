# docker-dogmode

DOG Mode `bitcoind` as a Docker image, built from source at one pinned commit of
[bitcoindogmode/bitcoin](https://github.com/bitcoindogmode/bitcoin). Made for the Umbrel package
maintained by the Dog of Bitcoin Foundation. Not an official release of the DOG Mode project.

Why from source: the DOG Mode project has not cut a release yet, so there is no tarball to
download and no signature to verify. This image compiles the client itself and says so. The
`Dockerfile` names the repository and the exact commit (checked after checkout), builds the
dependencies with the repository's own `depends` system (static, the way release binaries are
made), and prints the binaries' SHA256 sums, which also ship inside the image at `/SHA256SUMS`.
The included sums check binary integrity within the image; they do not establish
independent authenticity or reproducible builds. When the project publishes a signed
release, this image switches to download-and-verify like `getumbrel/docker-bitcoind`.

For a first contributor run, follow the [local Docker testing guide](doc/local-docker-testing.md).
It covers digest pinning, an isolated regtest datadir, CLI access, shutdown,
persistence, cleanup, and where wallet or Qt changes belong.

Tags are never reused. `31.1-dogmode-7503240-r2` is the same commit as `31.1-dogmode-7503240`, rebuilt to ship
its licenses; a rebuild compiles new binaries, so each tag's run log and `/SHA256SUMS` carry its own hashes.

Built by GitHub Actions on native amd64 and arm64 runners; one tag for both architectures.
Pin the manifest-list digest, printed at the end of each run, wherever the image is consumed.

| | |
|---|---|
| Commit | `75032400914250c7ad857dc29043761680a66485` (the merge of DOG Mode pull request 3 into `31.1-dogmode`) |
| Base | Bitcoin Core 31.1 plus the DOG Mode relay policy (3,900,000 WU standard transactions, a global 1 sat dust limit, preferential peering on service bit 14) |
| Binaries | `bitcoind`, `bitcoin-cli`, `bitcoin`, `bitcoin-node` (the multiprocess node, for the IPC interface) |
| Contact | contact@dogofbitcoin.org |

## Credit and licenses

DOG Mode is the DOG Mode project's client ([bitcoindogmode/bitcoin](https://github.com/bitcoindogmode/bitcoin)),
built on Bitcoin Core by the Bitcoin Core developers. This image only compiles it, is maintained by the Dog of
Bitcoin Foundation, and is not an official DOG Mode release.

Inside the image, at `/usr/share/doc/dogmode/`:

| | |
|---|---|
| `COPYING` | Bitcoin Core's MIT license, which covers the client |
| `licenses/` | the license files of the dependencies built into the static binaries (boost, libevent, ZeroMQ, Cap'n Proto; SQLite is public domain and ships none), taken from the exact source archives the build checked by hash |
| `SOURCES` | those archives' names and SHA-256 hashes, so anyone can fetch the identical sources (ZeroMQ's MPL-2.0 asks for this) |
| `BUILD` | the repository and commit the client was built from |

This repository's own files (the `Dockerfile`, the workflow, this README) are MIT licensed; see `LICENSE`.
