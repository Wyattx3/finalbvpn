// Firebase Client SDK for real-time updates in browser
import { initializeApp, getApps } from 'firebase/app';
import { 
  getFirestore, 
  collection, 
  onSnapshot, 
  query, 
  orderBy, 
  limit, 
  Timestamp,
  doc,
  getDocs,
  setDoc,
  deleteDoc,
  getDoc,
  updateDoc,
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyDQWQKLoDkYgghVpE8in35HmuyFWFwHHls",
  authDomain: "strategic-volt-341100.firebaseapp.com",
  projectId: "strategic-volt-341100",
  storageBucket: "strategic-volt-341100.firebasestorage.app",
  messagingSenderId: "890572946148",
  appId: "1:890572946148:web:b3ef65f3734c855129caf1",
  measurementId: "G-8HN9QCVF0S"
};

// Initialize Firebase (singleton pattern)
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
const db = getFirestore(app);

export { 
  db, 
  collection, 
  onSnapshot, 
  query, 
  orderBy, 
  limit, 
  Timestamp,
  doc,
  getDocs,
  setDoc,
  deleteDoc,
  getDoc,
  updateDoc,
};
export default app;

