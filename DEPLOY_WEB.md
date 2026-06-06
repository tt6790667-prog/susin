# Flutter Web Deploy — app.susingroup.com

## Your server layout (detected)

Files are at **`public_html/`** (site root), NOT `public_html/app/`:

- ✅ `https://app.susingroup.com/flutter_bootstrap.js`
- ✅ `https://app.susingroup.com/main.dart.js`
- ❌ `https://app.susingroup.com/app/flutter_bootstrap.js` → 404

**Problem:** `index.html` had `<base href="/app/">` so the browser looked in `/app/` and login never loaded.

**Fix:** Use **`--base-href /`** and upload `index.html` + `.htaccess` to **`public_html/`** (root).

---

## Build

```bash
cd D:\NITHISH\APP
flutter build web --base-href /
```

Output: `build\web\`

---

## Upload

Hostinger → **app.susingroup.com** → **`public_html/`** (root, NOT `app/web/`)

Upload **all** from `build\web\`:

- `index.html` ← **must replace** (base href `/`)
- `.htaccess`
- `flutter_bootstrap.js`, `main.dart.js`, `assets/`, `canvaskit/`, …

Keep **`public_html/support-api/`** for tickets API.

You can **delete** empty `public_html/app/web/` folder.

---

## Test

| URL | Result |
|-----|--------|
| `https://app.susingroup.com/` | Login page |
| `https://app.susingroup.com/flutter_bootstrap.js` | JavaScript |
| `https://app.susingroup.com/support-api/api/health.php` | `{"ok":true}` |

---

## Quick fix (only index.html)

If JS files are already at root, in File Manager edit **`public_html/index.html`** line 17:

```html
<base href="/">
```

Save → refresh browser (Ctrl+Shift+R).
