"use client";

import { useState, useEffect, useRef } from "react";
import { db } from "@/lib/firebase-config";
import { 
  collection, 
  query, 
  orderBy, 
  onSnapshot,
  doc,
  updateDoc,
  serverTimestamp,
  addDoc
} from "firebase/firestore";
import { 
  FaComments, 
  FaPaperPlane, 
  FaMobileAlt,
  FaClock,
  FaUserCircle
} from "react-icons/fa";

interface ChatSession {
  id: string; // This is the deviceId
  deviceId: string;
  status: 'active' | 'closed';
  lastMessageAt: any;
  deviceModel?: string;
  messages?: ChatMessage[];
}

interface ChatMessage {
  id: string;
  sender: 'user' | 'admin';
  message: string;
  timestamp: any;
}

function ChatSessionItem({ 
  session, 
  isSelected, 
  onClick 
}: { 
  session: ChatSession; 
  isSelected: boolean; 
  onClick: () => void; 
}) {
  const [deviceStatus, setDeviceStatus] = useState<string>('offline');
  const [lastSeen, setLastSeen] = useState<any>(null);

  useEffect(() => {
    // Listen to device status and lastSeen
    const unsubscribe = onSnapshot(doc(db, "devices", session.deviceId), (doc) => {
      if (doc.exists()) {
        const data = doc.data();
        setDeviceStatus(data.status || 'offline');
        setLastSeen(data.lastSeen);
      }
    });
    return () => unsubscribe();
  }, [session.deviceId]);

  // Check if device is actually online based on lastSeen (heartbeat)
  // If lastSeen > 5 mins ago, consider offline even if status says 'online'
  let isOnline = deviceStatus === 'online' || deviceStatus === 'vpn_connected';
  
  if (lastSeen) {
    let lastSeenDate: Date;
    if (lastSeen.toDate) {
      lastSeenDate = lastSeen.toDate();
    } else if (lastSeen.seconds) {
      lastSeenDate = new Date(lastSeen.seconds * 1000);
    } else {
      lastSeenDate = new Date(); // Fallback
    }
    
    const diffMinutes = (new Date().getTime() - lastSeenDate.getTime()) / (1000 * 60);
    if (diffMinutes > 5) {
      isOnline = false; // Force offline if heartbeat lost
    }
  }

  const displayStatus = deviceStatus === 'vpn_connected' && isOnline ? 'VPN Connected' : (isOnline ? 'Online' : 'Offline');
  const statusColor = deviceStatus === 'vpn_connected' && isOnline ? 'bg-blue-500' : (isOnline ? 'bg-green-500' : 'bg-gray-400');

  return (
    <div 
      onClick={onClick}
      className={`p-4 border-b border-gray-100 cursor-pointer hover:bg-gray-50 dark:border-gray-800 dark:hover:bg-gray-800 ${isSelected ? 'bg-green-50 dark:bg-gray-800' : ''}`}
    >
      <div className="flex justify-between items-center mb-1">
        <span className="font-semibold text-sm truncate">{session.deviceModel || 'Unknown Device'}</span>
        <span className="text-xs text-gray-400">
          {session.lastMessageAt?.toDate ? session.lastMessageAt.toDate().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : ''}
        </span>
      </div>
      <div className="text-xs text-gray-500 truncate mb-1">ID: {session.deviceId.substring(0, 8)}...</div>
      <div className="flex items-center gap-1 text-xs text-gray-400">
          <div className={`w-2 h-2 rounded-full ${statusColor}`}></div>
          {displayStatus}
          {lastSeen && !isOnline && (
             <span className="text-[10px] ml-1">
               ({Math.floor((new Date().getTime() - (lastSeen.toDate ? lastSeen.toDate().getTime() : lastSeen.seconds * 1000)) / (1000 * 60))}m ago)
             </span>
          )}
      </div>
    </div>
  );
}

