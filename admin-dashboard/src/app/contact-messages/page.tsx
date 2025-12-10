"use client";

import { useState, useEffect } from "react";
import { db } from "@/lib/firebase-config";
import { 
  collection, 
  query, 
  orderBy, 
  onSnapshot,
  doc,
  updateDoc,
  serverTimestamp,
  where
} from "firebase/firestore";
import { 
  FaEnvelope, 
  FaSearch, 
  FaReply, 
  FaCheck, 
  FaMobileAlt,
  FaClock,
  FaUser
} from "react-icons/fa";

interface ContactMessage {
  id: string;
  deviceId: string;
  deviceModel: string;
  email?: string;
  category: string;
  subject: string;
  message: string;
  status: 'pending' | 'replied' | 'resolved';
  createdAt: any;
  replies?: any[];
}

export default function ContactMessagesPage() {
  const [messages, setMessages] = useState<ContactMessage[]>([]);
  const [selectedMessage, setSelectedMessage] = useState<ContactMessage | null>(null);
  const [loading, setLoading] = useState(true);
  const [replyMessage, setReplyMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [filter, setFilter] = useState<'all' | 'pending' | 'resolved'>('all');

  // Real-time listener
  useEffect(() => {
    const q = query(collection(db, "contact_messages"), orderBy("createdAt", "desc"));
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const msgList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as ContactMessage));
      setMessages(msgList);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleStatusUpdate = async (id: string, newStatus: string) => {
    try {
      await updateDoc(doc(db, "contact_messages", id), { status: newStatus });
    } catch (error) {
      console.error("Error updating status:", error);
    }
  };

  const handleSendReply = async () => {
    if (!selectedMessage || !replyMessage.trim()) return;
    
    if (!selectedMessage.email) {
      alert("Cannot send email - user did not provide an email address. Reply will be saved to database only.");
    }
    
    setSending(true);
    try {
      // API call to send email
      const response = await fetch('/api/contact-messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messageId: selectedMessage.id,
          replyMessage: replyMessage,
          recipientEmail: selectedMessage.email
        }),
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Failed to send reply');
      }

      setReplyMessage("");
      
      if (data.emailSent) {
        alert(`✅ Reply sent successfully to ${selectedMessage.email}`);
      } else {
        alert("⚠️ Reply saved to database. Email could not be sent (check console for details).");
      }
    } catch (error: any) {
      console.error("Error sending reply:", error);
      alert(`Failed to send reply: ${error.message || 'Unknown error'}`);
    } finally {
      setSending(false);
    }
  };

  const filteredMessages = messages.filter(msg => {
    if (filter === 'pending') return msg.status === 'pending';
    if (filter === 'resolved') return msg.status === 'resolved';
    return true;
  });

  if (loading) return <div className="p-8 text-center">Loading messages...</div>;

  return (
    <div className="flex h-[calc(100vh-64px)] overflow-hidden bg-gray-50 dark:bg-gray-900">
      {/* Sidebar List */}
      <div className="w-1/3 min-w-[320px] border-r border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900 flex flex-col">
        <div className="p-4 border-b border-gray-200 dark:border-gray-800">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold flex items-center gap-2">
              <FaEnvelope className="text-purple-600" />
              Contact Messages
            </h2>
            <div className="flex gap-2">
              <button onClick={() => setFilter('all')} className={`px-2 py-1 text-xs rounded ${filter === 'all' ? 'bg-purple-100 text-purple-700' : 'text-gray-500'}`}>All</button>
              <button onClick={() => setFilter('pending')} className={`px-2 py-1 text-xs rounded ${filter === 'pending' ? 'bg-yellow-100 text-yellow-700' : 'text-gray-500'}`}>Pending</button>
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {filteredMessages.map(msg => (
            <div 
              key={msg.id}
              onClick={() => setSelectedMessage(msg)}
              className={`p-4 border-b border-gray-100 cursor-pointer hover:bg-gray-50 dark:border-gray-800 dark:hover:bg-gray-800 ${selectedMessage?.id === msg.id ? 'bg-purple-50 dark:bg-gray-800' : ''}`}
            >
              <div className="flex justify-between items-start mb-1">
                <span className="font-semibold truncate flex-1">{msg.subject}</span>
                <span className={`text-xs px-2 py-0.5 rounded-full ${
                  msg.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 
                  msg.status === 'replied' ? 'bg-blue-100 text-blue-800' : 
                  'bg-green-100 text-green-800'
                }`}>
                  {msg.status}
                </span>
              </div>
              <div className="text-xs text-gray-500 mb-1 flex items-center gap-1">
                <FaClock className="w-3 h-3" />
                {msg.createdAt?.toDate().toLocaleString()}
              </div>
              <div className="text-xs text-gray-500 truncate">{msg.email || msg.deviceId}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Details View */}
      <div className="flex-1 flex flex-col bg-white dark:bg-gray-900">
        {selectedMessage ? (
          <>
            <div className="p-6 border-b border-gray-200 dark:border-gray-800 bg-gray-50 dark:bg-gray-900">
              <div className="flex justify-between items-start">
                <div>
                  <h1 className="text-2xl font-bold mb-2">{selectedMessage.subject}</h1>
                  <div className="flex flex-wrap gap-4 text-sm text-gray-600 dark:text-gray-400">
                    <div className="flex items-center gap-2">
                      <FaUser className="text-gray-400" />
                      <span>{selectedMessage.email || 'No email provided'}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <FaMobileAlt className="text-gray-400" />
                      <span>{selectedMessage.deviceModel} ({selectedMessage.deviceId.substring(0, 8)}...)</span>
                    </div>
                    <div className="bg-gray-200 px-2 py-0.5 rounded text-xs">
                      {selectedMessage.category}
                    </div>
                  </div>
                </div>
                
                <div className="flex gap-2">
                   {selectedMessage.status !== 'resolved' && (
                     <button 
                       onClick={() => handleStatusUpdate(selectedMessage.id, 'resolved')}
                       className="flex items-center gap-1 px-3 py-1 bg-green-100 text-green-700 rounded hover:bg-green-200"
                     >
                       <FaCheck /> Mark Resolved
                     </button>
                   )}
                </div>
              </div>
            </div>

            <div className="flex-1 p-6 overflow-y-auto">
              <div className="bg-white p-4 rounded-lg border border-gray-200 shadow-sm mb-6 dark:bg-gray-800 dark:border-gray-700">
                <p className="whitespace-pre-wrap">{selectedMessage.message}</p>
              </div>

              {selectedMessage.replies && selectedMessage.replies.length > 0 && (
                <div className="mb-6">
                  <h3 className="font-bold mb-3 text-gray-500 uppercase text-xs">Previous Replies</h3>
                  <div className="space-y-4">
                    {selectedMessage.replies.map((reply, idx) => (
                      <div key={idx} className="bg-blue-50 p-4 rounded-lg border border-blue-100 ml-8 dark:bg-gray-800 dark:border-gray-700">
                        <div className="text-xs text-blue-600 mb-1 font-bold">Admin Reply</div>
                        <p className="whitespace-pre-wrap text-sm">{reply.message}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>

            <div className="p-4 border-t border-gray-200 bg-gray-50 dark:border-gray-800 dark:bg-gray-900">
              <div className="mb-2 text-sm font-medium flex items-center gap-2">
                <FaReply /> Reply via Email {selectedMessage.email ? `to ${selectedMessage.email}` : '(No email provided)'}
              </div>
              <textarea
                value={replyMessage}
                onChange={(e) => setReplyMessage(e.target.value)}
                placeholder={selectedMessage.email ? "Type your reply..." : "Cannot reply - no email provided by user."}
                disabled={!selectedMessage.email}
                className="w-full p-3 border rounded-lg h-32 mb-2 focus:ring-2 focus:ring-purple-500 dark:bg-gray-800 dark:border-gray-700"
              />
              <div className="flex justify-end">
                <button
                  onClick={handleSendReply}
                  disabled={sending || !replyMessage.trim() || !selectedMessage.email}
                  className="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {sending ? 'Sending...' : 'Send Reply'}
                </button>
              </div>
            </div>
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-gray-400">
            <FaEnvelope className="text-6xl mb-4 text-gray-200" />
            <p>Select a message to view</p>
          </div>
        )}
      </div>
    </div>
  );
}
