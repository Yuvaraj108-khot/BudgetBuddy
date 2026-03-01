# CampusCash Backend API 🎓💰
> Smart Automatic Money Tracker for Students

A production-ready **Node.js + PostgreSQL** REST API backend for the CampusCash Flutter Android app.
Tracks student spending automatically via SMS, predicts budget shortages, scores financial discipline,
and provides smart rule-based insights — all without any paid AI service.

---

## 📋 Table of Contents

1. [Tech Stack](#tech-stack)
2. [Project Structure](#project-structure)
3. [Security Features](#security-features)
4. [Database Schema](#database-schema)
5. [Setup & Installation](#setup--installation)
6. [API Reference](#api-reference)
7. [Engine Details](#engine-details)
8. [SMS Parser](#sms-parser)
9. [Environment Variables](#environment-variables)
10. [How It All Works Together](#how-it-all-works-together)

---

## 🛠️ Tech Stack

| Technology | Version | What it does |
|---|---|---|
| **Node.js** | v18+ | JavaScript runtime for the server |
| **Express.js** | v4.18 | Web framework for building REST APIs |
| **PostgreSQL** | v14+ | Relational database for storing all data |
| **pg (node-postgres)** | v8.11 | Connects Node.js to PostgreSQL |
| **bcryptjs** | v2.4 | Hashes passwords and PINs securely |
| **jsonwebtoken** | v9.0 | Creates and verifies JWT access tokens |
| **express-validator** | v7 | Validates and sanitizes incoming request data |
| **helmet** | v7 | Sets secure HTTP headers |
| **cors** | v2.8 | Allows the Flutter app to communicate with the API |
| **morgan** | v1.10 | Logs all HTTP requests for debugging |
| **express-rate-limit** | v7 | Limits requests per IP to prevent brute-force |
| **dotenv** | v16 | Loads secrets from `.env` file |
| **nodemon** | v3 | Auto-restarts server during development |

---

## 📁 Project Structure

```
backend/
├── .env.example              ← Template for environment variables (safe to share)
├── .gitignore                ← Prevents .env and node_modules from being committed
├── package.json              ← Dependencies and npm scripts
├── README.md                 ← This file
│
└── src/
    ├── server.js             ← Express app: middleware, routes, server start
    │
    ├── config/
    │   └── db.js             ← PostgreSQL connection pool
    │
    ├── db/
    │   └── migrate.js        ← Creates all database tables (run once)
    │
    ├── models/
    │   └── index.js          ← All database queries (UserModel, TransactionModel, etc.)
    │
    ├── engines/
    │   ├── balanceEngine.js    ← Calculates income, expense, remaining balance
    │   ├── predictionEngine.js ← Predicts end-of-month spending
    │   ├── disciplineEngine.js ← Scores financial discipline (0–100)
    │   ├── insightEngine.js    ← Generates smart insights without AI
    │   ├── smsParser.js        ← Parses raw bank/UPI SMS to extract transactions
    │   └── smsParser.test.js   ← Test the SMS parser manually
    │
    ├── controllers/
    │   ├── authController.js         ← Register, Login, PIN lock, Logout
    │   ├── transactionController.js  ← Add, List, Delete transactions + SMS routes
    │   └── dashboardController.js    ← Full dashboard combining all engines
    │
    ├── routes/
    │   ├── auth.js           ← /api/auth/*
    │   ├── transactions.js   ← /api/transactions/*
    │   └── dashboard.js      ← /api/dashboard/*
    │
    └── middleware/
        └── index.js          ← JWT auth, PIN check, error handlers
```

---

## 🔐 Security Features

### 1. Password Security
- Passwords are **hashed with bcrypt** (cost factor 12) before storage — never stored in plain text
- Minimum 8 characters, must contain uppercase + number
- Password is **never returned** in any API response

### 2. Account Lockout (Phone Stolen Protection)
- After **5 failed login attempts** → account is locked for **30 minutes**
- After lockout, even the correct password won't work until the timer expires
- All login attempts (success/fail) are logged in the `security_logs` table

### 3. App PIN Lock 🔒 (Main Phone Stolen Protection)
- User can set a **4–6 digit numeric PIN** via `POST /api/auth/pin/set`
- The Flutter app checks the PIN every time the app opens or resumes
- PIN is **hashed with bcrypt** — never stored as plain text
- After **5 wrong PIN attempts** → PIN is locked for **10 minutes**
- Setting the PIN requires the account password (double confirmation)
- Changing or removing the PIN also requires the old PIN or password

### 4. JWT Tokens
- **Access token**: short-lived (1 day), used for all API requests
- **Refresh token**: stored as a bcrypt hash in the database, used to get new access tokens
- On logout, the refresh token is **invalidated immediately**

### 5. HTTP Security Headers
- `helmet` sets headers like `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`

### 6. Rate Limiting
- Max **100 requests per 15 minutes** per IP address
- Prevents brute-force attacks on login and PIN endpoints

### 7. Security Audit Log
- Every security event is recorded: logins, failures, lockouts, PIN events, logouts
- Stored in the `security_logs` table with timestamp and IP address

---

## 🗄️ Database Schema

### `users`
| Column | Type | Description |
|---|---|---|
| id | SERIAL PK | Auto-incrementing user ID |
| name | VARCHAR(100) | Full name |
| email | VARCHAR(150) UNIQUE | Login email |
| password_hash | VARCHAR(255) | bcrypt hash of password |
| phone | VARCHAR(20) | Optional phone number |
| pin_hash | VARCHAR(255) | bcrypt hash of app PIN (null = no PIN set) |
| failed_login_attempts | INT | Count of consecutive wrong passwords |
| locked_until | TIMESTAMP | Account unlock time (null = not locked) |
| failed_pin_attempts | INT | Count of consecutive wrong PINs |
| pin_locked_until | TIMESTAMP | PIN unlock time (null = not locked) |
| refresh_token_hash | VARCHAR(255) | bcrypt hash of current refresh token |
| created_at | TIMESTAMP | Account creation time |
| updated_at | TIMESTAMP | Last update time |

### `transactions`
| Column | Type | Description |
|---|---|---|
| id | SERIAL PK | Auto-incrementing |
| user_id | INT FK | References users.id |
| amount | NUMERIC(12,2) | Transaction amount in ₹ |
| type | VARCHAR(10) | `income` or `expense` |
| merchant_or_sender | VARCHAR(200) | Shop name or person name |
| category | VARCHAR(100) | Auto-detected category |
| source | VARCHAR(10) | `sms` or `manual` |
| note | TEXT | Optional user note |
| transaction_date | TIMESTAMP | When the transaction happened |
| raw_sms | TEXT | Original SMS text (for SMS transactions) |
| created_at | TIMESTAMP | When the record was saved |

### `budget_settings`
| Column | Type | Description |
|---|---|---|
| id | SERIAL PK | Auto-incrementing |
| user_id | INT FK | References users.id |
| month | INT | 1–12 |
| year | INT | e.g. 2026 |
| pocket_money | NUMERIC(12,2) | Monthly budget set by student |

### `security_logs`
| Column | Type | Description |
|---|---|---|
| id | SERIAL PK | Auto-incrementing |
| user_id | INT FK | References users.id |
| event | VARCHAR(50) | e.g. LOGIN_SUCCESS, PIN_FAILED, ACCOUNT_LOCKED |
| ip_address | VARCHAR(50) | IP of the request |
| detail | TEXT | Extra info |
| created_at | TIMESTAMP | When it happened |

---

## 🚀 Setup & Installation

### Prerequisites
- [Node.js](https://nodejs.org/) v18 or higher
- [PostgreSQL](https://www.postgresql.org/download/) v14 or higher

### Step 1 — Clone & install
```bash
# Navigate to the backend folder
cd backend

# Install all dependencies
npm install
```

### Step 2 — Create `.env` file
```bash
# Copy the example file
cp .env.example .env
```

Then open `.env` and fill in your values:
```env
PORT=3000
NODE_ENV=development
DB_HOST=localhost
DB_PORT=5432
DB_NAME=campuscash
DB_USER=postgres
DB_PASSWORD=your_actual_password
JWT_SECRET=a_long_random_string_at_least_32_chars
JWT_EXPIRES_IN=1d
```

> ⚠️ **NEVER commit `.env` to GitHub.** It's already in `.gitignore`.

### Step 3 — Create the PostgreSQL database
Open psql or pgAdmin and run:
```sql
CREATE DATABASE campuscash;
```

### Step 4 — Run migrations (creates all tables)
```bash
npm run db:migrate
```

### Step 5 — Start the server
```bash
npm run dev    # Development (auto-reloads on file change)
npm start      # Production
```

You should see:
```
✅ Connected to PostgreSQL database
🚀 CampusCash API running on port 3000
```

### Step 6 — Test it works
```bash
curl http://localhost:3000/health
```
Should return:
```json
{ "success": true, "service": "CampusCash API", "version": "1.0.0" }
```

---

## 🔌 API Reference

> All protected routes require: `Authorization: Bearer <access_token>`

### Auth Routes `/api/auth`

| Method | Endpoint | Auth | Body | Description |
|---|---|---|---|---|
| POST | `/register` | ❌ | `name, email, password, phone` | Create account |
| POST | `/login` | ❌ | `email, password` | Login, returns tokens |
| GET | `/me` | ✅ | — | Get current user info |
| POST | `/logout` | ✅ | — | Invalidate refresh token |
| POST | `/pin/set` | ✅ | `pin, current_password` | Set app PIN lock |
| POST | `/pin/verify` | ✅ | `pin` | Verify PIN on app open |
| POST | `/pin/change` | ✅ | `old_pin, pin` | Change existing PIN |
| DELETE | `/pin` | ✅ | `current_password` | Remove PIN lock |

#### Example: Register
```json
POST /api/auth/register
{
  "name": "Yuvaraj",
  "email": "yuvaraj@example.com",
  "password": "MyPass123",
  "phone": "9876543210"
}
```

#### Example: Set PIN
```json
POST /api/auth/pin/set
Authorization: Bearer <token>
{
  "pin": "1234",
  "current_password": "MyPass123"
}
```

---

### Transaction Routes `/api/transactions`

| Method | Endpoint | Body | Description |
|---|---|---|---|
| POST | `/` | `amount, type, merchant_or_sender, category, source, note, transaction_date` | Manual add |
| POST | `/parse-sms` | `raw_sms` | Parse SMS, return structured data for confirmation popup |
| POST | `/from-sms` | `raw_sms, transaction_date` | Parse SMS and auto-save |
| GET | `/?month=3&year=2026` | — | List transactions for month |
| DELETE | `/:id` | — | Delete a transaction |

#### Example: Parse SMS
```json
POST /api/transactions/parse-sms
{
  "raw_sms": "Rs.150 debited from A/c XX1234. Info: UPI/Campus Canteen. Avl bal: Rs.850"
}
```
Response:
```json
{
  "success": true,
  "is_transaction": true,
  "confidence": "high",
  "parsed": {
    "amount": 150,
    "type": "expense",
    "merchant_or_sender": "Campus Canteen",
    "category": "Food & Dining",
    "balance_after": 850,
    "source": "sms"
  }
}
```

---

### Dashboard Routes `/api/dashboard`

| Method | Endpoint | Description |
|---|---|---|
| GET | `/?month=3&year=2026` | Full dashboard (all engines combined) |
| POST | `/budget` | Set pocket money: `{ month, year, pocket_money }` |
| GET | `/merchants?month=3&year=2026` | Merchant spend breakdown |

#### Dashboard Response Fields
```json
{
  "balance":    { "total_income", "total_expense", "remaining", "daily_safe_limit", "budget_usage_pct" },
  "prediction": { "avg_daily_spend", "predicted_total_spend", "will_exceed_budget", "projected_shortfall" },
  "discipline": { "score", "rank", "deductions", "bonuses" },
  "insights":   { "insights": [...], "warning": "...", "suggestion": "..." },
  "merchants":  [{ "merchant_or_sender", "total_spent", "visit_count", "avg_per_visit", "pct_of_budget" }],
  "categories": [{ "category", "total_spent", "count" }],
  "recent_transactions": [...]
}
```

---

## ⚙️ Engine Details

### Balance Engine (`balanceEngine.js`)
**Formula:**
```
total_income  = pocket_money + income_transactions
remaining     = total_income - total_expense
daily_limit   = remaining / days_left_in_month
budget_usage  = (total_expense / total_income) × 100
```

### Prediction Engine (`predictionEngine.js`)
**Formula:**
```
avg_daily_spend       = total_spent_so_far / days_passed
predicted_total_spend = avg_daily_spend × 30
will_exceed           = predicted_total_spend > total_income
```

### Discipline Score Engine (`disciplineEngine.js`)
**Base score: 80**
| Rule | Points |
|---|---|
| Predicted to exceed budget | −20 |
| One merchant > 50% of spending | −10 |
| One category > 50% of spending | −10 |
| Savings ratio > 20% | +10 |
| Daily spend under safe limit | +5 |

**Score labels:**
- 80–100 → Excellent 🌟
- 60–79 → Good 👍
- 40–59 → Fair ⚠️
- 0–39 → At Risk 🚨

### Insight Engine (`insightEngine.js`)
Generates **3 insights + 1 warning + 1 suggestion** using pure if/else logic — no paid AI.
- Insight 1: Top merchant spending pattern
- Insight 2: Top category spending pattern
- Insight 3: Daily pace vs safe daily limit
- Warning: Budget overrun alert (if applicable)
- Suggestion: Specific actionable recommendation

---

## 📱 SMS Parser

**File:** `src/engines/smsParser.js`

Parses common Indian bank/UPI SMS formats:
- PhonePe, GPay, Paytm, BHIM UPI alerts
- HDFC, SBI, ICICI, Axis, Kotak SMS alerts
- Debit/credit card transaction alerts

**What it extracts:**
| Field | How |
|---|---|
| `amount` | Regex: `Rs./INR/₹ + number` |
| `type` | Keywords: `debited/sent/paid` → expense; `credited/received` → income |
| `merchant_or_sender` | Regex: `to <name>` (expense) or `from <name>` (income) |
| `category` | Keyword matching against 9 categories |
| `balance_after` | Regex: `Avl bal: Rs.XXX` |
| `confidence` | `high` if all fields found, `medium` if merchant unknown |

**Auto-skips:**
- OTP messages (`Your OTP is...`)
- Promotional messages (`Cashback offer...`)
- Non-transaction messages

**Test the parser:**
```bash
node src/engines/smsParser.test.js
```

---

## 🌍 Environment Variables

| Variable | Required | Description | Example |
|---|---|---|---|
| `PORT` | No | Server port (default: 3000) | `3000` |
| `NODE_ENV` | No | `development` or `production` | `development` |
| `DB_HOST` | ✅ | PostgreSQL host | `localhost` |
| `DB_PORT` | No | PostgreSQL port (default: 5432) | `5432` |
| `DB_NAME` | ✅ | Database name | `campuscash` |
| `DB_USER` | ✅ | PostgreSQL username | `postgres` |
| `DB_PASSWORD` | ✅ | PostgreSQL password | `yourpassword` |
| `JWT_SECRET` | ✅ | Secret key for JWT signing (min 32 chars) | `a-long-random-string` |
| `JWT_EXPIRES_IN` | No | Access token expiry | `1d` |

---

## 🔄 How It All Works Together

```
📱 Student's Android Phone
│
├── New SMS arrives (bank/UPI)
│   └── Flutter reads SMS (READ_SMS permission)
│       └── POST /api/transactions/parse-sms (sends raw SMS)
│           └── smsParser.js extracts: amount, type, merchant
│               └── App shows confirmation popup to user
│                   └── User taps "Save" → POST /api/transactions (saved!)
│
├── App opens / resumes from background
│   └── If PIN is set → show PIN screen
│       └── POST /api/auth/pin/verify
│           ├── Correct PIN → open app ✅
│           └── Wrong PIN × 5 → locked 10 mins 🔒
│
└── Dashboard loads
    └── GET /api/dashboard
        ├── BalanceEngine → remaining money, daily limit
        ├── PredictionEngine → will I run out this month?
        ├── DisciplineEngine → score 0-100
        └── InsightEngine → 3 insights + warning + tip
```

---

## 📦 npm Scripts

| Script | Command | Description |
|---|---|---|
| `npm run dev` | `nodemon src/server.js` | Start with auto-reload |
| `npm start` | `node src/server.js` | Start production server |
| `npm run db:migrate` | `node src/db/migrate.js` | Create all database tables |

---

## 👤 Author
**Yuvaraj Khot**
Project: CampusCash — Smart Student Money Tracker
