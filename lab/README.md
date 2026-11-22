# Local RouterOS test lab

MikroTik RouterOS CHR with a Mailpit inbox, for developing and testing `BackupAndUpdate.rsc`.
RouterOS starts with `/tool e-mail` already sending to Mailpit and its log stored on disk, so the
log survives reboots.

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

`make ssh` opens a RouterOS terminal. Type `/quit` or press Ctrl+D to leave it.

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

Add the script from this repository through the REST API (needs `jq` and `curl`). The `sed`
keeps lab runs out of the script's usage statistics.

```sh
sed 's/^:local anonStats true/:local anonStats false/' ../BackupAndUpdate.rsc \
  | jq -Rs '{name: "BackupAndUpdate", source: .}' \
  | curl -sS -u admin:admin -X PUT -H 'content-type: application/json' --data-binary @- \
    http://127.0.0.1:12280/rest/system/script | jq 'del(.source)'
```

To load an edited version, run the same command with `{source: .}`, `-X PATCH` and the URL
`http://127.0.0.1:12280/rest/system/script/BackupAndUpdate`.

Run it and read the log:

```sh
make ros CMD='/system script run BackupAndUpdate'
make ros CMD='/log print where message~"^Bkp&Upd"'   # lines from the script
make ros CMD='/log print'                           # everything RouterOS logged
```

The full log also shows events the script does not log itself, such as e-mail errors, package
installs and reboots. Each script upload adds a copy of the script source to it.

Errors in a run started with `make ros` print to its output and end with `(:error; line N)` or
`(line N column M)`. The line numbers match the `.rsc` file.

Mailpit accepts any recipient, so the script's default `emailAddress` works. Read mail through the
Mailpit API:

```sh
curl -s http://127.0.0.1:8025/api/v1/messages | jq                    # list messages
curl -s http://127.0.0.1:8025/api/v1/message/<ID> | jq .Attachments   # attachments and PartID
curl -s http://127.0.0.1:8025/api/v1/message/<ID>/part/<PartID>       # one attachment
curl -s -X DELETE http://127.0.0.1:8025/api/v1/messages               # empty the inbox
```

If the script reboots RouterOS, for example to install an update, `make ros` waits until RouterOS
is back.
