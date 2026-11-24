# Local RouterOS test lab

MikroTik RouterOS v7 and v6 CHR with a shared Mailpit inbox, for developing and testing
`BackupAndUpdate.rsc`. Both routers start with `/tool e-mail` already sending to Mailpit and their log
stored on disk, so the log survives reboots.

## Start the lab

```sh
make up
```

`make up` returns when both routers are configured. `make help` lists the other targets.

The lab keeps no state. Run `make down up` to get fresh, configured routers.

## Access

| Service | RouterOS v7 | RouterOS v6 |
| --- | --- | --- |
| SSH | `127.0.0.1:17022` | `127.0.0.1:16022` |
| WebFig | <http://127.0.0.1:17080> (also REST API) | <http://127.0.0.1:16080> |
| WinBox | `127.0.0.1:17291` | `127.0.0.1:16291` |

RouterOS user `admin`, password `admin`. Mailpit web interface: <http://127.0.0.1:8025>.

The `make` targets below act on v7. Add `V=6` for v6.

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

Load the script from this repository, with `anonStats` turned off so lab runs stay out of the
script's usage statistics. It replaces any loaded copy, so run it again after each edit.

```sh
make script
```

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

To test the upgrade from v6 to v7, set `updateChannel` to `"testing"` in `BackupAndUpdate.rsc`. On v6
the `stable` and `long-term` channels only offer v6 releases. Then:

```sh
make script V=6
make ros V=6 CMD='/system script run BackupAndUpdate'
```

The router installs v7, reboots and a few minutes later sends an "Update completed" mail to Mailpit.

Mailpit accepts any recipient, so the script's default `emailAddress` works. Read mail through the
Mailpit API:

```sh
curl -s http://127.0.0.1:8025/api/v1/messages | jq                    # list messages
curl -s http://127.0.0.1:8025/api/v1/message/<ID> | jq .Attachments   # attachments and PartID
curl -s http://127.0.0.1:8025/api/v1/message/<ID>/part/<PartID>       # one attachment
curl -s -X DELETE http://127.0.0.1:8025/api/v1/messages               # empty the inbox
```

If the script reboots RouterOS, for example to install an update, `make ros` ends with
`Received disconnect ... shutdown/reboot` and make reports `Error 255`. A command sent while RouterOS
is rebooting waits until it is back.
