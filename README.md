# MCQ (Muallim Carpets) - Business Management System

A complete business management application for **Muallim Carpets** with a Node.js/Express backend and a Flutter mobile app.

## Features

- **Authentication & Roles** - Admin and Shop Manager accounts with JWT auth
- **Dashboard** - Daily/weekly/monthly/yearly sales, expenses and inventory statistics with charts
- **Products & Categories** - CRUD with low-stock alerts
- **Inventory** - Stock in/out tracking with full history
- **Sales** - Sale creation, listing and detailed views
- **Expenses** - Categorized expense tracking
- **Reports** - Period-based sales/expense/inventory reports with CSV export
- **Analytics** - Business insights and charts
- **Audit Logs** - Immutable audit trail with soft-delete and restore (admin only)
- **Shops & Managers** - Multi-shop management with manager assignment (admin only)
- **Notifications** - In-app notification inbox

## Tech Stack

### Backend (`/backend`)
- Node.js + Express
- MongoDB (Mongoose)
- JWT authentication
- bcrypt password hashing

### Mobile (`/mobile`)
- Flutter 3.38.x
- Riverpod 3.3.x (state management)
- Dio (HTTP client)
- fl_chart (charts)
- share_plus (CSV export sharing)

## Getting Started

### Prerequisites
- Node.js 18+
- MongoDB (local or Atlas)
- Flutter 3.38+

### 1. Backend Setup
```bash
cd backend
npm install
cp .env.example .env   # edit with your MongoDB URI
npm run seed           # creates demo data
npm run dev            # starts on http://localhost:5000
```

### 2. Mobile Setup
```bash
cd mobile
flutter pub get
flutter run            # on an Android emulator
```

## Demo Accounts

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@muallimcarpets.com` | `Admin@123` |
| Shop 1 Manager | `ali@muallimcarpets.com` | `Manager@123` |
| Shop 2 Manager | `omar@muallimcarpets.com` | `Manager@123` |
| Shop 3 Manager | `bilal@muallimcarpets.com` | `Manager@123` |

## Testing

```bash
cd backend
npm run seed
node test-api.js       # runs 12 API integration tests
```
