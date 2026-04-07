# Tasil Shosetsu Extension (API)

This Shosetsu source uses a **JSON API** on your Tasil/Flask site and authenticates using an **API key** sent as `X-API-Key`.

## Install

Add `source.lua` to your Shosetsu extensions (or install from your extensions repo workflow) and enable the source.

## Configure (required)

1. **Create an API key** on your site:
   - Go to `/admin/api-keys`
   - Create a key and copy it
2. **Set extension settings** in Shosetsu:
   - **Base URL**: your site URL (example: `https://tasil.mon5termatt.com`)
   - **API Key**: the key you generated (sent as `X-API-Key`)

## Endpoints used

- `GET /api/shosetsu/catalog`
- `GET /api/shosetsu/novel/<book_slug>`
- `GET /api/shosetsu/chapter/<book_slug>/<chapternum>?lang=english`

## Troubleshooting

- **401 `missing_api_key`**: you didn’t set the API key in the extension settings.
- **403 `invalid_api_key`**: the key is wrong, revoked, or deleted — generate a new one in `/admin/api-keys`.
- **Empty catalog**: your server only returns **non-hidden** books to app clients.


