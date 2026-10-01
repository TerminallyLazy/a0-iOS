# Computer setup

The themed Computer sheet links to shared setup guidance. Launcher owns
installation, normal sign-in, access choices and OS permissions. Core provides
versioned help and readiness to Launcher, WebUI and iOS; TipKit adds optional
local feature guidance. Setup works without a chat or configured model provider.

`ComputerSetup.swift` validates bounded `host_setup_v1` responses using the
authenticated same-origin transport without mutation retries. Continuation
requests use a dedicated protected journal, separate from uncertain host input.
Reconnect reads requests by ID; it never replays them. A ten-minute code grants
no access. Confirming a computer still requires separate local review in Launcher.
Forgetting a code cannot clear a host hold or resume A0.

Foreground polling is profile/lifecycle fenced. Unsupported servers preserve
chat and local Launcher setup. Multiple connected hosts fail closed. Prepared
and recently Tested are distinct; computer evidence covers capture only.

`ComputerSetupTests` covers response bounds, authenticated chat-independent
reads and no-retry rejection. `ComputerSetupUITests` uses a DEBUG-only server
and isolated receipt journal, not a real permission grant or host input test.

## Beta compatibility

The mobile build alone cannot add host control to an older server. Core must
advertise `host_tasks_v1`, `host_viewer_v1` and `host_setup_v1`; the connector
must advertise its matching viewer and setup verification features. Launcher
owns local setup and permissions. These coordinated changes are initially
source/beta integrations; do not imply they ship in upstream Launcher 1.8 or
connector 2.13. Older installations retain chat and historical captures with
unavailable controls disabled. The tested desktop is macOS; Windows/Linux
native permission and installer acceptance remains pending.

Rollback the iOS beta independently. Do not delete durable host holds to roll
back a server/connector: explicitly Return to A0 first, or retain the hold and
repair the compatible host connection. Downgrading does not replay input.
