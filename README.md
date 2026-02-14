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
```

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

## Stack

- Rails 8.1 with Hotwire (Turbo + Stimulus)
- Tailwind CSS
- SQLite with Solid Queue, Solid Cache, Solid Cable
- Google Maps JavaScript API (AdvancedMarkerElement)
