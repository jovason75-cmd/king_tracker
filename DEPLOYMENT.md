# King Tracker

A comprehensive tracker for Stephen King's bibliography and adaptations.

## Features

- Track 80+ Stephen King books with owned/read/wished status
- 5-star rating system for books
- Follow 80+ film and TV adaptations
- Dark Tower reading order (main series + extended list)
- Connection tracking between books
- Detailed statistics with progress visualization
- PDF export for wishlists and statistics
- Iconology guide explaining all symbols

## Version 1.0

Built with Flutter for Web.

## Deployment

### GitHub Pages

1. Create a new repository on GitHub
2. Run these commands:

```bash
git add .
git commit -m "Initial commit - King Tracker v1.0"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

3. Deploy to GitHub Pages:

```bash
flutter build web --release --base-href "/YOUR_REPO/"
git subtree push --prefix build/web origin gh-pages
```

4. Enable GitHub Pages in repository settings (Settings > Pages > Source: gh-pages branch)

### Firebase Hosting

```bash
npm install -g firebase-tools
firebase login
firebase init hosting
# Select build/web as public directory
firebase deploy
```

### Netlify

1. Go to https://app.netlify.com/drop
2. Drag and drop the `build/web` folder
3. Your site is live!

## Local Development

```bash
flutter pub get
flutter run -d chrome
```
