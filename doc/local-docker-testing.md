# Test the Docker image locally

This guide is for contributors testing the community-built image. It uses
regtest, Bitcoin's local test chain, with networking disabled and a separate
Docker volume. It does not connect to mainnet or require a wallet, coins, or a
blockchain download. The image is not an official DOG Mode release.

You need Docker running and a shell with Docker access. Run the commands in the
same shell so the image variables stay available. The names `dogmode-regtest`
and `dogmode-regtest-data` must be unused; choose different names throughout if
you already have a test using them. Do not mount an existing Bitcoin datadir.

## Pull and record an immutable image reference

```sh
DOGMODE_TAG=ghcr.io/dogofbitcoin/bitcoin:31.1-dogmode-7503240
docker pull "$DOGMODE_TAG"
DOGMODE_IMAGE=$(docker image inspect --format '{{index .RepoDigests 0}}' "$DOGMODE_TAG")
printf '%s\n' "$DOGMODE_IMAGE"
```

Record the printed `ghcr.io/dogofbitcoin/bitcoin@sha256:...` reference with your
test results. Tags can be moved; using the digest pins these commands to the
pulled image. Docker selects the image for your architecture. Record that too:

```sh
docker image inspect --format '{{.Os}}/{{.Architecture}}' "$DOGMODE_IMAGE"
docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$DOGMODE_IMAGE"
docker run --rm --network none --entrypoint sh --workdir /bin "$DOGMODE_IMAGE" -ec 'sha256sum -c /SHA256SUMS'
```

The revision label identifies the client source commit. Each checksum should
report `OK`. These checks verify the binaries against the sums included in the
same image; they are not an independent signature or proof of a reproducible
build. The Dockerfile pins the client commit, but other build inputs can change.

## Start a node and use its CLI

```sh
docker volume create dogmode-regtest-data
docker run -d --name dogmode-regtest --network none \
  -v dogmode-regtest-data:/data/.bitcoin "$DOGMODE_IMAGE" \
  -regtest -server -disablewallet -listen=0 -dnsseed=0 -discover=0 -connect=0 \
  -printtoconsole
docker exec dogmode-regtest bitcoin-cli -regtest -rpcwait -rpcwaittimeout=30 getblockchaininfo
docker exec dogmode-regtest bitcoin-cli -regtest getnetworkinfo
```

Expect `chain` to be `regtest` and `blocks` to be `0` on first start.
`localservicesnames` should include `DOG_MODE`, and `connections` should be `0`.
No ports are published. RPC stays inside the container and the CLI uses the
node's authentication cookie in the shared datadir, so no RPC password is
needed in these commands.

The datadir is `/data/.bitcoin` inside this image; regtest files are under
`/data/.bitcoin/regtest`. The named volume holds those files independently of
the container. Container removal does not remove this named volume.

## Generate local test blocks

```sh
docker exec dogmode-regtest bitcoin-cli -regtest generatetodescriptor 3 'raw(51)'
docker exec dogmode-regtest bitcoin-cli -regtest getblockcount
docker exec dogmode-regtest bitcoin-cli -regtest getbestblockhash
```

Expect a height of `3`. Save the best-block hash for the next check. `raw(51)` is
an OP_TRUE script used here only to generate regtest blocks without a wallet;
it is not a receiving address for real funds.

## Shut down and recreate the container

```sh
docker exec dogmode-regtest bitcoin-cli -regtest stop
docker wait dogmode-regtest
docker rm dogmode-regtest
docker run -d --name dogmode-regtest --network none \
  -v dogmode-regtest-data:/data/.bitcoin "$DOGMODE_IMAGE" \
  -regtest -server -disablewallet -listen=0 -dnsseed=0 -discover=0 -connect=0 \
  -printtoconsole
docker exec dogmode-regtest bitcoin-cli -regtest -rpcwait -rpcwaittimeout=30 getblockcount
docker exec dogmode-regtest bitcoin-cli -regtest getbestblockhash
```

`docker wait` should print `0`, the node's successful exit status. The recreated
container should still report height `3` and the same best-block hash. To test a
new image later, stop the node before recreating the container with the new
reference. Never run two nodes against the same datadir at once. Reusing chain
data is not a wallet backup or a guarantee of compatibility across versions.

## Remove this test's data

The last command below permanently removes this guide's regtest volume. Keep
the volume if you want to resume the test later.

```sh
docker exec dogmode-regtest bitcoin-cli -regtest stop
docker wait dogmode-regtest
docker rm dogmode-regtest
docker volume rm dogmode-regtest-data
```

## If a command fails

- If Docker cannot connect to its daemon, check that Docker is running and that
  your user has access before starting this guide.
- If RPC does not become ready within 30 seconds, inspect
  `docker logs dogmode-regtest` and `docker inspect dogmode-regtest`. An exited
  node or a datadir already in use needs fixing before retrying.
- If `DOG_MODE` is absent, record the image digest and revision label; a Core
  version string alone does not identify this policy fork.
- For a packaging report, include the digest, architecture, source revision,
  command, and relevant output in [this repository's issues](https://github.com/dogofbitcoin/docker-dogmode/issues).
  Remove credentials and private information before sharing logs.

## Where wallet and GUI work belongs

This image ships command-line node tools; the Dockerfile sets `BUILD_GUI=OFF`.
The wallet and Qt source live in [bitcoindogmode/bitcoin](https://github.com/bitcoindogmode/bitcoin).
The [Umbrel web interface](https://github.com/dogofbitcoin/umbrel-dogmode) is a
separate project. Client policy, wallet, and Qt changes belong with the client;
Docker build and image-runtime problems belong here. Follow the client's
contribution guidance when deciding whether a general change belongs upstream
in Bitcoin Core.
