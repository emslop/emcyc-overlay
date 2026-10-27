# emcyc-overlay

Personal Gentoo overlay.

## Adding the repository

### eselect

```sh
eselect repository enable emcyc
emerge --sync emcyc
```

### repos.conf

Create `/etc/portage/repos.conf/emcyc.conf`:

```ini
[emcyc]
location = /var/db/repos/emcyc
sync-type = git
sync-uri = https://github.com/emslop/emcyc-overlay.git
priority = 50
```

Then run:

```sh
emerge --sync emcyc
```
