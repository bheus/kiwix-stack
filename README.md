# kiwix-stack

Offline Wikipedia (`kiwix-serve`) on apple-pi at http://wiki.svc.lan.
Deployed as a Portainer GitOps stack.

ZIM files live on the host in `/srv/kiwix/`, not in this repo. Download into
`/srv/kiwix/incoming/`, move the finished file up a level, remove the old one,
then restart the container. Releases: https://download.kiwix.org/zim/wikipedia/
