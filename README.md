# MapWise

A map creation platform inspired by Google My Maps and Atlist. Create custom maps with markers and styles, then embed them on any website via iframe.

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

# Set your Anthropic API key (required for AI chat)
EDITOR="vim" bin/rails credentials:edit
# Add: anthropic_api_key: YOUR_KEY_HERE
```

Get an Anthropic API key at https://console.anthropic.com/settings/keys. The AI chat feature uses Claude Sonnet to interpret natural language requests and modify maps via tool use.

## Running

```bash
bin/dev
```

This starts the Rails server and Tailwind CSS watcher. Visit http://localhost:3000.

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
- **Tracking tab**: Manage tracked vehicles with webhooks, planned paths, and deviation alerts.
- **AI tab**: Chat with an AI assistant to create and modify your map using natural language. Powered by Claude (Anthropic).

### AI Chat

The AI tab lets you describe map changes in plain English. Examples:

- "Add 5 coffee shops in downtown Manhattan"
- "Change the style to Night"
- "Create a group called Hotels and add 3 hotels near Times Square"
- "Delete the first marker"
- "What markers are on this map?"

The AI assistant uses Claude Sonnet with tool use to execute map operations (create/update/delete markers, apply styles, create groups, etc.). Changes appear on the map in real-time via Action Cable.

**Setup**: Add your Anthropic API key to credentials (see Setup section above). Without the key, the AI tab will not function.

## UI & Layouts

MapWise uses three layouts:

- **Application layout**: Standard pages with responsive navbar, flash messages, and content container (dashboard, auth pages, API keys, map styles, new map).
- **Fullscreen layout**: Zero-padding layout for the map editor and viewer.
- **Embed layout**: Minimal layout for iframe embeds.

Auth pages (sign in, sign up) hide the navbar for a clean, centered card design.

## Stack

- Rails 8.1 with Hotwire (Turbo + Stimulus)
- Tailwind CSS
- SQLite with Solid Queue, Solid Cache, Solid Cable
- Google Maps JavaScript API (dual-mode: AdvancedMarkerElement with cloud Map ID, or legacy Marker with JSON styles)
- Anthropic Claude API (AI chat with tool use)
- Importmap (no bundler), Propshaft
