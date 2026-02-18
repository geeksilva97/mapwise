# MapWise

A map creation platform inspired by Google My Maps and Atlist. Create custom maps with markers, styles, layers, and vehicle tracking, then embed them on any website via iframe. Includes an AI assistant that builds maps from natural language.

## Requirements

- Ruby 3.4.5
- SQLite 3
- Node.js (for Tailwind CSS CLI)

## Setup

```bash
# Install dependencies
bundle install

# Set up the database
bin/rails db:prepare

# Seed map styles
bin/rails db:seed

# Set your Google Maps platform API key
EDITOR="vim" bin/rails credentials:edit
# Add: google_maps_api_key: YOUR_KEY_HERE

# Set your LLM API key(s) (required for AI chat)
EDITOR="vim" bin/rails credentials:edit
# Add one or more:
#   anthropic_api_key: YOUR_KEY_HERE
#   openai_api_key: YOUR_KEY_HERE
#   gemini_api_key: YOUR_KEY_HERE
```

The AI chat feature uses [RubyLLM](https://rubyllm.com) for multi-provider support. By default it uses Claude Sonnet — set `RUBY_LLM_MODEL` env var to switch models (e.g. `gpt-4o`, `gemini-2.0-flash`).

## Running

```bash
bin/dev
```

This starts the Rails server, Tailwind CSS watcher, and Solid Queue worker via `Procfile.dev`. Visit http://localhost:3000.

The Solid Queue worker (`bin/jobs`) is required for background jobs: AI chat, CSV/Excel import, geocoding, tracking broadcasts, and deviation checks. To run manually in separate terminals:

```bash
bin/rails server   # web server
bin/jobs            # Solid Queue worker
```

## Tests

```bash
bin/rails test
```

507 tests, 1297 assertions (96% line coverage, 85% branch coverage).

## Features

### Authentication & Account Management

- Sign up with name, email, and password (rate limited)
- Sign in / sign out with session management
- Password reset via email
- Account settings page to update name and email
- **Email verification**: New users must verify their email within 7 days. During the grace period, an amber banner reminds them. After 7 days, unverified accounts are blocked until verified. Verification tokens expire after 3 days and can be re-sent

### API Keys

MapWise uses a dual API key model:

- **Platform key** (in `config/credentials.yml.enc`): Powers all maps inside the app (editor, viewer, dashboard). Users don't need to provide a key to use MapWise
- **Customer key** (optional, in Settings > API Keys): Encrypted via Active Record Encryption. Required only for embedding public maps on external sites

### Dashboard

Grid of map cards ordered by most recently updated. Quick access to create new maps.

### Map Editor

The editor is a full-screen split view with a sidebar (4 tabs) and map canvas:

- **Markers tab**: Add, edit, drag, and delete markers. Import from CSV/Excel. Organize with groups and layers. Draw geometric shapes
- **Settings tab**: Edit title, description, starting position (lat/lng/zoom), map style, clustering toggle, search mode. Settings save inline via Turbo Stream — no page refresh
- **Tracking tab**: Manage tracked vehicles with webhooks, planned paths, and deviation alerts
- **AI tab**: Chat with an AI assistant to create and modify your map using natural language

### Markers

- **Placement mode**: Click "+ Add", then click the map to place markers. Placement is persistent (multi-marker) — click Cancel to exit
- **Editing**: Inline sidebar form for title, description, color, icon, custom info window HTML
- **Drag to reposition**: Drag markers on the map, position auto-saves
- **Info windows**: Click a marker to see its title, description, and any custom HTML content
- **Clustering**: Optional marker clustering via `@googlemaps/markerclusterer`, togglable in Settings

### Marker Groups

- Create named groups with a color and icon
- Toggle group visibility (show/hide all markers in a group)
- **Circle selection**: Click "Pick markers" on a group, then draw a circle on the map to bulk-assign markers
- Ungroup individual markers back to the ungrouped section

### Geometric Layers (Terra Draw)

Draw shapes directly on the map using a toolbar at the top center:

- **Polygon**: Click vertices, double-click to finish
- **Line**: Connected line segments
- **Circle**: Click center, click to set radius
- **Rectangle**: Click opposite corners
- **Freehand**: Free-form drawing

Each layer has a name, stroke color, stroke width, fill color, and fill opacity. Layers are editable inline in the sidebar and support visibility toggling. In read-only views (viewer, embed), layers render via Google Maps Data layer without Terra Draw.

### CSV/Excel Import

- Import markers from CSV or XLSX files via a dialog modal
- Column mapping UI: map file columns to lat, lng, address, title, description, color, group
- Address-only import with deferred geocoding
- Async processing via background job with progress polling
- Auto-creates groups if a group column is mapped
- Per-row error reporting with completion summary

### Map Styling

Two rendering modes (mutually exclusive, determined by whether the map has a `google_map_id`):

- **With Google Map ID**: `AdvancedMarkerElement` + cloud-based styling
- **Without Google Map ID**: Legacy `Marker` with SVG pin icons + JSON styles

Style picker dropdown in Settings with 6 pre-seeded styles (Default, Silver, Night, Retro, Aubergine, Minimal). Users can also create custom JSON styles.

### Map Search

Search overlay on the map with two modes (configurable in Settings):

- **Places mode**: Google Places API autocomplete — search for addresses and places
- **Marker mode**: Search markers on the current map by title

### Map Visibility & Embedding

- **Private maps**: Viewable only inside MapWise (requires authentication)
- **Public maps**: Also embeddable via iframe on external sites (requires customer API key)

```html
<iframe src="https://your-domain.com/embed/TOKEN" width="100%" height="400" frameborder="0"></iframe>
```

The embed endpoint returns 503 if no customer API key is configured, and 404 for private maps.

### Map Viewer

Dedicated read-only page at `/maps/:id` for viewing maps. Renders markers with info windows, layers, clustering, and search — without editing controls.

### Live Tracking

Each map can have tracked vehicles that receive GPS data via webhooks:

1. Add a vehicle in the Tracking tab — it gets a unique webhook URL
2. Send GPS data: `POST /webhooks/tracking/:token` with `{ lat, lng, speed, heading, recorded_at }`
3. View live positions and trails on the dedicated tracking page (`/maps/:id/tracking`)
4. Draw planned paths and get deviation alerts when vehicles go off-route
5. Toggle vehicles active/inactive, clear tracking history
6. Auto-zoom: the tracking map fits to existing data on load and pans to follow incoming points

Response codes: `200` (success), `404` (vehicle not found), `410` (vehicle inactive), `422` (validation error).

### Deviation Alerts

- Draw a planned path for a vehicle using the drawing tool
- Set a deviation threshold in meters
- When a tracking point exceeds the threshold distance from the planned path, a `DeviationAlert` is created
- Alerts appear in real-time on the tracking page sidebar (Alerts tab)
- Dismissible with an acknowledge button

### Historical Playback

Review vehicle movement history on the tracking page:

- Select a vehicle and date range
- Play/pause/stop controls with speed multiplier (1x, 2x, 5x, 10x)
- Animated marker moves along the historical trail with a progress bar
- Fetches up to 10,000 tracking points per query

### AI Chat

The AI tab lets you describe map changes in plain English:

- "Add 5 coffee shops in downtown Manhattan"
- "Change the style to Night"
- "Create a group called Hotels and add 3 hotels near Times Square"
- "Delete the first marker"
- "What markers are on this map?"

The AI assistant uses 8 tools to execute map operations:

| Tool | Description |
|------|-------------|
| `create_marker` | Add a marker with lat, lng, title, description, color |
| `update_marker` | Edit an existing marker |
| `delete_marker` | Remove a marker |
| `list_markers` | Get all markers on the map |
| `update_map` | Change title, description, center, zoom |
| `apply_style` | Apply a map style by name |
| `create_group` | Create a marker group |
| `assign_to_group` | Add markers to a group |

Changes appear on the map in real-time via Action Cable. Powered by RubyLLM with support for Anthropic (Claude), OpenAI (GPT), and Google Gemini.

## Developer Tools

### Tracking Simulator

A standalone CLI script for demoing live tracking without a real GPS device:

```bash
# List available routes
bin/simulate_tracking --list

# Simulate with defaults (nyc_taxi route, 2s interval, localhost:3000)
bin/simulate_tracking <WEBHOOK_TOKEN>

# Customize route, speed, and host
bin/simulate_tracking <WEBHOOK_TOKEN> --route delivery_route --interval 1 --host localhost:3000

# Loop the route continuously
bin/simulate_tracking <WEBHOOK_TOKEN> --loop
```

Three predefined routes with realistic GPS interpolation (~50m steps, auto-computed headings):

| Route | Description |
|-------|-------------|
| `nyc_taxi` | Cab through Manhattan: Times Square → Central Park → East Village |
| `highway_drive` | I-95 NJ/NY stretch at highway speeds |
| `delivery_route` | Brooklyn neighborhood delivery loop with stops |

No Rails dependency — uses only Ruby stdlib.

### Dev Email

Emails in development are captured by `letter_opener_web`. Browse sent emails at http://localhost:3000/letter_opener.

### Security & Linting

```bash
bin/brakeman        # Security scanner
bin/rubocop         # Code style
bundle exec bundler-audit check  # Gem vulnerabilities
```

## Architecture

### Service Layer

Controllers never talk to the database directly — all ActiveRecord operations go through namespaced service classes using the `.call` pattern. Auth controllers are excluded.

Service namespaces: `Maps::`, `Markers::`, `MarkerGroups::`, `Layers::`, `Tracking::`, `Chat::`, `ApiKeys::`, `MapStyles::`, `Imports::`, `EmailVerifications::`.

### Real-Time Communication

Two Action Cable channels:

- **TrackingChannel** (`tracking_map_{id}`): Live vehicle positions, deviation alerts
- **AiChatChannel** (`ai_chat_map_{id}`): AI assistant responses, map state updates after tool use

### Background Jobs (Solid Queue)

- `AiChatJob` — AI chat processing with tool loop
- `CsvImportJob` — CSV/Excel row processing with progress
- `TrackingBroadcastJob` — Real-time vehicle position broadcasts
- `DeviationCheckJob` — Path deviation detection
- `GeocodeJob` — Address geocoding via Google Geocoding API

### JavaScript Architecture

Stimulus controllers with shared utilities:

- `utils/controllers.js` — Cross-controller lookup helpers (`findMapController`, `findDrawingController`, `findTrackingController`)
- `utils/flash.js` — Error toast notifications
- `utils/csrf.js` — CSRF token helper
- `utils/http.js` — Fetch wrappers (`getJSON`, `postJSON`, `patchJSON`, `turboPost`, etc.)

Key controllers: `map_controller` (Google Maps + diff-based marker rendering), `drawing_controller` (Terra Draw), `tracking_controller` (live tracking), `playback_controller` (historical playback), `chat_controller` (AI chat), `import_controller` / `import_dialog_controller` (CSV import).

### Layouts

- **Application**: Navbar + container (dashboard, settings, auth pages)
- **Fullscreen**: Zero-padding (editor, viewer, tracking page)
- **Embed**: Minimal (iframe embeds)

## Stack

- Rails 8.1.2 with Hotwire (Turbo + Stimulus)
- Tailwind CSS
- SQLite with Solid Queue, Solid Cache, Solid Cable
- Google Maps JavaScript API (dual-mode: AdvancedMarkerElement with cloud Map ID, or legacy Marker with JSON styles)
- Terra Draw (geometric layer drawing)
- RubyLLM (multi-provider AI: Anthropic, OpenAI, Gemini)
- Importmap (no bundler), Propshaft
- Roo (Excel/XLSX parsing)
