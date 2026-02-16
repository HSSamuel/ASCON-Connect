# ASCON Alumni Backend API

The **ASCON Alumni Backend** is a robust RESTful API built with **Node.js** and **Express.js**. It serves as the central backend for the ASCON Alumni platform, handling authentication, user management, events, and real-time notifications for both the **Mobile App** and the **Web Admin Dashboard**.

---

## 🛠️ Tech Stack

* **Runtime:** Node.js
* **Framework:** Express.js
* **Database:** MongoDB (via Mongoose)
* **Authentication:** JWT (Access & Refresh Tokens) + Google OAuth
* **Notifications:** Firebase Cloud Messaging (FCM)
* **Email Service:** Brevo (formerly Sendinblue)
* **API Documentation:** Swagger UI

---

## 🚀 Getting Started

### 1. Prerequisites

Ensure you have the following installed:

* [Node.js](https://nodejs.org/) (v16 or higher)
* [MongoDB](https://www.mongodb.com/) (Local installation or MongoDB Atlas)

---

### 2. Installation

Navigate to the backend directory and install dependencies:

```bash
cd backend
npm install
```

---

### 3. Environment Configuration

Create a `.env` file in the root of the **backend** folder and add the following variables:

```env
# ------------------------------
# 🌍 SERVER & DATABASE
# ------------------------------
PORT=5000
DB_CONNECT=mongodb+srv://<username>:<password>@cluster.mongodb.net/....

# ------------------------------
# 🔐 SECURITY SECRETS
# ------------------------------
# Generate using: openssl rand -hex 32
JWT_SECRET=your_super_secure_access_token_secret
REFRESH_SECRET=your_super_secure_refresh_token_secret

# ------------------------------
# 📧 EMAIL SERVICE (Brevo)
# ------------------------------
EMAIL_USER=your_brevo_account_email
EMAIL_PASS=your_brevo_smtp_api_key

# ------------------------------
# ☁️ GOOGLE AUTHENTICATION
# ------------------------------
GOOGLE_CLIENT_ID=your_google_cloud_client_id.apps.googleusercontent.com
```

---

### 4. Running the Server

#### Development Mode (with Nodemon)

```bash
npm run dev
# or
npx nodemon server.js
```

#### Production Mode

```bash
npm start
```

---

## 📖 API Documentation

The API includes built-in **Swagger Documentation** for easy testing and exploration of endpoints.

* **Local:** [http://localhost:5000/api-docs](http://localhost:5000/api-docs)
* **Live:** [https://ascon.onrender.com/api-docs](https://ascon.onrender.com/api-docs)

---

## 📂 Project Structure

```plaintext
backend/
├── config/             # Third-party configurations (Firebase, Cloudinary)
├── controllers/        # Request handling logic (Auth, Events, Users)
├── models/             # Mongoose schemas (User, Event, Notification)
├── routes/             # API route definitions
├── utils/              # Helper utilities (Logger, Validators, Email)
├── server.js           # Application entry point
└── package.json        # Dependencies and scripts
```

---

## 🔐 Key Features

### 1. Secure Authentication

* **Dual Token System:**

  * Access Tokens (2 hours)
  * Refresh Tokens (30 days)

* **Hybrid Login:**

  * Email & Password authentication
  * Google Sign-In (OAuth)
  * Automatic account merging when emails match

---

### 2. Smart Notification System

* **Cap & Slice Token Management:**

  * Supports up to **5 active devices per user**
  * Automatically removes the oldest device token when a new one is added

* **Targeted Messaging:**

  * Broadcast notifications (all users)
  * Personal notifications (specific users)

---

### 3. Role-Based Access Control (RBAC)

* **isAdmin:** Full access to the Admin Dashboard
* **canEdit:** Permission-based editing (View-only vs Editor)
* **isVerified:** Restricts login access for unapproved alumni accounts

---

### 4. Digital Identity Generation

* Automatically generates a unique **Alumni ID** (e.g., `ASC/2025/0042`)
* Auto-incrementing logic based on graduation year
* Consistent formatting and uniqueness guaranteed

---

## ⚠️ Common Errors & Troubleshooting

### 503 Service Unavailable

* Server failed to start
* Ensure MongoDB IP Whitelist allows your connection

### Database Connection Failed

* Verify `DB_CONNECT` value in `.env`
* Ensure your IP is whitelisted in MongoDB Atlas

### Missing Environment Variables

* The server will crash if critical variables (e.g., `JWT_SECRET`) are missing
* Check console logs for **CRITICAL ERROR** messages

---

**© ASCON Alumni Platform – Backend API**
