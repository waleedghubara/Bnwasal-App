# Bnwasal-App

Bnwasal (بن وصل) Complete Delivery Platform Monorepo.

## Project Structure

- **`admin_bnwasal/`**: Admin Panel web & desktop application built with Flutter.
- **`backend/`**: Node.js / Express REST API server & database management.
- **`we_deliver/`**: Delivery mobile application built with Flutter.
- **`wedeliver-landing/`**: Web landing page for Bnwasal platform.

## Getting Started

### Backend
1. `cd backend`
2. `npm install`
3. Copy `.env.example` to `.env` and configure your environment variables.
4. `npm start` or `npm run dev`

### Admin Panel
1. `cd admin_bnwasal`
2. `flutter pub get`
3. `flutter run -d chrome` (or target platform)

### Mobile Application
1. `cd we_deliver`
2. `flutter pub get`
3. `flutter run`
