# ASCON Alumni Association Platform

**ASCON Alumni** is the official digital platform for the Administrative Staff College of Nigeria (ASCON) Alumni. It bridges the gap between the institution and its graduates, providing Digital Identity, Networking, and Verification services.

## 🚀 Project Architecture

The project is a **Full-Stack Application** divided into three distinct parts:

| Folder                 | Tech Stack            | Description                                                                                   |
| :--------------------- | :-------------------- | :-------------------------------------------------------------------------------------------- |
| **`/ascon_mobile`**    | **Flutter (Dart)**    | The Android/iOS mobile app used by Alumni. Features Digital ID, News, and Profile Management. |
| **`/ascon_web_admin`** | **React.js**          | The Admin Portal for ASCON staff to Approve users, Post Events, and Verify IDs.               |
| **`/backend`**         | **Node.js & Express** | The central API connecting the App, Website, and MongoDB Database.                            |

---

## 🛠️ Setup Instructions

### 1. Backend API (The Brain)

_Located in `/backend`_

1.  Navigate to the folder: `cd backend`
2.  Install dependencies: `npm install`
3.  **Environment Variables:** Create a `.env` file in the `backend` folder with these keys:

    ```env
    # Database & Server
    DB_CONNECT = mongodb+srv://YOUR_MONGO_URL
    PORT = 5000

    # Security Secrets
    JWT_SECRET = your_super_secret_access_key
    REFRESH_SECRET = your_super_secret_refresh_key

    # Email Service (Brevo API)
    EMAIL_USER = your_brevo_account_email
    EMAIL_PASS = your_xkeysib_api_key_here

    # Google Auth
    GOOGLE_CLIENT_ID = your_google_client_id
    ```

4.  Start the server: `npm start`
5.  _Server runs on: `http://localhost:5000`_

### 2. Admin Portal (The Dashboard)

_Located in `/ascon_web_admin`_

1.  Navigate to the folder: `cd ascon_web_admin`
2.  Install dependencies: `npm install`
3.  **Configuration:** Ensure `.env` points to your backend:
    ```env
    REACT_APP_API_URL=http://localhost:5000
    # For Production: REACT_APP_API_URL=[https://ascon-st50.onrender.com](https://ascon-st50.onrender.com)
    ```
4.  Start the dashboard: `npm start`
5.  _Access at: `http://localhost:3000`_

### 3. Mobile App (The Client)

_Located in `/ascon_mobile`_

1.  Navigate to the folder: `cd ascon_mobile`
2.  Install packages: `flutter pub get`
3.  **Environment Configuration:**
    Create a `.env` file in the root of `ascon_mobile` to switch between Local and Production servers easily.

    ```

    ```

4.  **Run the app:** \* Development: `flutter run`
    - Web (CORS Disabled): `flutter run -d chrome --web-browser-flag "--disable-web-security"`
5.  **Build Release (Android):** `flutter build apk --release`
6.  **Build Release (iPhone):** `flutter build ios --release`

---

## 🔐 Key Features

### 1. Auto-Generated Digital ID

- **Logic:** Upon registration, every user is assigned a unique Alumni ID (e.g., `ASC/2025/0042`).
- **Visual:** The mobile app renders a realistic ID card with a QR Code.
- **Verification:** The QR Code links to `/verify/ASC-...` allowing security personnel to validate identity instantly without logging in.

### 2. Smart Notification System (FCM)

- **Hybrid Support:** Works for both Android (Push Notifications) and Web.
- **Token Management:** Implements a **"Cap & Slice"** strategy. Each user account stores up to 5 active devices. When a 6th device logs in, the oldest token is automatically removed to prevent database bloat.
- **Targeting:** Admins can send Broadcasts (to all) or Personal Messages (to specific users).

### 3. Role-Based Access Control (RBAC)

- **User:** View profile, events, and Digital ID.
- **Admin:** Approve users, post events, manage jobs.
- **Super Admin:** Manage other admins and edit sensitive data.
- **Security:** Protected via JWT Access Tokens (2h expiry) and Refresh Tokens (30d expiry).

### 4. Verification System

- New accounts are **Auto-Verified** for MVP speed.
- Admins can manually revoke verification or ban users via the Dashboard.
- **Unverified users** are blocked from logging in until approved.

---

## 📦 Deployment status

- **Backend:** Deployed on **Render** (Node.js Web Service).
  - _Note: Free tier spins down after 15 mins. First request may take 60s._
- **Admin Panel:** Deployed on **Netlify** (React Static Site).
- **Database:** Hosted on **MongoDB Atlas**.
- **Mobile App:** Built as `app-release.apk` for Android distribution.

---

## 🤝 Contribution

Developed by **[HUNSA S. Samuel]** for ASCON.
