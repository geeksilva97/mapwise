# MapWise

Multi-tenant SaaS map creation platform built on Rails 8. Users create custom maps with markers, groups, layers, and styles, then embed them via iframe or track vehicles in real time.

## Quick Start

```bash
bin/dev          # Full stack: Puma + Tailwind watcher + Solid Queue worker
bin/rails test   # 507 tests, 1297 assertions
```

The Solid Queue worker (`bin/jobs`) is **required** for AI chat, CSV import, geocoding, and deviation checks. `bin/dev` starts it automatically.

## Stack

- **Backend**: Rails 8.1.2, SQLite, Solid Queue/Cache/Cable, Propshaft, Importmap
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS, Google Maps JS API
- **AI**: RubyLLM gem (multi-provider: Anthropic, OpenAI, Gemini) — model via `ENV["RUBY_LLM_MODEL"]`
- **Deployment**: Kamal 2 → GCP Compute Engine (IP in `.kamal/secrets`)
- **Dev email**: `letter_opener_web` at `/letter_opener`

## Architecture Rules

### Service Layer

Controllers never talk to the database directly. All ActiveRecord operations go through namespaced `.call` service classes.

```ruby
# Pattern:
@marker = Markers::Create.call(@map, marker_params)
```

**Namespaces**: `Maps::`, `Markers::`, `MarkerGroups::`, `Layers::`, `Tracking::`, `Chat::`, `ApiKeys::`, `MapStyles::`, `Imports::`, `EmailVerifications::`

**Exceptions** (allowed to skip services): Auth controllers (Sessions, Passwords, Registrations), `SettingsController#update`, `ImportsController#set_import`.

### Zeitwerk Namespacing

When referencing a top-level constant inside a namespaced service, use the `::` prefix:

```ruby
# Inside Tracking::FindVehicleByToken
::TrackedVehicle.find_by(webhook_token: token)  # correct
TrackedVehicle.find_by(webhook_token: token)     # wrong — Zeitwerk resolves to Tracking::TrackedVehicle
```

### Google Maps Dual-Mode Rendering

With `google_map_id` → sets `mapId` → `AdvancedMarkerElement` + cloud styling.
Without → no `mapId` → legacy `Marker` with SVG pin icons + JSON `styles`.

These modes are mutually exclusive. Never use a hardcoded fallback `mapId` like `"DEMO_MAP_ID"`.

### Cross-Controller Communication

Stimulus controllers can't reach siblings directly. Use shared helpers from `app/javascript/utils/controllers.js`:

```javascript
import { findMapController, findDrawingController, findTrackingController } from "utils/controllers"
```

### Error Handling (JS)

All controllers use `showError()` from `app/javascript/utils/flash.js` — red toast, bottom-right, 3s auto-dismiss.

## Project Structure

### Layouts
- `application.html.erb` — navbar + container (dashboard, settings, etc.)
- `fullscreen.html.erb` — zero-padding (editor, viewer, tracking)
- `embed.html.erb` — minimal for iframes

### Key Files

| Area | Files |
|------|-------|
| **Map editor** | `app/views/maps/edit.html.erb`, `app/javascript/controllers/map_controller.js` |
| **Marker CRUD** | `app/javascript/controllers/marker_editor_controller.js`, `app/services/markers/` |
| **Groups** | `app/javascript/controllers/group_controller.js`, `app/services/marker_groups/` |
| **Layers** | `app/javascript/controllers/drawing_controller.js`, `app/services/layers/` |
| **Import** | `app/javascript/controllers/import_controller.js`, `import_dialog_controller.js`, `app/services/imports/` |
| **Tracking** | `app/javascript/controllers/tracking_controller.js`, `playback_controller.js`, `app/services/tracking/` |
| **Vehicles** | `app/javascript/controllers/vehicle_editor_controller.js`, `vehicle_item_controller.js` |
| **AI Chat** | `app/javascript/controllers/chat_controller.js`, `app/services/ai_chat_service.rb`, `app/services/ai_tools/` |
| **Shared JS utils** | `app/javascript/utils/controllers.js`, `flash.js`, `csrf.js`, `http.js` |

### Editor Sidebar Tabs

4 tabs: **Markers | Settings | Tracking | AI**

## Testing

```bash
bin/rails test                    # all tests
bin/rails test test/controllers/  # controller tests only
bin/rails test test/models/       # model tests only
```

- **Helper**: `sign_in_as(user)` from `test/test_helpers/session_test_helper.rb`
- **Fixtures**: 2 users, 5 maps, 3 markers, 2 api_keys, 4 map_styles, 3 marker_groups, 3 layers, 4 tracked_vehicles, 3 tracking_points, 2 deviation_alerts, 3 chat_messages
- **404 testing**: `show_exceptions: :rescuable` in test env → `assert_response :not_found`
- **AR Encryption**: Fixtures bypass encryption; `support_unencrypted_data = true` in test config
- **Passwords**: Min 8 chars — use long passwords in test fixtures
- **Stubbing**: `minitest/mock` (`Object#stub`) not available in minitest 6.0.1/Ruby 3.4 — use manual method overrides

## Common Gotchas

- `Current.user.api_keys.build(...)` adds unsaved record to association → use `.reload` when re-rendering after failed save
- `tag` helper not available in controllers → use `helpers.tag` instead
- Turbo Stream `html:` param escapes HTML → use block form with `helpers.tag.p(...)`
- Google Maps script loaded via `<script>` in HTML layouts (not dynamic JS injection)
- Terra Draw crashes in readonly mode → skip `initTerraDraw()`, render via Google Maps Data layer
- `CSV.open(path, headers: true).headers` returns `true` → use `CSV.read(path, headers: true).headers`
- Placement mode is persistent (multi-marker) — user must click Cancel to exit
- RubyLLM tool names include module prefix (e.g. `ai_tools--create_marker`) → override `def name` in each tool
- RubyLLM `param` DSL: `desc:` (not `description:`), `type:`, `required:`
- RubyLLM has no built-in max tool iterations → implement guard via `on_tool_call` callback

## Deployment

```bash
bin/kamal deploy    # Deploy to GCP (requires Docker Desktop + gcloud auth)
bin/kamal logs      # View production logs
bin/kamal console   # Rails console on production
bin/kamal shell     # SSH into container
```

- **Host**: GCP `e2-small` (Ubuntu 24.04) — IP set via `DEPLOY_HOST` in `.kamal/secrets`
- **Registry**: `us-central1-docker.pkg.dev/edy-ai-playground/mapwise`
- **Solid Queue**: runs in-process via `SOLID_QUEUE_IN_PUMA=true`
- **Storage**: Docker volume `mapwise_storage:/rails/storage` (SQLite DB + Active Storage)

## Credentials

Stored in `config/credentials.yml.enc`:

```yaml
google_maps_api_key: REQUIRED     # Powers all maps
anthropic_api_key: FOR_AI_CHAT    # At least one LLM key needed
openai_api_key: OPTIONAL
gemini_api_key: OPTIONAL
```

## Skills (Slash Commands)

- `/deploy` — Run tests, check git status, deploy to GCP via Kamal
- `/simulate-tracking` — Run GPS tracking simulator against a vehicle webhook
