# CampusCash Backend API 🎓💰

Smart automatic money tracker for students — Node.js + PostgreSQL backend.

## 📁 Project Structure

```
backend/
├── src/
│   ├── server.js              # Express app entry point
│   ├── config/
│   │   └── db.js              # PostgreSQL pool connection
│   ├── db/
│   │   └── migrate.js         # Database migration script
│   ├── models/
│   │   └── index.js           # TransactionModel, BudgetModel, UserModel
│   ├── engines/
│   │   ├── balanceEngine.js   # Monthly balance calculator
│   │   ├── predictionEngine.js# Spending prediction (avg daily spend × 30)
│   │   ├── disciplineEngine.js# Discipline score (0–100)
│   │   └── insightEngine.js   # Rule-based smart insights (no paid AI)
│   ├── controllers/
│   │   ├── authController.js  # Register / Login / Me
│   │   ├── transactionController.js # CRUD for transactions
│   │   └── dashboardController.js   # Full dashboard aggregation
│   ├── routes/
│   │   ├── auth.js
│   │   ├── transactions.js
│   │   └── dashboard.js
│   └── middleware/
│       └── index.js           # JWT auth + error handlers
└── package.json
```

## 🚀 Setup

### 1. Install dependencies
```bash
cd backend
npm install
```

### 2. Configure environment
```bash
cp .env.example .env
# Edit .env with your PostgreSQL credentials and JWT secret
```

### 3. Create PostgreSQL database
```sql
CREATE DATABASE campuscash;
```

### 4. Run migrations
```bash
npm run db:migrate
```

### 5. Start server
```bash
npm run dev   # development (with auto-reload)
npm start     # production
```

## 🔌 API Endpoints

### Auth
| Method | Endpoint            | Description        |
|--------|---------------------|--------------------|
| POST   | /api/auth/register  | Create new account |
| POST   | /api/auth/login     | Login              |
| GET    | /api/auth/me        | Get current user   |

### Transactions
| Method | Endpoint                | Description                |
|--------|-------------------------|----------------------------|
| POST   | /api/transactions       | Add transaction (SMS/manual)|
| GET    | /api/transactions       | List by month/year         |
| DELETE | /api/transactions/:id   | Delete transaction         |

### Dashboard
| Method | Endpoint                    | Description                        |
|--------|-----------------------------|------------------------------------|
| GET    | /api/dashboard              | Full dashboard (all engines)       |
| POST   | /api/dashboard/budget       | Set pocket money for the month     |
| GET    | /api/dashboard/merchants    | Merchant spend breakdown           |

## 🧠 Engines

| Engine            | What it does                                          |
|-------------------|-------------------------------------------------------|
| Balance Engine    | Calculates income, expense, remaining & daily limit   |
| Prediction Engine | Predicts end-of-month spend using daily average       |
| Discipline Engine | Scores student 0–100 on financial discipline          |
| Insight Engine    | Generates 3 insights + 1 warning + 1 suggestion      |

## 🔐 Authentication
All `/api/transactions` and `/api/dashboard` routes require:
```
Authorization: Bearer <your_jwt_token>
```
