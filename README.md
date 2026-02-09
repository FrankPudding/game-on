# Game On 🏆

**Game On** is a local-first game league and match tracking application built with Flutter. It's designed for groups of friends, colleagues, or local clubs who want to track scores and standings across various types of games without needing a complex cloud setup.

## ✨ Features

- **Scoring Systems**:
  - **Simple (Available)**: Standard Win/Loss/Draw (e.g., Board games, Casual play).
  - **Coming Soon**: First To, Timed, Frames, and Tennis scoring types.
- **Premium UI/UX**:
  - Interactive hero-style player selection.
  - Dynamic standings that update in real-time.
  - Beautiful "British Racing Green" and "Mikado Yellow" theme.
- **Local-First Architecture**: 
  - Lightning-fast performance with **Hive** local storage.
  - Works perfectly offline—great for flights or basements.
  - Web support via IndexedDB.
- **League Management**:
  - Create and manage multiple leagues.
  - Track detailed match history and player statistics.
  - Easily add and remove players and leagues.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Database**: [Hive](https://docs.hivedb.dev) (NoSQL)
- **Code Generation**: `build_runner`, `json_serializable`, `hive_generator`
- **Typography**: [Google Fonts](https://fonts.google.com/) (Inter, Outfit)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (Latest Stable)
- Chrome (for web development) or a Mobile Device/Emulator

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/FrankPudding/game-on.git
   cd game-on
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run code generation (required for Hive and JSON models):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Run the app:
   ```bash
   # For Web
   flutter run -d web-server --web-port 8080
   
   # For Desktop/Mobile
   flutter run
   ```

## 📄 License

This project is licensed under the Polyform Noncommercial License 1.0.0 - see the [LICENSE](LICENSE) file for details.
