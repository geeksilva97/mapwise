---
name: simulate-tracking
description: Run the GPS tracking simulator to demo vehicle movement on the live tracking page
disable-model-invocation: false
---

Run the MapWise tracking simulator (`bin/simulate_tracking`) to send GPS points to a vehicle's webhook endpoint.

## Prerequisites
- The Rails server must be running (`bin/dev` or `bin/rails server`)
- A tracked vehicle must exist on a map with tracking enabled and toggled active

## Steps

1. If no webhook token was provided as an argument, ask the user for it. The token is in the editor's Tracking tab — each vehicle shows a webhook URL like `/webhooks/tracking/<TOKEN>`.
2. Ask which **route** to simulate (default: `nyc_taxi`):
   - `nyc_taxi` — Cab through Manhattan: Times Square → Central Park → Upper East Side → East Village
   - `highway_drive` — I-95 NJ/NY stretch at highway speeds
   - `delivery_route` — Local neighborhood delivery loop with stops (Brooklyn)
3. Run the simulator in the background so the user can continue working:
   ```
   bin/simulate_tracking <TOKEN> --route <ROUTE> --interval 2
   ```
4. Tell the user to open the map's tracking page to watch the vehicle move in real time.

## Options
- `--route ROUTE` — Route to simulate (default: nyc_taxi)
- `--interval SECS` — Seconds between points (default: 2)
- `--loop` — Loop the route continuously
- `--host HOST` — Target host:port (default: localhost:3000)
- `--https` — Use HTTPS instead of HTTP

## Common errors
- **404**: Vehicle not found — webhook token is wrong
- **410**: Vehicle is inactive — enable tracking for the vehicle in the editor first
- **Connection refused**: Rails server is not running
