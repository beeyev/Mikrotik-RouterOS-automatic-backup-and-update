# Local RouterOS test lab

MikroTik RouterOS CHR with a Mailpit inbox, for developing and testing `BackupAndUpdate.rsc`.
RouterOS starts with `/tool e-mail` already sending to Mailpit.

## Start the lab

```sh
make up
```

`make up` returns when RouterOS is configured. `make help` lists the other targets.

The lab keeps no state. Run `make down up` to get a fresh, configured RouterOS.

## Access

| Service | Address |
| --- | --- |
| Mailpit web interface | <http://127.0.0.1:8025> |
| RouterOS WebFig and REST API | <http://127.0.0.1:12280> |
| RouterOS SSH | `127.0.0.1:12222` |
| RouterOS WinBox | `127.0.0.1:18291` |

RouterOS user `admin`, password `admin`.

Run a RouterOS command without an SSH client:

```sh
make ros CMD='/system resource print'
```

RouterOS returns exit status 0 over SSH even when a command fails, so read the output.

Send a test message and check that it shows up in Mailpit:

```sh
make ros CMD='/tool e-mail send to="lab@example.test" subject="lab test" body="mail works"'
```

## Test the script

Add the script from this repository through the REST API (needs `jq` and `curl`):

```sh
jq -Rs '{name: "BackupAndUpdate", source: .}' ../BackupAndUpdate.rsc \
  | curl -fsS -u admin:admin -X PUT -H 'content-type: application/json' --data-binary @- \
    http://127.0.0.1:12280/rest/system/script
```

To load an edited version, remove the old one first with
`make ros CMD='/system script remove BackupAndUpdate'`.

Run it and read its log:

```sh
make ros CMD='/system script run BackupAndUpdate'
make ros CMD='/log print where message~"Bkp&Upd"'
```

Mailpit accepts any recipient, so the script's default `emailAddress` works. Check the result at
<http://127.0.0.1:8025>.

With the default `scriptMode` of `osupdate`, the script upgrades RouterOS to the latest stable
release and reboots it. `make ros` fails until RouterOS is back.
