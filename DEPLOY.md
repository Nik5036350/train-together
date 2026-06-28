# Host This App on GitHub Pages

This repo is a Vite + React static app. It does not need a backend server: `npm run build`
creates a deployable `dist/` folder, and GitHub Pages can host that folder with a
GitHub Actions workflow.

This checkout is configured for the project-site URL:

```text
https://Nik5036350.github.io/couples-recording-mode/
```

In general, the final URL will be one of these:

- Project site: `https://YOUR_USERNAME.github.io/couples-recording-mode/`
- User site: `https://YOUR_USERNAME.github.io/`
- Custom domain: `https://your-domain.com/`

## 1. Create the GitHub repository

1. Sign in to GitHub.
2. Create a new repository named `couples-recording-mode`.
3. Keep it public if you are using GitHub Free. Private GitHub Pages requires a paid
   plan or eligible organization plan.
4. Do not add starter files on GitHub if this local repo already has `README.md`,
   `package.json`, and source files.

## 2. Push this local repo to GitHub

From this project folder:

```bash
git init
git add .
git commit -m "Initial app"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/couples-recording-mode.git
git push -u origin main
```

If the repo already has Git history, skip `git init` and the commit if they are not
needed. If `origin` already exists, update it instead:

```bash
git remote set-url origin https://github.com/YOUR_USERNAME/couples-recording-mode.git
git push -u origin main
```

## 3. Set the Vite base path

Open `vite.config.js` and add the right `base` value inside `defineConfig`.

For the normal project URL:

```js
export default defineConfig({
  base: '/couples-recording-mode/',
  plugins: [
    // existing plugins
  ],
})
```

For a user site named `YOUR_USERNAME.github.io`, or for a custom domain, use `/` instead:

```js
export default defineConfig({
  base: '/',
  plugins: [
    // existing plugins
  ],
})
```

Commit and push the change:

```bash
git add vite.config.js
git commit -m "Set GitHub Pages base path"
git push
```

## 4. Add the GitHub Pages workflow

Create this file:

```text
.github/workflows/deploy.yml
```

Add:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy
        id: deployment
        uses: actions/deploy-pages@v4
```

Commit and push it:

```bash
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Pages deployment"
git push
```

## 5. Turn on GitHub Pages

1. Open the repository on GitHub.
2. Go to **Settings**.
3. In the left sidebar, open **Pages**.
4. Under **Build and deployment**, set **Source** to **GitHub Actions**.
5. Save if GitHub shows a save button.

The workflow will run automatically after the next push to `main`. You can also run it
manually from the **Actions** tab because the workflow includes `workflow_dispatch`.

## 6. Wait for the deployment

1. Open the repository's **Actions** tab.
2. Click **Deploy to GitHub Pages**.
3. Wait for the run to finish successfully.
4. Open the deployed URL shown in the workflow summary, or visit:

```text
https://YOUR_USERNAME.github.io/couples-recording-mode/
```

GitHub Pages can take a few minutes to publish the first deployment.

## 7. Install it on iPhone

The app is a PWA, so after it is hosted:

1. Open the GitHub Pages URL in Safari on the iPhone.
2. Tap **Share**.
3. Tap **Add to Home Screen**.
4. Tap **Add**.

The app stores workout data in the device browser's local storage. Use the app's backup
export/import feature before switching phones, clearing Safari data, or reinstalling.

## Updating the app later

Every time you change the app:

```bash
git add .
git commit -m "Describe the update"
git push
```

GitHub Actions will rebuild the app and publish the new `dist/` output automatically.

## Troubleshooting

- Blank page: check that `base` in `vite.config.js` matches the hosted URL.
- 404 page: confirm **Settings -> Pages -> Source** is set to **GitHub Actions**.
- Failed build: open **Actions**, click the failed run, and inspect the failed step.
- Old version still appears: close and reopen the installed PWA while online so the
  service worker can update.

## References

- GitHub Pages publishing source: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- Vite static deployment guide: https://vite.dev/guide/static-deploy.html#github-pages
