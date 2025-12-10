// Import the functions you need from the SDKs you need
import { initializeApp, getApps, getApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBE4E5PkSINjKQps303Up_kJvDC7Bzp2P4",
  authDomain: "strategic-volt-341100.firebaseapp.com",
  projectId: "strategic-volt-341100",
  storageBucket: "strategic-volt-341100.firebasestorage.app",
  messagingSenderId: "890572946148",
  appId: "1:890572946148:web:placeholder" // You should replace this with your actual Web App ID from Firebase Console
};

// Initialize Firebase
const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);

export { db, auth };

