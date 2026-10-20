# TableGo Flutter App

Flutter 3.x mobile app — Module 1: Utilisateur.

## Requirements
- Flutter SDK >= 3.13
- Dart >= 3.x
- Android emulator or iOS simulator
- Local SQLite database (sqflite + Riverpod) — no backend required

## Setup

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Run
```bash
# Android emulator
flutter run

# iOS simulator
flutter run -d ios

# Web
flutter run -d chrome
```

## Architecture

```
lib/
├── main.dart                    ← App entry + routing
├── core/
│   ├── theme/                   ← AppColors, AppTheme (Poppins font)
│   ├── database/                ← DatabaseHelper, tables, dev seed (sqflite)
│   └── constants/               ← Route name constants
├── features/
│   ├── auth/                    ← Login, Register, ForgotPassword, SplashScreen
│   ├── profile/                 ← Client & Restaurant profile screens
│   ├── favorites/               ← Favorites screen (Restaurants + Dishes tabs)
│   └── recommendations/         ← AI recommendation carousel
└── shared/widgets/              ← AppButton, AppTextField, RestaurantCard, DishCard
```

## Design System
- Primary color: #E85D0C (orange)
- Font: Poppins (via google_fonts)
- Cards: 24px radius, no elevation
- Buttons: 52px height, 12px radius

## Test Credentials
| Role       | Email               | Password    |
|------------|---------------------|-------------|
| Client     | client@test.com     | password123 |
| Restaurant | resto@test.com      | password123 |

## Screens Built
1. SplashScreen — auto-login if a local session exists
2. LoginScreen — email/password + social placeholders
3. RegisterScreen — client/restaurant toggle
4. ForgotPasswordScreen — email input → success state
5. ChangePasswordScreen — authenticated
6. ClientHomeScreen — greeting, search, AI carousel, nearby list, 5-tab nav
7. ClientProfileScreen — avatar, stats, dietary chips, menu
8. EditClientProfileScreen — photo picker, dietary prefs, allergies chips
9. RestaurantProfileScreen — hours, photos grid, description
10. EditRestaurantProfileScreen — all fields editable
11. FavoritesScreen — Restaurants / Plats tabs with heart toggle
