# openmediavault-imagecheck

A **monitor-only** OpenMediaVault plugin that reports whether newer Docker
images are available for your running containers.

It **never** pulls, recreates, or changes anything. It only compares digests
and reports.

Companion app: [OMV Companion on Google Play](https://play.google.com/store/apps/details?id=net.hackitz.omvcompanion)
(optional — see [below](#omv-companion)).

## How it works

- `/usr/sbin/omv-imagecheck` (python3) lists running containers, and for each
  unique image compares the **local** registry digest (`RepoDigests`, i.e. what
  was actually pulled) against the **current registry** digest for that same
  tag, fetched *without pulling* via `docker buildx imagetools inspect`.
  Different digest → an update is available.
- The result is written atomically to `/var/lib/openmediavault/imagecheck.json`.
- A daily cron job (`/etc/cron.d/openmediavault-imagecheck`, 04:17) refreshes it.
- The workbench page **Services → Image Check** lists the result and has a
  *Check now* button that runs the checker as a background task.
- A dashboard widget (**Docker Image Updates**) shows one tile per container.
- An RPC service named **`ImageCheck`** exposes:
  - `getStatus` — cheap cached `{updateCount, checked, generatedAt, error}`.
    Safe to poll often (it only reads the cache file).
  - `getUpdateList` — paged per-container list (`start/limit/sortfield/sortdir`)
    with `local`, `remote`, `updateAvailable`, and any per-image `error`.
  - `refresh` — runs the checker now as a background task and streams its
    output (like `Apt.update`).

## Why a daily cache instead of checking live

Registry digest lookups are network round-trips and Docker Hub rate-limits
unauthenticated requests (~100 per 6h per IP). Doing the check once a day
server-side and having clients read a precomputed count keeps things instant
and avoids ever tripping the limit. The checker also de-duplicates images, so N
containers sharing one image cost one registry lookup.

## Requirements

- OpenMediaVault 7 or 8 (uses the standard `\OMV\Rpc\ServiceAbstract` +
  `execBgProc` API; no config database entries at all).
- Docker reachable as **root** (the cron job and the OMV engine both run as
  root). `docker buildx` must be present — it ships with modern Docker Engine.
- Private registries work automatically if the host is already `docker login`'d
  (buildx uses the host's `~/.docker/config.json`).

## Install

Once the plugin is in the omv-extras repository it is installed like any other
plugin, from **System → Plugins**, or:

```bash
sudo apt-get install openmediavault-imagecheck
```

### Building the package yourself

On a Debian box with `build-essential`, `debhelper` and `devscripts`:

```bash
git clone https://github.com/hackitz/openmediavault-imagecheck.git
cd openmediavault-imagecheck
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../openmediavault-imagecheck_*_all.deb
```

The package is `3.0 (native)`, so the version in `debian/changelog` is the
whole version — bump it there for each release.

### Manual install (no packaging)

`install.sh` / `uninstall.sh` copy the same files into place on a single
server without building a `.deb`. Handy for testing:

```bash
sudo bash install.sh
```

## Verify

```bash
omv-rpc -u admin 'ImageCheck' 'getStatus' | python3 -m json.tool
omv-imagecheck --print
```

## Package layout

```
debian/                                     packaging (native, dh 13)
etc/cron.d/openmediavault-imagecheck        daily refresh at 04:17
usr/sbin/omv-imagecheck                     the checker (python3)
usr/share/openmediavault/engined/rpc/       ImageCheck RPC service
usr/share/openmediavault/workbench/
  component.d/                              datatable page + "Check now"
  dashboard.d/                              dashboard widget
  navigation.d/, route.d/                   Services → Image Check
```

There are no `datamodels/` or `confdb/` entries because the plugin stores no
configuration — everything it needs lives in the JSON cache.

## Notes / edge cases

- Containers running an image **pinned by digest** or a **locally-built** image
  (no registry digest) are listed but marked "not a checkable tag" — there is
  nothing newer to compare against.
- A per-image lookup failure (rate limit, private registry with no host login,
  transient network) is recorded as that row's `error` and is **not** counted as
  an update — so a failed lookup never becomes a false "update available".
- Multi-arch images compare correctly: both `RepoDigests` and
  `imagetools .Manifest.Digest` refer to the manifest-list (index) digest.
- Purging the package removes the JSON cache; plain removal keeps it.

## OMV Companion

This plugin is the server-side counterpart to **OMV Companion**, an Android app
for monitoring and managing an OpenMediaVault server:

**[OMV Companion on Google Play](https://play.google.com/store/apps/details?id=net.hackitz.omvcompanion)**

The app consumes `getStatus`/`getUpdateList` when this plugin is installed —
surfacing the update count next to its package-updates count — and falls back
to driving `Compose.doDockerCmd` itself when it isn't.

The plugin is **not** required to use the app, and the app is not required to
use the plugin: the workbench page and dashboard widget work on their own.
