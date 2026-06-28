# Install on your iPhone (PWA)

The app is a static site that stores all data in your browser's local storage on
the device. To run it like a real app on your iPhone, host the build somewhere
and "Add to Home Screen".

## 1. Build

```bash
cd web
npm install      # first time only
npm run build    # outputs to web/dist/
```

`dist/` is a fully static site (it includes the PWA manifest, service worker and
icons). It can be served from any static host — no server code required, because
the app uses HashRouter.

## 2. Host it (pick one — all free)

### Option A — Netlify Drop (easiest, no account/CLI needed)
1. Go to https://app.netlify.com/drop
2. Drag the **`web/dist`** folder onto the page.
3. You get a public `https://...netlify.app` URL. Done.

### Option B — Vercel
```bash
npm i -g vercel
cd web && vercel --prod      # set the output dir to dist when asked
```

### Option C — GitHub Pages (served from a subpath like /myrepo/)
If the site is served from `https://you.github.io/myrepo/`, set the base path
first, then rebuild:
```js
// web/vite.config.js → defineConfig({ base: '/myrepo/', ... })
```
Then push `dist/` to the `gh-pages` branch (or use an action).
Netlify/Vercel root hosting does **not** need a `base` change.

## 3. Add to Home Screen (on the iPhone)

1. Open the hosted URL in **Safari** (must be Safari, not Chrome).
2. Tap the **Share** button → **Add to Home Screen** → **Add**.
3. Launch it from the new home-screen icon. It opens full-screen with no Safari
   chrome, and works offline after the first load.

## 4. Don't lose your data

All workouts are stored on the device. iOS can clear an installed PWA's storage
after ~7 days of not opening it. So:

- Open **Home → Data & backup → Export backup** every so often to save a
  `couples-backup-YYYY-MM-DD.json` file (AirDrop/email it to yourself).
- To restore (new phone, or after data loss): **Import backup** and pick the file.

## Updating the app later

Re-run `npm run build` and re-deploy `dist/`. The service worker auto-updates the
installed app the next time it's opened online.
