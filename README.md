# Chromium Updater

**Deprecated: I have deprecated this project as I am able to use [snap](https://snapcraft.io/chromium) to keep a maintained and working Chromium installation on my system**

This script is for lame company policies that remove Chromium from the Debian package repo and don't let you install it yourself.

Maybe you don't like Firefox and use Chrome for business use (and don't want to mess around with profiles). Maybe you have other reasons.

In any case, this checks the Debian security repo for new Chromium fixes, downloads the deb packages and installs them - and then grossly removes all trace of the installation from `/var/lib/dpkg/status`.

It's shady, it's hacky and it's effective.

The script has been hacked together over time. Refactored PRs to tidy it up would be greatly appreciated (e.g. put the packages in an array and download/install them from that)

## Use

Run the script as root (it needs root to install Chromium and also to modify the dpkg status)

## Problems

At each stage there is a test to help ensure this script will back out if things are going wrong. That's not to say it's perfect and it could leave a trace of chromium in your dpkg status, fail to install chromium properly or break your system!

Backup files are kept, specifically:

1. Your original `/var/lib/dpkg/status` file is backed up as `/tmp/status-restore-chromium-VERSION` - copying this (or diffing it) might help
2. The patch applied is stored as `/tmp/status-chromium-VERSION.patch` and might help recover things
3. The post-installation (including all the Chromium bits) status is backed up as `/tmp/status-backup-chromium-VERSION`

If Chromium is installing OK but then disappearing from your system it likely means there's a trace of it in your dpkg status.

Run this:

```
apt remove chromium chromium-sandbox chromium-l10n chromium-driver
```

Once this has complete, run your org's update application and reboot. Then try this script again.
