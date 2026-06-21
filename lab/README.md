# Local RouterOS test lab

This lab runs MikroTik RouterOS CHR for development and manual tests.

## Start the lab

```sh
make start
make state
```

RouterOS can take up to two minutes to accept SSH connections on its first boot.
The `routeros-init` container retries during that period and exits after it applies the mail settings.

## Access

| Service | Address |
| --- | --- |
| Mailpit web interface | <http://localhost:8025> |
| RouterOS WebFig | <http://localhost:12280> |
| RouterOS WinBox | `localhost:18291` |
| RouterOS SSH | `localhost:12222` |
| RouterOS Telnet | `localhost:12223` |
| RouterOS API | `localhost:18728` |
| RouterOS API over TLS | `localhost:18729` |

!! Use the RouterOS user `admin` with an empty password. Use this account inside the isolated lab.

## Mailpit and ping

Expect `ping mailpit` from RouterOS to time out. Docker DNS still resolves the `mailpit` name, and SMTP traffic can reach port `1025`.
The Docker and QEMU network path does not provide a useful ICMP health check for this service.

Test SMTP from a RouterOS terminal:

```routeros
/tool e-mail send to="lab@example.test" subject="lab test" body="mail works"
```

Open <http://localhost:8025> and check that Mailpit received the message. Use message delivery as the health check for this lab.

## Usage

```routeros
/system script run BackupAndUpdate
```

Follow the script log while it runs:
```routeros
/log print follow where message~"Bkp&Upd"
```
