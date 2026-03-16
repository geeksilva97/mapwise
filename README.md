# MapWise

A self-hostable map creation platform. Create custom maps with markers, groups, layers, and styles, then embed them on any website via iframe. Includes live vehicle tracking with deviation alerts and an AI assistant that builds maps from natural language.

Inspired by Google My Maps and Atlist, but you own your data and infrastructure.

## Table of Contents

- [Self-Hosting Guide](#self-hosting-guide)
  - [Prerequisites](#prerequisites)
  - [1. Clone and Install](#1-clone-and-install)
  - [2. Configure Credentials](#2-configure-credentials)
  - [3. Configure Branding](#3-configure-branding)
  - [4. Seed the Database](#4-seed-the-database)
  - [5. Run Locally](#5-run-locally)
  - [6. Deploy to Production](#6-deploy-to-production)
  - [7. SSL Setup](#7-ssl-setup)
  - [8. Email Delivery](#8-email-delivery)
- [Configuration Reference](#configuration-reference)
- [Features](#features)
- [Architecture](#architecture)
- [Tests](#tests)
- [Developer Tools](#developer-tools)
- [Stack](#stack)

---

## Self-Hosting Guide

### Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Ruby | 3.4.5 | Exact version in `.ruby-version` |
| SQLite | 3.8+ | Ships with macOS and most Linux distros |
| Node.js | 18+ | Only for the Tailwind CSS CLI during asset compilation |
| Docker | 20+ | For production deployment via Kamal |

No external database server, Redis, or message broker required. Everything runs on SQLite with Solid Queue, Solid Cache, and Solid Cable.

### 1. Clone and Install

```bash
git clone <repo-url> && cd mapwise
bundle install
```

### 2. Configure Credentials

Credentials are stored encrypted in `config/credentials.yml.enc`. You need to create your own master key and credentials file:

```bash
# Delete the existing credentials (they're encrypted with a key you don't have)
rm config/credentials.yml.enc

# Generate your own master key + credentials file
EDITOR="vim" bin/rails credentials:edit
```

Add the following keys:

```yaml
# Required — powers all maps (editor, viewer, dashboard)
google_maps_api_key: YOUR_GOOGLE_MAPS_API_KEY

# At least one LLM key is needed for the AI chat feature (optional)
anthropic_api_key: YOUR_KEY    # Claude
openai_api_key: YOUR_KEY       # GPT
gemini_api_key: YOUR_KEY       # Gemini

# For production email delivery (optional, see Email Delivery section)
# smtp:
#   user_name: YOUR_SMTP_USER
#   password: YOUR_SMTP_PASSWORD
```

**Google Maps API key**: Create one at [console.cloud.google.com](https://console.cloud.google.com/apis/credentials). Enable the Maps JavaScript API, Places API, and Geocoding API.

**AI chat**: Uses [RubyLLM](https://rubyllm.com) for multi-provider support. Defaults to Claude Sonnet. Set `RUBY_LLM_MODEL` env var to switch (e.g. `gpt-4o`, `gemini-2.0-flash`).

> **Important**: Keep `config/master.key` safe and never commit it. You'll need it for production deployment.

### 3. Configure Branding

Copy the example environment file and customize:

```bash
cp .env.example .env
```

Branding variables (all optional, sensible defaults provided):

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | MapWise | Shown in navbar, page titles, emails, PWA manifest |
| `MAILER_FROM_ADDRESS` | noreply@example.com | Sender address for verification and password reset emails |
| `THEME_COLOR` | #2563eb | PWA theme color and manifest background |

The primary brand color used for buttons, links, and active states is defined via CSS custom properties in `app/assets/tailwind/application.css`. To change it, override the `--brand-*` CSS variables:

```css
/* In your custom CSS or via a <style> tag */
:root {
  --brand-50: oklch(0.98 0.01 155);
  --brand-100: oklch(0.94 0.03 155);
  --brand-500: oklch(0.55 0.17 155);
  --brand-600: oklch(0.48 0.17 155);
  --brand-700: oklch(0.42 0.16 155);
  --brand-800: oklch(0.36 0.14 155);
}
```

To replace the logo, swap `public/icon.png` and `public/icon.svg` with your own files. The navbar logo is an inline SVG in `app/views/shared/_navbar.html.erb`.

### 4. Seed the Database

```bash
bin/rails db:prepare
bin/rails db:seed     # Creates 6 built-in map styles
```

### 5. Run Locally

```bash
bin/dev
```

This starts three processes via `Procfile.dev`:
- **web**: Rails server on port 3000
- **css**: Tailwind CSS watcher (rebuilds on file changes)
- **jobs**: Solid Queue worker (processes background jobs)

Visit http://localhost:3000, create an account, and start building maps.

> The Solid Queue worker is required for AI chat, CSV/Excel import, geocoding, tracking broadcasts, and deviation checks. Without it, these features will silently fail.

To run processes manually in separate terminals:

```bash
bin/rails server   # web server
bin/jobs            # background jobs
```

### 6. Deploy to Production

The app ships with a Kamal 2 deployment configuration that deploys to any Linux server with Docker.

#### a. Prepare your server

You need a Linux server (Ubuntu 22.04+ recommended) with:
- Docker installed (`curl -fsSL https://get.docker.com | sh`)
- SSH access from your local machine
- A container registry (Docker Hub, GitHub Container Registry, GCP Artifact Registry, etc.)

#### b. Configure deployment

Edit `.env` with your deployment details:

```bash
# Server
DEPLOY_HOST=203.0.113.10           # Your server's IP or hostname
DEPLOY_SSH_USER=root               # SSH user with Docker access
DEPLOY_SSH_KEY=~/.ssh/id_rsa       # Path to your SSH private key

# Container registry
DEPLOY_REGISTRY=ghcr.io                  # Registry server
DEPLOY_REGISTRY_USERNAME=your-username   # Registry username
DEPLOY_IMAGE=your-username/mapwise       # Image name
DEPLOY_VOLUME=mapwise_storage            # Docker volume name for data

# Service name (used by Kamal for container naming)
DEPLOY_SERVICE=mapwise

# Registry authentication — set KAMAL_REGISTRY_PASSWORD here,
# or let .kamal/secrets auto-detect (works for GCP with gcloud CLI)
KAMAL_REGISTRY_PASSWORD=your-registry-token
```

#### c. Set the master key

Your production server needs the Rails master key to decrypt credentials:

```bash
# .kamal/secrets reads it automatically from config/master.key
# Make sure this file exists locally before deploying
cat config/master.key
```

#### d. Deploy

```bash
# First deployment (sets up Docker, creates volumes, runs migrations)
bin/kamal setup

# Subsequent deployments
bin/kamal deploy
```

#### e. Useful commands

```bash
bin/kamal logs        # Tail production logs
bin/kamal console     # Rails console on the server
bin/kamal shell       # SSH into the running container
```

#### Production details

- **Solid Queue** runs in-process with Puma via `SOLID_QUEUE_IN_PUMA=true` (no separate job server needed)
- **Data persistence**: SQLite databases and Active Storage uploads live in a Docker volume mounted at `/rails/storage`
- **Health check**: `GET /up` returns 200 when the app is ready
- The app accepts connections on port 80 via Thruster (Rails' built-in HTTP proxy)

### 7. SSL Setup

The app ships without SSL enabled. For production, you have two options:

**Option A: Reverse proxy (recommended)**

Put Nginx, Caddy, or a cloud load balancer in front of the app. Caddy auto-provisions Let's Encrypt certificates:

```
# Caddyfile
yourdomain.com {
    reverse_proxy localhost:80
}
```

Then uncomment in `config/environments/production.rb`:

```ruby
config.assume_ssl = true
config.force_ssl = true
```

**Option B: Thruster with Let's Encrypt**

Thruster (the built-in proxy) can handle SSL automatically if you set `TLS_DOMAIN`:

```bash
# Add to your .env or Kamal env config
TLS_DOMAIN=yourdomain.com
```

### 8. Email Delivery

In development, emails are captured by `letter_opener_web` at http://localhost:3000/letter_opener.

For production, configure SMTP in `config/environments/production.rb`:

```ruby
config.action_mailer.smtp_settings = {
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  address: "smtp.example.com",
  port: 587,
  authentication: :plain
}
```

Add your SMTP credentials via `bin/rails credentials:edit` and set `MAILER_HOST` in your `.env` to your domain or IP (used for links in emails).

---

## Configuration Reference

### Environment Variables

| Variable | Where | Default | Description |
|----------|-------|---------|-------------|
| `APP_NAME` | Branding | MapWise | Application name (navbar, titles, emails) |
| `MAILER_FROM_ADDRESS` | Branding | noreply@example.com | Email sender address |
| `THEME_COLOR` | Branding | #2563eb | PWA theme/background color |
| `RUBY_LLM_MODEL` | AI | claude-sonnet (via RubyLLM) | LLM model for AI chat |
| `MAILER_HOST` | Email | localhost | Host for email links |
| `RAILS_LOG_LEVEL` | Logging | info | Log verbosity (debug/info/warn/error) |
| `WEB_CONCURRENCY` | Performance | 2 | Puma worker count |
| `RAILS_MAX_THREADS` | Performance | 5 | Threads per Puma worker |
| `SOLID_QUEUE_IN_PUMA` | Jobs | false | Run Solid Queue in Puma process |

### Encrypted Credentials (`bin/rails credentials:edit`)

| Key | Required | Description |
|-----|----------|-------------|
| `google_maps_api_key` | Yes | Google Maps JavaScript API key |
| `anthropic_api_key` | For AI | Anthropic API key (Claude models) |
| `openai_api_key` | For AI | OpenAI API key (GPT models) |
| `gemini_api_key` | For AI | Google Gemini API key |
| `smtp.user_name` | For email | SMTP username |
| `smtp.password` | For email | SMTP password |

### Deployment Variables (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `DEPLOY_HOST` | *(none)* | Server IP or hostname |
| `DEPLOY_SERVICE` | mapwise | Kamal service name |
| `DEPLOY_IMAGE` | mapwise | Container image name |
| `DEPLOY_REGISTRY` | *(none)* | Container registry server |
| `DEPLOY_REGISTRY_USERNAME` | *(none)* | Registry auth username |
| `DEPLOY_SSH_USER` | root | SSH user for deployment |
| `DEPLOY_SSH_KEY` | *(none)* | Path to SSH private key |
| `DEPLOY_VOLUME` | mapwise_storage | Docker volume for data |
| `KAMAL_REGISTRY_PASSWORD` | *(auto for GCP)* | Registry auth token/password |

### CSS Custom Properties (Brand Colors)

Override in your CSS to change the primary brand color:

| Variable | Default (oklch) | Usage |
|----------|-----------------|-------|
| `--brand-50` | Light tint | Hover backgrounds, banners |
| `--brand-100` | Lighter shade | Borders, subtle backgrounds |
| `--brand-500` | Mid shade | Secondary buttons, hover states |
| `--brand-600` | Primary | Buttons, links, active tabs |
| `--brand-700` | Darker shade | Button hover (dark variant) |
| `--brand-800` | Dark shade | Link hover, emphasis text |

### Files to Customize

| File | What to change |
|------|---------------|
| `public/icon.png` | Favicon and PWA icon (512x512 PNG) |
| `public/icon.svg` | SVG favicon |
| `app/views/shared/_navbar.html.erb` | Navbar logo (inline SVG on line 6) |

---

## Features

### Authentication & Account Management

- Sign up with name, email, and password (rate limited)
- Sign in / sign out with session management
- Password reset via email
- Account settings page to update name and email
- Email verification with 7-day grace period. Amber banner during grace period, hard block after deadline. Tokens expire in 3 days and can be re-sent

### API Keys (Dual Model)

- **Platform key** (in encrypted credentials): Powers all maps inside the app. Users don't need a key to use the application
- **Customer key** (optional, in Settings > API Keys): Encrypted via Active Record Encryption. Required only for embedding public maps on external sites via iframe

### Dashboard

Grid of map cards ordered by most recently updated. Quick access to create new maps.

### Map Editor

Full-screen split view with a sidebar (4 tabs) and map canvas:

- **Markers tab**: Add, edit, drag, and delete markers. Import from CSV/Excel. Organize with groups and layers. Draw geometric shapes
- **Settings tab**: Title, description, starting position, map style, clustering, search mode. Settings auto-save via Turbo Stream
- **Tracking tab**: Manage tracked vehicles with webhooks, planned paths, and deviation alerts
- **AI tab**: Chat with an AI assistant to create and modify your map using natural language

### Markers

- Persistent placement mode (click map to place multiple markers, Cancel to exit)
- Inline editing: title, description, color, icon, custom info window HTML
- Drag to reposition (auto-saves)
- Info windows on click
- Optional clustering via `@googlemaps/markerclusterer`

### Marker Groups

- Named groups with color and icon
- Toggle group visibility
- Circle selection: draw a circle on the map to bulk-assign markers
- Ungroup individual markers

### Geometric Layers (Terra Draw)

Draw shapes on the map: polygon, line, circle, rectangle, freehand. Each layer has name, stroke color/width, fill color/opacity. Inline editing, visibility toggling. Read-only views render via Google Maps Data layer.

### CSV/Excel Import

- Import from CSV or XLSX via dialog modal
- Column mapping UI (lat, lng, address, title, description, color, group)
- Address-only import with deferred geocoding
- Async processing with progress polling
- Auto-creates groups from a mapped column

### Map Styling

Two mutually exclusive rendering modes:

- **With Google Map ID**: `AdvancedMarkerElement` + cloud-based styling
- **Without Google Map ID**: Legacy `Marker` with SVG pin icons + JSON styles

6 pre-seeded styles: Default, Silver, Night, Retro, Aubergine, Minimal. Users can create custom JSON styles.

### Map Search

Overlay with two modes (configurable in Settings):

- **Places mode**: Google Places API autocomplete
- **Marker mode**: Search markers on the current map by title

### Map Visibility & Embedding

- **Private maps**: Viewable only inside the app (requires authentication)
- **Public maps**: Embeddable via iframe (requires customer API key)

```html
<iframe src="https://your-domain.com/embed/TOKEN" width="100%" height="400" frameborder="0"></iframe>
```

Returns 503 if no customer API key is configured, 404 for private maps.

### Live Tracking

1. Add a vehicle in the Tracking tab — gets a unique webhook URL
2. Send GPS data: `POST /webhooks/tracking/:token` with `{ lat, lng, speed, heading, recorded_at }`
3. View live positions and trails on the tracking page (`/maps/:id/tracking`)
4. Draw planned paths and get deviation alerts when vehicles go off-route
5. Toggle vehicles active/inactive, clear tracking history

Response codes: `200` (success), `404` (not found), `410` (inactive), `422` (validation error).

### Deviation Alerts

- Draw a planned path for a vehicle
- Set a deviation threshold in meters
- Real-time alerts when a tracking point exceeds the threshold distance from the planned path
- Dismissible via acknowledge button

### Historical Playback

- Select a vehicle and date range on the tracking page
- Play/pause/stop with speed multiplier (1x, 2x, 5x, 10x)
- Animated marker along historical trail with progress bar

### AI Chat

Describe map changes in natural language:

- "Add 5 coffee shops in downtown Manhattan"
- "Change the style to Night"
- "Create a group called Hotels and add 3 hotels near Times Square"

8 tools: `create_marker`, `update_marker`, `delete_marker`, `list_markers`, `update_map`, `apply_style`, `create_group`, `assign_to_group`. Changes appear in real-time via Action Cable.

---

## Architecture

### Service Layer

Controllers never touch the database directly. All ActiveRecord operations go through namespaced `.call` service classes:

```ruby
@marker = Markers::Create.call(@map, marker_params)
```

Namespaces: `Maps::`, `Markers::`, `MarkerGroups::`, `Layers::`, `Tracking::`, `Chat::`, `ApiKeys::`, `MapStyles::`, `Imports::`, `EmailVerifications::`.

### Real-Time (Action Cable)

- **TrackingChannel** (`tracking_map_{id}`): Live vehicle positions, deviation alerts
- **AiChatChannel** (`ai_chat_map_{id}`): AI responses, map state updates

### Background Jobs (Solid Queue)

`AiChatJob`, `CsvImportJob`, `TrackingBroadcastJob`, `DeviationCheckJob`, `GeocodeJob`.

### JavaScript (Stimulus)

Shared utilities in `app/javascript/utils/`: `controllers.js` (cross-controller lookups), `flash.js` (error toasts), `csrf.js`, `http.js` (fetch wrappers).

Key controllers: `map_controller` (Google Maps, diff-based rendering), `drawing_controller` (Terra Draw), `tracking_controller`, `playback_controller`, `chat_controller`, `import_controller`.

### Layouts

- **Application**: Navbar + container (dashboard, settings, auth)
- **Fullscreen**: Zero-padding (editor, viewer, tracking)
- **Embed**: Minimal (iframes)

---

## Tests

```bash
bin/rails test
```

514 tests, 1305 assertions (95.7% line coverage, 83.5% branch coverage).

---

## Developer Tools

### Tracking Simulator

Standalone CLI for demoing live tracking without a real GPS device:

```bash
bin/simulate_tracking --list                          # List routes
bin/simulate_tracking <TOKEN>                          # NYC taxi, 2s interval
bin/simulate_tracking <TOKEN> --route delivery_route   # Custom route
bin/simulate_tracking <TOKEN> --loop                   # Loop continuously
```

Routes: `nyc_taxi`, `highway_drive`, `delivery_route`.

### Dev Email

Captured by `letter_opener_web` at http://localhost:3000/letter_opener.

### Security Scanning

```bash
bin/brakeman                          # Static analysis
bin/rubocop                           # Code style
bundle exec bundler-audit check       # Gem vulnerabilities
```

---

## Stack

- Rails 8.1.2, Hotwire (Turbo + Stimulus), Tailwind CSS v4
- SQLite with Solid Queue, Solid Cache, Solid Cable
- Google Maps JavaScript API (dual-mode rendering)
- Terra Draw (geometric layers)
- RubyLLM (multi-provider AI: Anthropic, OpenAI, Gemini)
- Importmap, Propshaft
- Kamal 2 (deployment)
