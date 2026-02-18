# MapWise

A map creation platform inspired by Google My Maps and Atlist. Create custom maps with markers, styles, layers, and vehicle tracking, then embed them on any website via iframe.

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

This starts the Rails server, Tailwind CSS watcher, and Solid Queue worker. Visit http://localhost:3000.

The Solid Queue worker is required for background jobs (AI chat, CSV import, geocoding, deviation checks). To run manually in separate terminals:

```bash
bin/rails server   # web server
bin/jobs            # Solid Queue worker
```

## Tests

```bash
bin/rails test
```

## How It Works

### API Keys

MapWise uses a dual API key model:

- **Platform key** (in `config/credentials.yml.enc`): Powers all maps inside the app (editor, viewer, dashboard). Users don't need to provide a key to use MapWise.
- **Customer key** (optional, in Settings > API Keys): Required only for embedding public maps on external sites.

### Map Visibility

- **Private maps**: Viewable only inside MapWise (requires authentication).
- **Public maps**: Also embeddable via iframe on external sites (requires customer API key).

### Embedding

Public maps can be embedded with:

```html
<iframe src="https://your-domain.com/embed/TOKEN" width="100%" height="400" frameborder="0"></iframe>
```

### Map Editor

The editor is a full-screen split view with a sidebar and map canvas:

- **Markers tab**: Add, edit, drag, and delete markers on the map. Import from CSV/Excel. Organize with groups and layers.
- **Settings tab**: Edit title, description, starting position (lat/lng/zoom), and map style. Settings save inline via Turbo Stream. Style changes apply immediately.
- **Tracking tab**: Manage tracked vehicles with webhooks, planned paths, and deviation alerts. Each vehicle gets a unique webhook URL for receiving GPS data.
- **AI tab**: Chat with an AI assistant to create and modify your map using natural language. Powered by RubyLLM (Anthropic, OpenAI, Gemini).

### Live Tracking

Each map can have tracked vehicles that receive GPS data via webhooks:

1. Add a vehicle in the Tracking tab — it gets a unique webhook URL
2. Send GPS data to the webhook: `POST /webhooks/tracking/:token` with `{ lat, lng, speed, heading }`
3. View live positions and trails on the dedicated tracking page (`/maps/:id/tracking`)
4. Draw planned paths and get deviation alerts when vehicles go off-route
5. Review historical data with the playback feature (date range filtering, speed controls)

### AI Chat

The AI tab lets you describe map changes in plain English. Examples:

- "Add 5 coffee shops in downtown Manhattan"
- "Change the style to Night"
- "Create a group called Hotels and add 3 hotels near Times Square"
- "Delete the first marker"
- "What markers are on this map?"

The AI assistant uses LLM tool use to execute map operations (create/update/delete markers, apply styles, create groups, etc.). Changes appear on the map in real-time via Action Cable.

**Setup**: Add at least one LLM API key to credentials (see Setup section above). Without a key, the AI tab will not function.

## UI & Layouts

MapWise uses three layouts:

- **Application layout**: Standard pages with responsive navbar, flash messages, and content container (dashboard, auth pages, API keys, map styles, new map).
- **Fullscreen layout**: Zero-padding layout for the map editor and viewer.
- **Embed layout**: Minimal layout for iframe embeds.

Auth pages (sign in, sign up) hide the navbar for a clean, centered card design.

### Email Verification

New users must verify their email within 7 days. During the grace period, an amber banner reminds them. After 7 days, unverified accounts are blocked until verified. Verification tokens expire after 3 days and can be re-sent.

## Stack

- Rails 8.1.2 with Hotwire (Turbo + Stimulus)
- Tailwind CSS
- SQLite with Solid Queue, Solid Cache, Solid Cable
- Google Maps JavaScript API (dual-mode: AdvancedMarkerElement with cloud Map ID, or legacy Marker with JSON styles)
- RubyLLM (multi-provider AI: Anthropic, OpenAI, Gemini)
- Importmap (no bundler), Propshaft
