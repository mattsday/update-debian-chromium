# Chromium Updater

This script is for lame company policies that remove Chromium from the Debian package repo and don't let you install it yourself.

Maybe you don't like Firefox and use Chrome for business use (and don't want to mess around with profiles). Maybe you have other reasons.

In any case, this checks the Debian security repo for new Chromium fixes, downloads the deb packages and installs them - and then grossly removes all trace of the installation from `/var/lib/dpkg/status`.

It's shady, it's hacky and it's effective.

## Use

Run the script as root (it needs root to install Chromium and also to modify the dpkg status)

## Problems

It tries to back out if things go wrong, but ymmv. It could break your system! The dpkg status files are backed up in /var/lib/dpkg - maybe you can recover your system with those backups?

It also uses /tmp and you'll find useful things there perhaps... I don't know!
