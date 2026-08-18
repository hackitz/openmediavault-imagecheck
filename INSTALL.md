# Installing the OMV ImageCheck plugin — a beginner's guide

This guide installs **openmediavault-imagecheck**, the small server-side add-on that
checks whether your Docker containers have newer images available and reports the count
to the OMV Companion app. It never pulls, updates, or changes your containers — it only
looks and reports.

You'll do everything by connecting to your OpenMediaVault (OMV) server's command line
from your own computer and downloading the plugin from GitHub. **No coding required** —
you copy and paste a handful of commands.

- **Time needed:** about 10 minutes
- **Difficulty:** beginner (every step is spelled out)
- **You will need:** your OMV server powered on, the password for it, and any computer
  (Windows, Mac, or Linux) on the same network

> **About the word "SSH":** SSH just means securely opening your server's command line
> from your own computer — like a remote keyboard for the server. Because the plugin's
> code lives in a **public** GitHub repository, you do **not** need a GitHub account, a
> password, or SSH keys for GitHub. You'll download it with a single command.

---

## Before you start — a quick checklist

You need three things. Don't worry, the steps below show you how to get each one.

1. **SSH turned on in OMV** (Step 1).
2. **Your server's IP address** — something like `192.168.1.100` (Step 2).
3. **The server's login** — usually the username `root` and the password you set when you
   installed OMV.

Your server should already be running Docker with some containers, since that's what the
plugin checks. If Docker isn't set up yet, do that first.

> **Requirements:** This plugin needs **OpenMediaVault 8 or newer** — OMV 7 is
> end-of-life, and the installer will stop if it detects OMV 7. Your server also needs
> **internet access during installation**, because the installer downloads a small helper
> tool called `regctl` (used to ask your container registries whether a newer image
> exists). Your server almost certainly already has internet — the same connection it uses
> to pull container images.

---

## Step 1 — Turn on SSH in OMV

SSH is usually off by default. Turn it on from the OMV web page:

1. Open OMV in your web browser (the address you normally use to manage it, e.g.
   `http://192.168.1.100`) and log in.
2. In the left menu go to **Services → SSH**.
3. Tick **Enabled**.
4. Tick **Permit root login** (this lets you log in as `root`, which we'll use below).
5. Click **Save**, then click the yellow **Apply** banner that appears at the top.

That's the only thing you need to do in the web page. Leave the browser open — you'll use
it again at the end to check things worked.

---

## Step 2 — Find your server's IP address

If you don't already know it, the OMV web page shows it: go to the OMV **Dashboard** and
look for the network/IP widget, or check **Network → Interfaces**. Write down the address
that looks like `192.168.x.x`. We'll call it **YOUR-SERVER-IP** from here on.

---

## Step 3 — Open a terminal and connect to the server

A "terminal" is the plain text window where you type commands. Open it based on your
computer:

- **Windows:** click Start, type **PowerShell**, and open **Windows PowerShell**.
- **Mac:** press **Cmd+Space**, type **Terminal**, and press Enter.
- **Linux:** open your **Terminal** app.

Now connect. Type this (replace `YOUR-SERVER-IP` with the address from Step 2) and press
Enter:

```bash
ssh root@YOUR-SERVER-IP
```

Example: `ssh root@192.168.1.100`

- The **first time** you connect, it asks something like *"Are you sure you want to
  continue connecting (yes/no)?"* — type **yes** and press Enter. (This is normal; it's
  just remembering your server.)
- It then asks for a **password**. Type your OMV root password and press Enter.
  **Note:** the password is invisible as you type — no dots or stars appear. That's normal.
  Just type it and press Enter.

When you see the prompt change to something ending in `#` (for example `root@omv:~#`),
you're connected to the server. Everything you type now runs **on the server**.

---

## Step 4 — Make sure `git` is installed

`git` is the tool that downloads code from GitHub. Most systems have it; this installs it
if it's missing. Copy-paste the whole line and press Enter:

```bash
apt-get update && apt-get install -y git
```

If it was already installed, this just finishes quickly. If it installs it, that's fine too.

---

## Step 5 — Download the plugin from GitHub

This copies the plugin's files onto your server. Paste and press Enter:

```bash
git clone https://github.com/hackitz/openmediavault-imagecheck.git
```

You'll see a few lines about "Cloning into..." and it finishes in a second or two. Now move
into the folder it created:

```bash
cd openmediavault-imagecheck
```

