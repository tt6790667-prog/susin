# Documents API Fix — Deploy to doc.susingroup.com

## Problem
App login token is signed by **centralusers** with a production secret that the **doc** server did not know. Result: `Invalid or expired central token` (401).

## Upload these 3 files (overwrite on server)

From folder:
`d:\NITHISH\DOCUMENT SOFTWARE\remix-of-remix-of-remix-of-remix-of-asset-navigator-main\api\`

| Local file | Upload to server |
|------------|------------------|
| `auth/central_sso.php` | `public_html/api/auth/central_sso.php` |
| `config/jwt.php` | `public_html/api/config/jwt.php` |
| `config/central_secrets.php` | `public_html/api/config/central_secrets.php` |

## Central Users — give user DOC access

In Central Users admin, for the login email add domain **DOC** (or `doc.susingroup.com`) with role **sales**.

## After upload

1. Browser: Clear site data for the app URL
2. Logout → Login
3. Open Documents tab

## Security (important)

Production file `centralusers.susingroup.com/backend-php/.env` is currently **publicly readable**. Move it outside `public_html` or deny web access via `.htaccess`.
