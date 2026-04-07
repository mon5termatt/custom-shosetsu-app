# Shosetsu Extension (scaffold)

This folder is a starter scaffold for a **Shosetsu** source extension that targets this Flask site.

## What you need to fill in

- **API key**: create a key in the site admin panel at `/admin/api-keys`.
- **Shosetsu settings**: in the extension settings, set:
  - Base URL
  - API Key (sent as `X-API-Key`)

## Files

- `source.lua`: the Shosetsu source script (skeleton).
- `manifest.json`: basic metadata for the extension bundle.

## JSON endpoints (recommended)

- `GET /api/shosetsu/catalog`
- `GET /api/shosetsu/novel/<book_slug>`
- `GET /api/shosetsu/chapter/<book_slug>/<chapternum>?lang=english`

## Next step (tell me these 2 things)

1. The public URL of your site (or the exact paths you want the extension to call).
2. Which pages should Shosetsu scrape for:
  - book catalog/list
  - chapter list
  - chapter content

