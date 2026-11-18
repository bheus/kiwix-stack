#!/bin/sh
set -u

MIRROR=https://mirror.accum.se/mirror/kiwix.org/zim/wikipedia
CHECKSUMS=https://download.kiwix.org/zim/wikipedia
PREFIX=wikipedia_en_all_maxi_
DATA=/data
INCOMING=$DATA/incoming
MIN_FREE_GB=160

log() { echo "$(date -u +%FT%TZ) update-zim: $*"; }

email() {
  [ -r /run/secrets/email.env ] || { log "no email creds, skipping mail"; return; }
  . /run/secrets/email.env
  body=$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')
  from=$(printf '%s' "$FROM_EMAIL" | sed 's/"/\\"/g')
  wget -q -O /dev/null \
    --header "Authorization: Bearer $RESEND_API_KEY" \
    --header "Content-Type: application/json" \
    --post-data "{\"from\":\"$from\",\"to\":[\"$EMAIL_RECIPIENT\"],\"subject\":\"$1\",\"text\":\"$body\"}" \
    https://api.resend.com/emails || log "email send failed"
}

fail() { log "FAILED: $1"; email "Kiwix update failed" "$1"; exit 1; }

if [ "${1:-}" = "--test-email" ]; then
  email "Kiwix updater test" "Email path from kiwix-updater works."
  exit 0
fi

latest=$(wget -qO- "$MIRROR/" | grep -o "${PREFIX}[0-9-]*\.zim\"" | tr -d '"' | sort -u | tail -1)
[ -n "$latest" ] || fail "could not list $MIRROR"
current=$(cd "$DATA" && ls ${PREFIX}*.zim 2>/dev/null | sort | tail -1)

if [ "$latest" = "$current" ]; then
  log "up to date ($current)"
  exit 0
fi

mkdir -p "$INCOMING"
cd "$INCOMING" || fail "no $INCOMING"
for f in ${PREFIX}*.zim; do
  [ -e "$f" ] && [ "$f" != "$latest" ] && rm -f "$f"
done

free_gb=$(df -P "$DATA" | awk 'NR==2 {print int($4/1048576)}')
[ "$free_gb" -ge "$MIN_FREE_GB" ] || fail "only ${free_gb} GB free, need ${MIN_FREE_GB} GB for $latest"

log "downloading $latest (replacing ${current:-nothing})"
wget -c -q -O "$latest" "$MIRROR/$latest" || fail "download of $latest failed; partial kept in incoming/ for resume"

expected=$(wget -qO- "$CHECKSUMS/$latest.sha256" | cut -d' ' -f1)
actual=$(sha256sum "$latest" | cut -d' ' -f1)
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
  rm -f "$latest"
  fail "checksum mismatch for $latest (expected '${expected}', got '$actual'); file deleted"
fi

mv "$latest" "$DATA/"
cd "$DATA" || exit 1

rm -f library.xml.new
for f in *.zim; do
  case "$f" in ${PREFIX}*) [ "$f" = "$latest" ] || continue ;; esac
  kiwix-manage library.xml.new add "$DATA/$f" || fail "kiwix-manage could not add $f"
done
mv library.xml.new library.xml

# Give kiwix-serve time to reload the library before the old file disappears.
sleep 120
[ -n "$current" ] && rm -f "$DATA/$current"

log "updated $current -> $latest"
email "Kiwix updated to $latest" "Offline Wikipedia on apple-pi now serves $latest (was ${current:-none}). Free space: $(df -h "$DATA" | awk 'NR==2 {print $4}')."
