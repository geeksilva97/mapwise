# MapWise — Implementation Plan

## Context

MapWise is a multi-tenant SaaS map creation platform inspired by Google My Maps and Atlist. Users create custom maps with markers, styles, and layers, then embed them via iframe. Built on Rails 8 with Hotwire, Tailwind, SQLite, and Google Maps JavaScript API.

**Key decisions**: Rails 8 built-in auth, dual API key model (platform + customer), Google Maps only, phased delivery.

**API key model**:
- **MapWise platform key**: Stored in `config/credentials.yml.enc`. Powers all maps inside the app (editor, viewer, dashboard). Users never need to provide a key to use MapWise.
- **Customer API key** (optional): Required only for embedding public maps on external sites. If a customer hasn't added their key, embedding is disabled but everything inside MapWise still works.

**Map visibility**:
- **Private maps**: Viewable only inside MapWise (requires authentication). Dedicated read-only viewer page at `/maps/:id`.
- **Public maps**: Also viewable inside MapWise, plus embeddable via iframe on external sites (requires customer API key).

**Important API notes discovered during research**:
- `google.maps.Marker` is deprecated — use `AdvancedMarkerElement` when `mapId` is available
- Google Maps JSON styling is incompatible with `mapId` — dual-mode: `AdvancedMarkerElement` + cloud styling when `google_map_id` is set, legacy `Marker` + JSON styles otherwise
- Google Maps Drawing Library is deprecated — use [Terra Draw](https://github.com/JamesLMilner/terra-draw) for shapes (Phase 2)

---

## Data Model (Full Schema)

```
User (auth generator + name)
 ├── Session (auth generator)
 ├── ApiKey (encrypted google_maps_key, label) — optional, for embedding only
 ├── MapStyle (name, style_json, system_default — null user_id = preset)
 └── Map (title, description, center_lat/lng, zoom, map_type, embed_token, public, style_json, google_map_id)
      ├── Marker (lat, lng, title, description, color, icon, position, marker_group_id, custom_info_html, extra_data)
      ├── MarkerGroup (name, color, icon, visible, position) — Phase 2
      ├── Layer (name, layer_type, geometry_data JSON, stroke/fill styles, visible, position) — Phase 2
      └── TrackingConfig (webhook_token, planned_path JSON, deviation_threshold, alert_email) — Phase 4
           └── TrackingPoint (lat, lng, recorded_at, metadata JSON, deviated) — Phase 4
```

- Geometry stored as JSON text (SQLite has no spatial types)
- Embed tokens: `SecureRandom.urlsafe_base64(16)`, indexed unique
- API keys encrypted via `ActiveRecord::Encryption` (built into Rails 8)

---

## UI Architecture

- **Three layouts**: `application.html.erb` (navbar + container), `fullscreen.html.erb` (zero-padding for editor/viewer), `embed.html.erb` (minimal for iframes)
- **Shared partials**: `shared/_navbar.html.erb` (responsive nav with logo, links, user menu, mobile hamburger), `shared/_flash.html.erb` (flash messages with SVG icons)
- **Auth pages**: Sign in and sign up hide the navbar via `content_for :hide_navbar` for a clean centered card design
- **Stimulus controllers**: `navbar_controller.js` (mobile menu toggle), plus existing map/tabs/marker-editor/style-picker controllers
- **Editor settings**: Inline save via Turbo Stream — no page refresh, stays on current tab
- **Style picker**: Select dropdown (was buttons), uses Stimulus `application.getControllerForElementAndIdentifier` to communicate with the map controller on a sibling element
- **Design tokens**: Cards use `bg-white rounded-xl border border-gray-200 shadow-sm`, inputs use `rounded-lg border-gray-300 bg-gray-50` with blue focus ring, page background `bg-gray-50`

## Starting the Application

```bash
# Full stack (recommended) — runs Puma, Tailwind watcher, and Solid Queue worker:
bin/dev

# Or manually in separate terminals:
bin/rails server   # web server
bin/jobs            # Solid Queue worker (required for AI chat, CSV import, geocoding, deviation checks)
```

`Procfile.dev` defines three processes: `web`, `css`, `jobs`. The Solid Queue worker (`bin/jobs`) is **required** — without it, background jobs (AI chat, CSV import, geocoding, deviation checks) will be enqueued but never executed.

---

## Architecture

- **Google Maps loading**: Script tag injected by Stimulus controller; API key passed via `data-` attribute
- **API key resolution**:
  - Inside MapWise (editor, viewer, dashboard): always use platform key from `Rails.application.credentials.google_maps_api_key`
  - Embed endpoint: use the map owner's customer-provided API key; if none exists, show "embedding not configured" message
- **Editor layout**: Split-view — 320px sidebar (Turbo Frames for panels) + map canvas (Stimulus)
- **Marker sync**: Turbo Stream responses update sidebar DOM; map controller re-reads marker data from a JSON script tag and re-renders
- **Map state persistence**: `idle` event on map → debounced PATCH to save center/zoom
- **Map viewer**: Dedicated read-only page at `/maps/:id` for viewing maps inside MapWise (private or public). Clean layout, no editing controls.
- **Embed**: Separate controller + minimal layout at `/embed/:token`, no auth, uses customer's API key. Only works for public maps with a configured customer key.
- **Background jobs**: Solid Queue (Rails 8 default) for CSV import, geocoding, deviation checks
- **Real-time tracking** (Phase 4): Action Cable + Solid Cable → Turbo Streams

---

## Phase 1 — Core (Build First)

### Step 1: Rails 8 app scaffold
```bash
rails new mapwise --css tailwind --database sqlite3
```
- Configure Active Record Encryption keys (`bin/rails db:encryption:init`)
- Verify Solid Queue, Solid Cable, Solid Cache in Gemfile

### Step 2: Authentication
- `bin/rails generate authentication` → generates User, Session, Current, login/password reset
- Add custom `RegistrationsController` (sign-up flow — the generator doesn't include it)
- Add `name` column to users

**Files**: `app/controllers/registrations_controller.rb`, `app/views/registrations/new.html.erb`

**Tests**:
- *Unit* (`test/models/user_test.rb`): validates presence of email_address and name, validates uniqueness of email_address, validates password length
- *Integration* (`test/controllers/registrations_controller_test.rb`): GET new renders sign-up form, POST create with valid params creates user + starts session + redirects, POST create with invalid params re-renders form with errors
- *Integration* (`test/controllers/sessions_controller_test.rb`): POST create with valid credentials logs in, POST create with invalid credentials re-renders with error, DELETE destroy logs out
- *Integration*: unauthenticated users are redirected to login

### Step 3: API key management
- Store MapWise platform key in `config/credentials.yml.enc` under `google_maps_api_key`
- `ApiKey` model with `encrypts :google_maps_key` — for customer keys (optional, needed for embedding)
- Settings page to add/update/remove customer keys
- Helper method `platform_api_key` to resolve the platform key for editor/viewer usage
- No guard — users can use MapWise immediately without providing a key

**Files**: `app/models/api_key.rb`, `app/controllers/api_keys_controller.rb`, `app/views/api_keys/`

**Tests**:
- *Unit* (`test/models/api_key_test.rb`): validates presence of google_maps_key, encrypts/decrypts key correctly, belongs_to user
- *Integration* (`test/controllers/api_keys_controller_test.rb`): GET index lists user's keys, POST create saves encrypted key, PATCH update changes key, DELETE destroy removes key, all actions require authentication, user cannot see other user's keys

### Step 4: Map CRUD
- Map model with embed token generation (`before_create`)
- Standard CRUD controller scoped to `Current.user`
- `new` → set defaults (center of US, zoom 4); `create` → redirect to editor
- `show` → dedicated read-only viewer page (works for both private and public maps; private requires auth)
- `edit` → the full editor (always requires auth + ownership)

**Files**: `app/models/map.rb`, `app/controllers/maps_controller.rb`, `app/views/maps/` (including `show.html.erb` as viewer)

**Tests**:
- *Unit* (`test/models/map_test.rb`): validates presence of title, generates embed_token on create, embed_token is unique, belongs_to user, has_many markers (dependent destroy), default values for center_lat/lng/zoom
- *Integration* (`test/controllers/maps_controller_test.rb`): GET new renders form, POST create saves map + redirects to edit, GET edit renders editor (auth + ownership required), GET show renders viewer, PATCH update saves changes (HTML and JSON), DELETE destroy removes map + redirects to dashboard, user cannot access other user's maps (RecordNotFound), all actions require authentication

### Step 5: Map editor UI
- Split-view: sidebar with tabs (Markers / Styles) + full-height map canvas
- Tailwind for layout (`flex h-screen`, `w-80 border-r`, `flex-1`)
- Sidebar tabs via a small Stimulus `tabs_controller.js`

**Files**: `app/views/maps/edit.html.erb`, `app/javascript/controllers/tabs_controller.js`

### Step 6: Google Maps Stimulus controller
- `map_controller.js` — loads Google Maps API via script tag, initializes map, renders markers
- Uses `AdvancedMarkerElement` with `gmpDraggable: true`
- Persists center/zoom on `idle` event (1s debounce → PATCH)
- Dispatches/listens for custom events to sync with Turbo

**File**: `app/javascript/controllers/map_controller.js`

### Step 7: Marker CRUD
- Nested resource under maps (`/maps/:map_id/markers`)
- "Add Marker" enters placement mode → click map → POST with lat/lng
- Turbo Stream responses: append/update/remove sidebar items + update markers JSON
- Drag-end → PATCH position
- Edit form loads in a Turbo Frame

**Files**: `app/models/marker.rb`, `app/controllers/markers_controller.rb`, `app/views/markers/` (partials + turbo streams)

**Tests**:
- *Unit* (`test/models/marker_test.rb`): validates presence of lat and lng, belongs_to map, default color value, position defaults to 0
- *Integration* (`test/controllers/markers_controller_test.rb`): POST create with valid lat/lng creates marker (turbo_stream + json), POST create with missing lat/lng returns error, PATCH update changes marker attributes, PATCH update via JSON updates position (drag-end), DELETE destroy removes marker, markers are scoped to parent map, user cannot CRUD markers on other user's maps

### Step 8: Basic map styling
- `MapStyle` model — seed 6-8 presets (Default, Silver, Night, Retro, Aubergine, Minimal)
- Style picker panel in sidebar with visual previews
- Click applies style instantly (Stimulus) + saves (PATCH)
- Support both `style_json` (legacy) and `google_map_id` (cloud-based)

**Files**: `app/models/map_style.rb`, `app/controllers/map_styles_controller.rb`, `app/views/map_styles/_picker.html.erb`, `db/seeds.rb`

**Tests**:
- *Unit* (`test/models/map_style_test.rb`): validates presence of name and style_json, system_default scope, user-owned vs system presets
- *Integration* (`test/controllers/map_styles_controller_test.rb`): GET index returns system presets + user styles, POST create saves user style, DELETE destroy removes user style, user cannot delete system presets, user cannot delete other user's styles

### Step 9: Iframe embed
- `EmbedsController` — `skip_before_action :require_authentication`
- Only serves **public** maps; returns 404 for private maps
- Uses the map owner's **customer API key** (not the platform key)
- If owner has no customer key → render a friendly "embedding not configured" message with setup instructions
- Minimal layout (`embed.html.erb`) — no nav/footer, just the map
- Read-only mode (`data-map-readonly-value="true"`)
- Share dialog in editor: copyable iframe code + direct link + public/private toggle + prompt to add API key if missing

**Files**: `app/controllers/embeds_controller.rb`, `app/views/layouts/embed.html.erb`, `app/views/embeds/show.html.erb`

**Tests**:
- *Integration* (`test/controllers/embeds_controller_test.rb`): GET with valid token for public map + customer key renders map, GET with valid token for private map returns 404, GET with invalid token returns 404, GET with valid token but no customer key renders "not configured" message, does NOT require authentication (skip_before_action)

### Step 10: Dashboard
- Grid of map cards (title, description, marker count, timestamps)
- Ordered by `updated_at desc`

**Files**: `app/controllers/dashboard_controller.rb`, `app/views/dashboard/index.html.erb`, `app/views/maps/_map_card.html.erb`

**Tests**:
- *Integration* (`test/controllers/dashboard_controller_test.rb`): GET index requires authentication, GET index shows only current user's maps, maps are ordered by updated_at desc

### Routes (Phase 1)
```ruby
resource :session, only: [:new, :create, :destroy]
resource :password, only: [:new, :create, :edit, :update]
resource :registration, only: [:new, :create]
get "dashboard", to: "dashboard#index"
resources :api_keys, only: [:index, :create, :update, :destroy]
resources :maps do
  resources :markers, except: [:index]
end
resources :map_styles, only: [:index, :create, :destroy]
get "embed/:token", to: "embeds#show", as: :embed
root "dashboard#index"
```

---

## Pre-Phase 2 — Code Quality Refactoring (DONE)

Security fixes, separation of concerns, and code quality improvements before Phase 2.

### Security (P0)
- **XSS fixes**: Replaced `innerHTML` with DOM API (`createElement`/`textContent`) in marker sidebar and InfoWindow content
- **Scoped find**: `MapStylesController#destroy` now uses `MapStyle.for_user(Current.user).find()` instead of unscoped `MapStyle.find()`

### Separation of Concerns (P1)
- **Marker auto-positioning**: Moved to `before_create :assign_position` callback in Marker model
- **Map defaults**: US center (39.8283, -98.5795) and zoom (4) as `attribute` defaults in Map model
- **Embed resolution**: Extracted `Map.find_public_by_token` and `Map#embed_api_key` methods
- **Style authorization**: Scoped find + `system_default?` guard replaces manual ownership checks

### Code Quality (P2)
- **CSRF utility**: `app/javascript/utils/csrf.js` — shared across all controllers
- **Fetch error handling**: All fetch calls have `.catch()` with `console.error` + visual toast
- **Marker validations**: lat (-90..90), lng (-180..180), hex color format
- **N+1 fix**: `counter_cache: true` on Marker → Map; dashboard uses `markers_count` column
- **Nav helper**: `nav_link_to(label, path, mobile:)` replaces 6 inline active-link checks

### Dual-Mode Map Rendering
Google Maps API constraint: `AdvancedMarkerElement` requires `mapId`, but `mapId` disables JSON `styles`.

- **With `google_map_id`**: Sets `mapId` → `AdvancedMarkerElement` with `PinElement` → cloud-based styling
- **Without `google_map_id`**: No `mapId` → legacy `Marker` with SVG pin icons → JSON styles via `setOptions`

### UI Changes
- Merged Styles tab into Settings tab (editor sidebar: Markers | Settings)
- Style picker is now a section in Settings with immediate-apply behavior

### Tests
- 126 tests, 361 assertions (up from 104/308)
- New coverage: validation bounds, auto-positioning, model methods, dual-mode data attributes, cross-user auth

---

## Phase 2 — Data & Customization (DONE)

1. **CSV/Excel import** — `roo` gem for .xlsx; upload → column mapping UI → `ImportService`; random group colors with palette; import runs in a `<dialog>` modal triggered from "Import" button in Markers header (`import_dialog_controller.js` handles open/close/reset, blocks close during active polling)
2. **Marker clustering** — `@googlemaps/markerclusterer` via importmap; toggle in map settings; works with both Advanced and legacy markers
3. **Marker grouping** — `MarkerGroup` model; collapsible sidebar sections; group visibility toggle; circle selection for bulk assignment; ungroup action
4. **Info window customization** — `custom_info_html` on markers; render via `google.maps.InfoWindow` in readonly mode
5. **Geometric shapes/layers** — Terra Draw integration (`drawing_controller.js`); `Layer` model with JSON geometry; inline collapsible editing (name + stroke/fill colors via `layer_item_controller.js`); layers render on preview/embed via Google Maps Data layer (readonly skips Terra Draw)
6. **Multi-marker placement** — persistent placement mode; every click adds a marker until Cancel

**Routes**: `resources :marker_groups` (with `assign` + circle selection), `resources :layers`, `resources :imports` (nested under maps); `ungroup` member route on markers

**Tests**: 244 tests, 655 assertions

---

## Phase 3 — Polish (Outline)

1. **(DEFER)Custom JSON style editor** — textarea for Snazzy Maps JSON; validate + save as user style
2. **(DEFER)Street View** — `street_view_controller.js`; split-view panorama; toggle per map
3. **Address autocomplete** — `autocomplete_controller.js`; `google.maps.places.Autocomplete` in marker creation flow

---

## Phase 4 — Tracking (Outline)

1. **Tracking config** — `TrackingConfig` model; webhook token; planned path drawing (reuse Terra Draw)
2. **Webhook receiver** — `POST /webhooks/tracking/:token`; authenticate by token; create `TrackingPoint`; broadcast via Action Cable
3. **Live map updates** — `TrackingChannel` (Action Cable); `tracking_controller.js` updates polyline in real time
4. **Deviation alerts** — `DeviationCheckJob` with Haversine formula; `TrackingAlertMailer`

**New routes**: `resource :tracking_config` (nested under maps), `post "webhooks/tracking/:token"`

---

## Phase 5 — Create with AI (DONE)

A chat tab in the editor sidebar where users describe what they want in natural language. Claude interprets the request and executes map operations via tool use. Results appear on the map in real-time via Action Cable broadcasts.

### Setup

Add your LLM provider API key(s) to Rails credentials:

```bash
EDITOR="vim" bin/rails credentials:edit
# Add one or more:
#   anthropic_api_key: YOUR_KEY_HERE
#   openai_api_key: YOUR_KEY_HERE
#   gemini_api_key: YOUR_KEY_HERE
```

Optionally set `RUBY_LLM_MODEL` env var to choose a model (defaults to `claude-sonnet-4-5-20250929`).

### Architecture
- **RubyLLM** gem for multi-provider LLM support (Anthropic, OpenAI, Gemini) — API keys in `credentials.yml.enc`, model via `ENV["RUBY_LLM_MODEL"]`
- **Background job** (`AiChatJob`) for async API calls via Solid Queue
- **Action Cable** (`AiChatChannel`) for real-time response delivery (streams `ai_chat_map_{id}`)
- **Automatic tool loop** — RubyLLM handles tool call/result cycles internally; `on_tool_call`/`on_tool_result` callbacks trigger per-tool map broadcasts; max 30 tool calls guard via callback
- **Map context via tool param** — each tool receives `map_id` as a required parameter; system prompt includes "Current map ID: #{map.id}"; tool does `Map.find(map_id)` internally
- **Map sync** — after AI makes changes, broadcast updated markers/groups JSON that Stimulus picks up via `markersValue`/`groupsValue` setters
- **Chat UI** — `chat_controller.js` uses `fetch` POST + Action Cable subscription (no Turbo Stream forms)

### Data Model
- `ChatMessage` — belongs_to map, role (user/assistant), content (text), tool_calls (JSON, nullable)
- Index on `[map_id, created_at]`

### AI Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `create_marker` | Add marker to map | lat, lng, title, description, color |
| `update_marker` | Edit existing marker | marker_id, title, description, color, lat, lng |
| `delete_marker` | Remove marker | marker_id |
| `list_markers` | Get all markers on map | — |
| `update_map` | Change title, description, center, zoom | title, description, center_lat, center_lng, zoom |
| `apply_style` | Apply a map style by name | style_name (Default, Silver, Night, Retro, Aubergine, Minimal) |
| `create_group` | Create marker group | name, color |
| `assign_to_group` | Add markers to group | marker_ids, group_name |

Tools are `RubyLLM::Tool` subclasses with `param` DSL. Each receives `map_id` and operates directly on models — no HTTP calls, simpler and transactional.

### Files

**New files:**
- `app/models/chat_message.rb` — model
- `app/controllers/chat_messages_controller.rb` — JSON create action
- `app/channels/ai_chat_channel.rb` — Action Cable channel
- `app/services/ai_chat_service.rb` — RubyLLM chat + automatic tool loop + callbacks
- `app/jobs/ai_chat_job.rb` — async processing + broadcast
- `app/services/ai_tools/*.rb` — 8 `RubyLLM::Tool` subclasses (no base class needed)
- `config/initializers/ruby_llm.rb` — multi-provider API key config
- `app/javascript/controllers/chat_controller.js` — chat UI Stimulus controller
- `app/views/chat_messages/_chat_panel.html.erb` — chat tab content
- `app/views/chat_messages/_chat_message.html.erb` — message bubble partial

**Modified files:**
- `Gemfile` — added `gem "ruby_llm"`
- `app/models/map.rb` — `has_many :chat_messages`
- `config/routes.rb` — `resources :chat_messages, only: [:create]`
- `app/views/maps/edit.html.erb` — 4th "AI" tab + chat panel

### Editor UI

4 tabs: **[Markers] [Settings] [Tracking] [AI]**

The AI panel has a message history area with auto-scroll, user bubbles (blue) and assistant bubbles (gray), a thinking indicator (animated dots), and an input form.

### Broadcast Payload

```ruby
ActionCable.server.broadcast("ai_chat_map_#{map.id}", {
  type: "assistant_message",
  html: rendered_message_html,
  markers_json: map.markers.to_json,
  markers_html: rendered_sidebar_items,
  marker_count: map.markers.count,
  groups_json: map.marker_groups.to_json
})
```

### Tests
- 476 tests, 1187 assertions (up from 321/827 in Phase 4)
- Model tests, controller tests, service tests (RubyLLM mock objects), job tests, channel tests, all 8 tool tests

### Deferred
- Voice input
- Image/screenshot understanding
- Multi-turn tool call streaming
- Token usage tracking / rate limiting
- "Create with AI" button on dashboard

**Routes**: `resources :chat_messages, only: :create` (nested under maps)

---

## Service Layer (DONE)

Controllers never talk to the database directly — all ActiveRecord operations go through namespaced service classes using the `.call` pattern (one action per class).

**Excluded**: Auth controllers (`SessionsController`, `PasswordsController`, `RegistrationsController`) stay as-is. `SettingsController#update` (user update) and `ImportsController#set_import` (import lookup) are documented exceptions.

### Pattern

```ruby
# app/services/markers/create.rb
class Markers::Create
  def self.call(map, params)
    marker = map.markers.build(params)
    marker.save
    marker
  end
end

# Controller usage:
@marker = Markers::Create.call(@map, marker_params)
```

### Service Namespaces

| Namespace | Services | Covers |
|-----------|----------|--------|
| `Maps::` | List, Find, FindPublicByToken, Build, Create, Update, Destroy | MapsController, DashboardController, EmbedsController |
| `Markers::` | Find, Create, Update, Ungroup, Destroy | MarkersController |
| `MarkerGroups::` | Find, Create, Update, Destroy, AssignMarkers, ToggleVisibility | MarkerGroupsController |
| `Layers::` | Find, Create, Update, Destroy, ToggleVisibility | LayersController |
| `Tracking::` | FindVehicle, CreateVehicle, UpdateVehicle, DestroyVehicle, ToggleActive, ClearPoints, SavePlannedPath, QueryPoints, FindVehicleByToken, CreateTrackingPoint, AcknowledgeAlert | TrackedVehiclesController, WebhooksController, DeviationAlertsController |
| `Chat::` | CreateMessage, Clear | ChatMessagesController |
| `ApiKeys::` | Find, List, Create, Update, Destroy | ApiKeysController, SettingsController |
| `MapStyles::` | Create, Destroy | MapStylesController |
| `Imports::` | CreateFromUpload, StartProcessing, ParseHeaders | ImportsController |

`ImportService` (instance-based, used by `CsvImportJob` for row processing) remains as a separate file at `app/services/import_service.rb`.

### Zeitwerk Note

When referencing a top-level constant inside a namespaced service, **always use the `::` prefix** to prevent Zeitwerk from trying to resolve it within the namespace:

```ruby
# Inside Tracking::FindVehicleByToken
::TrackedVehicle.find_by(webhook_token: token)  # correct
TrackedVehicle.find_by(webhook_token: token)     # may fail — Zeitwerk looks for Tracking::TrackedVehicle
```

Constants that currently need `::`: `::Map` (in `Maps::`), `::TrackedVehicle` (in `Tracking::`), `::MapStyle` (in `MapStyles::`), `::CsvImportJob` (in `Imports::`).

### Tests
- 476 tests, 1204 assertions — all existing controller integration tests pass unchanged (services are tested indirectly)

---

## Gems (Beyond Rails 8 Defaults)

- Phase 2: `roo` (~> 2.10) for Excel parsing
- Phase 5: `ruby_llm` for multi-provider LLM support (Anthropic, OpenAI, Gemini)
- Phase 1 needs **no extra gems** — Rails 8 provides everything

## Credentials

API keys stored in `config/credentials.yml.enc`:

```yaml
google_maps_api_key: YOUR_GOOGLE_MAPS_KEY
anthropic_api_key: YOUR_ANTHROPIC_KEY    # and/or:
openai_api_key: YOUR_OPENAI_KEY
gemini_api_key: YOUR_GEMINI_KEY
```

- **Google Maps API key**: Required. Powers all maps in the app.
- **LLM API key**: At least one required for AI chat. Anthropic recommended. Set `RUBY_LLM_MODEL` env var to switch models (default: `claude-sonnet-4-5-20250929`).

## Importmap Pins (Added as Needed)

- Phase 2: `@googlemaps/markerclusterer`, `terra-draw`

---

## Testing Conventions

- **Every model** gets a unit test file (`test/models/<model>_test.rb`): validations, associations, callbacks, scopes
- **Every controller** gets an integration test file (`test/controllers/<controller>_test.rb`): all actions, auth guards, authorization (user can only access own resources), response formats (HTML, JSON, turbo_stream)
- **Fixtures** (`test/fixtures/`): at least 2 users, maps for each user, markers, api_keys, map_styles (system + user)
- **Test helper**: shared `sign_in(user)` method in `test/test_helper.rb` that POSTs to session
- Tests are written alongside each step — not deferred. Each step's PR must have green tests before moving on.
- Run with `bin/rails test` (unit + integration) after each step

---

## Verification

### Phase 1 checklist
1. `bin/rails test` — all model + controller tests pass
2. `bin/rails test:system` — Capybara system tests pass
3. Sign up → create map → add markers → drag markers → apply style → view map (dedicated viewer) — all using platform key, no customer key needed
4. Set map to public → add customer API key in settings → embed via iframe → view embed without login (uses customer key)
5. Verify embed returns "not configured" when customer has no API key
6. Verify embed returns 404 for private maps
7. Verify customer API key is encrypted in DB: `rails runner "puts ApiKey.first.google_maps_key_before_type_cast"` should show ciphertext
8. Verify embed token uniqueness
9. Test platform key in `config/credentials.yml.enc` powers editor and viewer correctly
