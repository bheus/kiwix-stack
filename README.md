# kiwix-stack

Offline Wikipedia (`kiwix-serve`) on apple-pi at http://wiki.svc.lan.
Portainer GitOps stack with relative paths enabled (`update-zim.sh` is bind-mounted from the repo).

ZIM files live on the host in `/srv/kiwix/`, not in this repo. `kiwix-serve` reads
`/srv/kiwix/library.xml` and reloads it when it changes, so swapping ZIMs needs no restart.

`kiwix-updater` runs `update-zim.sh` quarterly (1 Jan/Apr/Jul/Oct, 10:00 UTC): it
downloads the newest `wikipedia_en_all_maxi` from mirror.accum.se into `incoming/`,
verifies the SHA-256, swaps it into `library.xml`, deletes the old ZIM, and emails
the result via Resend. Quarterly rather than monthly to limit NVMe writes.

Run it by hand: `docker exec kiwix-updater /scripts/update-zim.sh`
Test email: `docker exec kiwix-updater /scripts/update-zim.sh --test-email`
