# Support Ticket API — app.susingroup.com

| Item | Value |
|------|--------|
| Domain | **app.susingroup.com** |
| Database | `u601352558_support` |
| User | `u601352558_support` |

## 1. SQL (phpMyAdmin)

1. Open phpMyAdmin for `u601352558_support`
2. Run **`sql/schema_tables_only.sql`**
3. Tables: `support_tickets`, `ticket_replies`

## 2. Upload PHP (critical path)

On **app.susingroup.com**, upload **contents of** `support-api/api/` to:

```
public_html/support-api/api/
```

(Current live URLs — matches your Hostinger upload.)

| URL | Expected |
|-----|----------|
| `https://app.susingroup.com/support-api/api/health.php` | `{"ok":true,...}` JSON |
| `https://app.susingroup.com/support-api/api/tickets/index.php` | JSON `401` without token |
| `https://app.susingroup.com/api/...` | Wrong — Flutter page (not uploaded there) |

Create `public_html/uploads/tickets/` (chmod 755).

Flutter `web/.htaccess` already skips rewrite when a real `.php` file exists under `/api/`.

## 3. `.env`

Copy `api/.env.example` → `api/.env`:

```env
DB_HOST=localhost
DB_NAME=u601352558_support
DB_USER=u601352558_support
DB_PASS=your_mysql_password
JWT_SECRET=optional-local-secret
```

## 4. Central Users

Add domain for each app user:

- **SUPPORT** or **app.susingroup.com**
- Role: `user` (or `admin` for all tickets)

## 5. Flutter app

`lib/api_config.dart` uses:

```dart
https://app.susingroup.com/support-api/api
```

Rebuild / hot restart after deploy.

## 6. Quick test

```
https://app.susingroup.com/support-api/api/health.php
```

Must return **JSON**, not the Susin App HTML page.

## API summary

| Method | URL | Auth |
|--------|-----|------|
| GET | `/api/tickets/index.php` | Bearer central token |
| POST | `/api/tickets/index.php` | JSON or multipart |
| PATCH | `/api/tickets/index.php` | Admin only |
| GET/POST | `/api/tickets/reply.php` | Bearer |
