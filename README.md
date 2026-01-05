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
    DB_CONNECT = mongodb+srv://YOUR_MONGO_URL
    JWT_SECRET = your_super_secret_key_123
    PORT = 5000

    # Email Service (Brevo API)
    EMAIL_USER = your_brevo_account_email
    EMAIL_PASS = your_xkeysib_api_key_here

    # Google Auth (Optional)
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
    ```
4.  Start the dashboard: `npm start`
5.  _Access at: `http://localhost:3000`_

### 3. Mobile App (The Client)

_Located in `/ascon_mobile`_

1.  Navigate to the folder: `cd ascon_mobile`
2.  Install packages: `flutter pub get`

3.  **API Connection:**
    - Open `lib/config.dart` (or `auth_service.dart`) and ensure `baseUrl` matches your backend.
    - _For Emulator:_ Use `http://10.0.2.2:5000`
    - _For Real Device:_ Use your Render/Heroku URL.
4.  Run the app: `flutter run`
5.  Run the app: `flutter run -d chrome`
6.  Clean the project: `flutter clean`
7.  Build the Release APK: `flutter build apk -- release`
8.  Build the Release APK: `flutter run -d chrome --web-browser-flag "--disable-web-security"`

---

## 🔐 Key Features

### 1. Auto-Generated Digital ID

- **Logic:** Upon registration, every user is automatically assigned a unique Alumni ID (e.g., `ASC/2025/0042`).
- **Visual:** The mobile app renders a realistic ID card with a QR Code.
- **Security:** The QR Code contains a secure verification link (`/verify/ASC-...`) that cannot be faked.

### 2. Role-Based Access Control (RBAC)

- **User:** Can view profile, news, and Digital ID.
- **Admin:** Can view user lists and approve requests.
- **Super Admin:** Can manage other admins and edit core data.
- _Security:_ Backend routes are protected via JWT Tokens.

### 3. Verification System

- New accounts are **Auto-Verified** (for MVP speed) but can be set to "Pending" in `auth.js` if stricter control is needed.
- Admins can manually revoke verification or ban users via the Dashboard.

---

## 📦 Deployment

- **Backend:** Deployed on **Render** (Node.js Web Service).
- **Admin Panel:** Deployed on **Netlify** (React Static Site).
- **Database:** Hosted on **MongoDB Atlas**.
- **Mobile App:** Built as `app-release.apk` for Android distribution.

---

## 🤝 Contribution

Developed by **[HUNSA S. Samuel]** for ASCON.