> If you ever want to see the files you just downloaded, type `ls` and press Enter.

---

## Step 6 — Run the installer

This puts the plugin into place, does a first check to warm up the data, and restarts the
OMV engine so the app can talk to it. Paste and press Enter:

```bash
sudo bash install.sh
```

(You're logged in as root, so it won't ask for a password again.) Let it finish — it prints
its progress and ends when it's done. This can take a minute the first time because it
checks each of your containers' images.

During install it also:

- **Checks your OMV version** and stops if it's older than OpenMediaVault 8.
- **Downloads `regctl`** (a small tool it uses to ask your container registries whether a
  newer image exists) and places it at `/usr/local/bin/regctl`. This is why the server
  needs internet access for this step.

---

## Step 7 — Check that it worked

Run the plugin's own status command:

```bash
omv-imagecheck --print
```

You should see some output listing your containers and how many have updates available
(for example a line with `"updateCount"`). If you see that, **the plugin is installed and
working.** 🎉

You can also confirm the app-facing service responds:

```bash
omv-rpc -u admin 'ImageCheck' 'getStatus'
```

That prints a short summary the OMV Companion app reads.

When you're done, you can close the connection by typing `exit` and pressing Enter.

---

## What happens now

- The plugin checks your images **once a day automatically** (early morning) and saves the
  result. It doesn't hammer your network or the registries.
- The **OMV Companion app** reads that saved result and shows the "updates available" count
  next to your other server info — no extra setup in the app.
- It only **reports**. It never pulls or changes a container. You stay in control of when
  to actually update anything.

---

## Updating the plugin later

If a newer version of the plugin is released on GitHub, connect again (Step 3) and run:

```bash
cd openmediavault-imagecheck
git pull
sudo bash install.sh
```

`git pull` grabs the latest files; re-running the installer applies them.

---

## Uninstalling

If you ever want to remove it, connect again and run:

```bash
cd openmediavault-imagecheck
sudo bash uninstall.sh
```

---

## Troubleshooting

**"Connection refused" or "Connection timed out" when you run `ssh`**
SSH probably isn't enabled yet, or the IP is wrong. Recheck Step 1 (and that you clicked
**Apply**) and Step 2. Make sure your computer is on the same network as the server.

**"Permission denied" after typing your password**
The password was mistyped (remember, it's invisible as you type — that's normal), or root
login isn't allowed. Recheck the **Permit root login** box in Step 1, and try again. If you
normally use a different username, log in with `ssh yourname@YOUR-SERVER-IP` instead, and
put the word `sudo` in front of the install/uninstall commands.

**`git: command not found`**
Run Step 4 again to install it: `apt-get update && apt-get install -y git`.

**`fatal: repository not found` when cloning**
Double-check the web address in Step 5 is typed exactly. The repository must be public and
pushed to GitHub first — if you just created it, make sure it finished uploading.

**The installer says it requires OpenMediaVault 8 or newer**
This plugin supports OMV 8+ (OMV 7 is end-of-life). Upgrade OpenMediaVault to version 8 or
newer, then run `sudo bash install.sh` again.

**The installer says it couldn't download `regctl`**
The installer fetches `regctl` from GitHub, so the server needs internet access during
install. Check the server can reach the internet and re-run `sudo bash install.sh`. If your
server can't reach GitHub, you can download the matching `regctl` binary manually from
`https://github.com/regclient/regclient/releases`, place it at `/usr/local/bin/regctl`, make
it executable (`chmod +x /usr/local/bin/regctl`), then re-run the installer.

**The installer complains about `docker`**
The plugin needs Docker installed and reachable as root — it uses it to list your running
containers and read their local image digests. If Docker isn't set up on this server yet,
set that up first, then re-run `sudo bash install.sh`.

**`omv-imagecheck --print` shows errors on some containers**
That's usually fine. Containers built locally or pinned to an exact digest have nothing to
compare against, and a private registry needs the host to be logged in (`docker login`).
Those show as per-item notes and are **not** counted as false "updates."

---

## Optional (advanced): download using GitHub over SSH

You don't need this — the public HTTPS download in Step 5 is simpler and works for everyone.
Use this **only** if you already have SSH keys set up with your GitHub account. In that case,
replace the Step 5 clone command with:

```bash
git clone git@github.com:hackitz/openmediavault-imagecheck.git
```

Everything else in the guide is exactly the same.
