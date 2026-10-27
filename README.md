# emcyc-overlay

Electromagnetic overlay with AI slop ebuilds. Packages on the branch `main` are tested and working.

## Adding the repository

### eselect

```sh
eselect repository add emcyc-overlay git https://github.com/emslop/emcyc-overlay.git
```

### repos.conf

Create `/etc/portage/repos.conf/emcyc-overlay.conf`:

```ini
[emcyc-overlay]
location = /var/db/repos/emcyc-overlay
sync-type = git
sync-uri = https://github.com/emslop/emcyc-overlay.git
sync-branch = main
```

## Syncing the repository

```sh
emerge --sync emcyc
```
