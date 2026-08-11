# openmediavault-imagecheck

A tiny, **monitor-only** OpenMediaVault plugin that reports whether newer
Docker images are available for your running containers. It is the clean,
server-side counterpart to OMV Companion's app-side check: the app calls this
plugin's RPC when it's installed, and falls back to driving `Compose.doDockerCmd`
itself when it isn't.

It **never** pulls, recreates, or changes anything. It only compares digests
and reports. (Same philosophy as the app: monitor, don't apply.)

## How it works

- `/usr/sbin/omv-imagecheck` (python3) lists running containers, and for each
  unique image compares the **local** registry digest (`RepoDigests`, i.e. what
  was actually pulled) against the **current registry** digest for that same
  tag, fetched *without pulling* via `docker buildx imagetools inspect`.
  Different digest → an update is available.
- The result is written atomically to `/var/lib/openmediavault/imagecheck.json`.
- A daily cron job (`/etc/cron.d/openmediavault-imagecheck`, 04:17) refreshes it.
- An RPC service named **`ImageCheck`** exposes:
  - `getStatus` — cheap cached `{updateCount, checked, generatedAt, error}`.
    Safe to poll every alert cycle (it only reads the cache file), which is how
    the app surfaces the count next to its package-updates count.
  - `getUpdateList` — paged per-container list (`start/limit/sortfield/sortdir`)
    with `local`, `remote`, `updateAvailable`, and any per-image `error`.
  - `refresh` — runs the checker now as a background task and streams its
    output (like `Apt.update`); the app then re-reads `getStatus`/`getUpdateList`.

## Why a daily cache instead of checking live

Registry digest lookups are network round-trips and Docker Hub rate-limits
unauthenticated requests (~100 per 6h per IP). Doing the check once a day
server-side and having the app read a precomputed count keeps the app's alert
loop instant and avoids ever tripping the limit. The checker also de-duplicates
images, so N containers sharing one image cost one registry lookup.

## Requirements

- OpenMediaVault 7/8 (uses the standard `\OMV\Rpc\ServiceAbstract` +
  `execBgProc` API).
- Docker reachable as **root** (the cron job and the OMV engine both run as
  root). `docker buildx` must be present — it ships with modern Docker Engine.
- Private registries work automatically if the host is already `docker login`'d
  (buildx uses the host's `~/.docker/config.json`).

## Install (single server, no packaging needed)

Copy this folder to the OMV server, then:

```bash
sudo bash install.sh
```

Verify:

```bash
omv-rpc -u admin 'ImageCheck' 'getStatus' | python3 -m json.tool
omv-imagecheck --print
```

Uninstall:

```bash
sudo bash uninstall.sh
```

## Notes / edge cases

- Containers running an image **pinned by digest** or a **locally-built** image
  (no registry digest) are listed but marked "not a checkable tag" — there is
  nothing newer to compare against.
- A per-image lookup failure (rate limit, private registry with no host login,
  transient network) is recorded as that row's `error` and is **not** counted as
  an update — so a failed lookup never becomes a false "update available".
- Multi-arch images compare correctly: both `RepoDigests` and
  `imagetools .Manifest.Digest` refer to the manifest-list (index) digest.

## Turning this into a real .deb later

The tree already mirrors the filesystem layout a Debian package would install
(`usr/…`, `etc/…`). To distribute it (e.g. via omv-extras or your own apt repo),
add a `debian/` dir with `control`, `rules`, `postinst` (restart
`openmediavault-engined`), and `cron.d` handling, then `dpkg-buildpackage`. Not
required for your own box.