export default function LiveChatPage() {
  const [sessions, setSessions] = useState<ChatSession[]>([]);
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [replyMessage, setReplyMessage] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // 1. Listen to all chat sessions (sidebar)
  useEffect(() => {
    const q = query(collection(db, "live_chats"), orderBy("lastMessageAt", "desc"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const sessionList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as ChatSession));
      setSessions(sessionList);
    });
    return () => unsubscribe();
  }, []);

  // 2. Listen to messages for selected session
  useEffect(() => {
    if (!selectedSessionId) {
      setMessages([]);
      return;
    }

    // Live chat messages are stored in a 'messages' array field inside the document
    // We need to listen to the document itself
    const unsubscribe = onSnapshot(doc(db, "live_chats", selectedSessionId), (doc) => {
      if (doc.exists()) {
        const data = doc.data();
        setMessages(data.messages || []);
      }
    });

    return () => unsubscribe();
  }, [selectedSessionId]);

  // Scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSendMessage = async () => {
    if (!selectedSessionId || !replyMessage.trim()) return;

    try {
      const response = await fetch('/api/live-chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          deviceId: selectedSessionId,
          message: replyMessage
        }),
      });

      if (!response.ok) throw new Error('Failed to send');
      setReplyMessage("");
    } catch (error) {
      console.error("Error sending message:", error);
      alert("Failed to send message");
    }
  };

  const selectedSession = sessions.find(s => s.id === selectedSessionId);

  return (
    <div className="flex h-[calc(100vh-64px)] overflow-hidden bg-gray-50 dark:bg-gray-900">
      {/* Sidebar - Sessions */}
      <div className="w-1/4 min-w-[280px] border-r border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900 flex flex-col">
        <div className="p-4 border-b border-gray-200 dark:border-gray-800">
          <h2 className="text-xl font-bold flex items-center gap-2">
            <FaComments className="text-green-600" />
            Live Chat
          </h2>
        </div>
        <div className="flex-1 overflow-y-auto">
          {sessions.map(session => (
            <ChatSessionItem 
              key={session.id}
              session={session}
              isSelected={selectedSessionId === session.id}
              onClick={() => setSelectedSessionId(session.id)}
            />
          ))}
        </div>
      </div>

      {/* Chat Area */}
      <div className="flex-1 flex flex-col bg-gray-100 dark:bg-gray-950">
        {selectedSessionId ? (
          <>
            <div className="p-4 bg-white border-b border-gray-200 flex justify-between items-center dark:bg-gray-900 dark:border-gray-800">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center text-gray-500">
                  <FaUserCircle className="w-6 h-6" />
                </div>
                <div>
                  <div className="font-bold">{selectedSession?.deviceModel || 'Unknown Device'}</div>
                  <div className="text-xs text-gray-500">ID: {selectedSessionId}</div>
                </div>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {messages.map((msg, idx) => {
                const isAdmin = msg.sender === 'admin';
                return (
                  <div key={idx} className={`flex ${isAdmin ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-[70%] rounded-2xl px-4 py-2 ${
                      isAdmin 
                        ? 'bg-blue-600 text-white rounded-br-none' 
                        : 'bg-white text-gray-800 rounded-bl-none shadow-sm dark:bg-gray-800 dark:text-gray-200'
                    }`}>
                      <p>{msg.message}</p>
                      <div className={`text-[10px] mt-1 text-right ${isAdmin ? 'text-blue-200' : 'text-gray-400'}`}>
                        {/* Handle timestamp safely */}
                        {msg.timestamp?.seconds 
                          ? new Date(msg.timestamp.seconds * 1000).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
                          : 'Just now'
                        }
                      </div>
                    </div>
                  </div>
                )
              })}
              <div ref={messagesEndRef} />
            </div>

            <div className="p-4 bg-white border-t border-gray-200 dark:bg-gray-900 dark:border-gray-800">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={replyMessage}
                  onChange={(e) => setReplyMessage(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                  placeholder="Type a message..."
                  className="flex-1 border rounded-full px-4 py-2 focus:ring-2 focus:ring-blue-500 dark:bg-gray-800 dark:border-gray-700"
                />
                <button
                  onClick={handleSendMessage}
                  disabled={!replyMessage.trim()}
                  className="bg-blue-600 text-white p-3 rounded-full hover:bg-blue-700 disabled:opacity-50"
                >
                  <FaPaperPlane />
                </button>
              </div>
            </div>
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-gray-400">
            <FaComments className="text-6xl mb-4 text-gray-200" />
            <p>Select a chat session to start messaging</p>
          </div>
        )}
      </div>
    </div>
  );
}
