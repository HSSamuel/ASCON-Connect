# ASCON Alumni Connect

ASCON Alumni Connect is a comprehensive platform designed to bridge the gap between the Administrative Staff College of Nigeria (ASCON) and its alumni network. It features a cross-platform mobile application for alumni, a web-based administration portal, and a robust Node.js backend.

---

## 🚀 Project Structure

The repository is organized into three main components:

- **ascon_mobile/**  
  Flutter-based mobile application (Android, iOS, Web) for alumni to connect, view events, and access the directory.

- **ascon_web_admin/**  
  React.js web portal for administrators to manage users, events, and system settings.

- **backend/**  
  Node.js & Express REST API powering both the mobile app and web admin, connected to a MongoDB database.

---

## 🛠 Tech Stack

### Mobile App

- Framework: Flutter (Dart)
- State Management: setState
- Authentication: JWT & Google Sign-In
- HTTP Client: http package
- Storage: shared_preferences

### Web Admin

- Framework: React.js
- Styling: CSS
- Routing: React Router

### Backend

- Runtime: Node.js
- Framework: Express.js
- Database: MongoDB (via Mongoose)
- Authentication: JSON Web Tokens (JWT) & Google OAuth
- Image Storage: Cloudinary

---

## 📋 Prerequisites

- Node.js
- Flutter SDK
- MongoDB (Atlas)
- Cloudinary account
- Google Cloud Console project

---

## 🔧 Setup & Installation

### Backend Setup

```bash
cd backend
npm install
npx nodemon server.js
```

Create a `.env` file:

```env
PORT=5000
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret_key
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
GOOGLE_CLIENT_ID=your_google_web_client_id
```

Start server:

```bash
npm start
```

---

### Mobile App Setup

```bash
cd ascon_mobile
flutter clean
flutter pub get
flutter run -d chrome
flutter run -d chrome --web-browser-flag "--disable-web-security"
flutter run -d chrome --web-port=5001
flutter build apk --release
```

---

### Web Admin Setup

```bash
cd ascon_web_admin
npm install
npm start
```

---

## 📱 Features

### Alumni

- Secure authentication
- Alumni directory
- Events & news
- Profile management

### Admins

- Dashboard overview
- User management
- Event management
- Broadcast notifications (planned)

---

## 📡 API Endpoints Overview

Method,Endpoint,Description,Access
POST,/api/auth/register,Create account,Public
POST,/api/auth/login,Login & get Token,Public
GET,/api/events,Fetch all events,Public
GET,/api/admin/users,List all users,Admin
PUT,/api/admin/users/:id/verify,Approve a user,Admin
POST,/api/admin/events,Create new event,Admin
POST,/api/admin/programmes,Add new course,Admin

## 🚀 Deployment

- Backend: Render
- Mobile: Flutter build for Android, iOS, Web
- Web Admin: Netlify

---

## 🤝 Contributing

Standard GitHub workflow with feature branches and pull requests.

---

## 📄 License

Proprietary software of the Administrative Staff College of Nigeria (ASCON).
Unauthorized use is prohibited.

---

## 📄 Persona

taskkill /F /IM java.exe

flutter build apk --release
flutter build appbundle
