importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts(
  "https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js"
);

firebase.initializeApp({
  apiKey: "AIzaSyBBteJZoirarB77b3Cgo67njG6meoGNq_U",
  authDomain: "ascon-alumni-91df2.firebaseapp.com",
  projectId: "ascon-alumni-91df2",
  storageBucket: "ascon-alumni-91df2.firebasestorage.app",
  messagingSenderId: "826004672204",
  appId: "1:826004672204:web:4352aaeba03118fb68fc69",
});

const messaging = firebase.messaging();
