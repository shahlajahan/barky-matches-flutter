/* Firebase Cloud Messaging service worker for the PetSupo Web app. */
importScripts(
  'https://www.gstatic.com/firebasejs/12.3.0/firebase-app-compat.js',
  'https://www.gstatic.com/firebasejs/12.3.0/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyAgrDy5XULhjwxMOsfGWuHdo5hNiepSQjg',
  authDomain: 'app.petsupo.com',
  projectId: 'barkymatches-new',
  storageBucket: 'barkymatches-new.firebasestorage.app',
  messagingSenderId: '188282684447',
  appId: '1:188282684447:web:2e04b07cfdc75dcc53412a',
});

firebase.messaging();
