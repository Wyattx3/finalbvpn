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
  addDoc
} from "firebase/firestore";
import { 
  FaInbox, 
  FaPaperPlane, 
  FaSearch, 
  FaReply, 
  FaStar, 
  FaTrash,
  FaEnvelopeOpen,
  FaEnvelope,
  FaPaperclip
} from "react-icons/fa";

interface Email {
  id: string;
  from: string;
  fromFull?: string;
  to?: string;
  subject: string;
  body: string;
  htmlBody?: string;
  receivedAt: any;
  status: 'unread' | 'read' | 'replied';
  isStarred?: boolean;
  attachmentCount?: number;
}

export default function EmailsPage() {
  const [emails, setEmails] = useState<Email[]>([]);
  const [selectedEmail, setSelectedEmail] = useState<Email | null>(null);
  const [loading, setLoading] = useState(true);
  const [replyMessage, setReplyMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [filter, setFilter] = useState<'all' | 'unread' | 'starred'>('all');

  // Real-time listener for emails
  useEffect(() => {
    const q = query(collection(db, "email_inbox"), orderBy("receivedAt", "desc"));
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const emailList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Email));
      setEmails(emailList);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching emails:", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleSelectEmail = async (email: Email) => {
    setSelectedEmail(email);
    if (email.status === 'unread') {
      try {
        await updateDoc(doc(db, "email_inbox", email.id), { status: 'read' });
      } catch (error) {
        console.error("Error marking email as read:", error);
      }
    }
  };

  const handleSendReply = async () => {
    if (!selectedEmail || !replyMessage.trim()) return;
    
    setSending(true);
    try {
      const response = await fetch('/api/emails/reply', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          originalEmailId: selectedEmail.id,
          to: selectedEmail.from,
          subject: selectedEmail.subject,
          message: replyMessage
        }),
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Failed to send email');
      }

      await updateDoc(doc(db, "email_inbox", selectedEmail.id), { 
        status: 'replied',
        lastReplyAt: serverTimestamp()
      });

      await addDoc(collection(db, "email_sent"), {
        to: selectedEmail.from,
        subject: `Re: ${selectedEmail.subject}`,
        body: replyMessage,
        sentAt: serverTimestamp(),
        replyToId: selectedEmail.id
      });

      setReplyMessage("");
      alert("✅ Reply sent successfully!");
    } catch (error: any) {
      console.error("Error sending reply:", error);
      alert(`❌ Failed to send reply: ${error.message}`);
    } finally {
      setSending(false);
    }
  };

  const formatDate = (timestamp: any) => {
    if (!timestamp) return '';
    try {
      const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
      const now = new Date();
      const diff = now.getTime() - date.getTime();
      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      
      if (days === 0) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      } else if (days === 1) {
        return 'Yesterday';
      } else if (days < 7) {
        return date.toLocaleDateString([], { weekday: 'short' });
      } else {
        return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
      }
    } catch {
      return '';
    }
  };

  const formatFullDate = (timestamp: any) => {
    if (!timestamp) return '';
    try {
      const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
      return date.toLocaleString();
    } catch {
      return '';
    }
  };

  const getEmailContent = (email: Email) => {
    // Try to get content from body or htmlBody
    if (email.body && email.body.trim()) {
      return email.body;
    }
    if (email.htmlBody && email.htmlBody.trim()) {
      // Strip HTML tags for plain text display
      return email.htmlBody.replace(/<[^>]*>/g, '').trim() || '(No content)';
    }
    return '(No content)';
  };

  const filteredEmails = emails.filter(email => {
    if (filter === 'unread') return email.status === 'unread';
    if (filter === 'starred') return email.isStarred;
    return true;
  });

  if (loading) return <div className="p-8 text-center">Loading inbox...</div>;

  return (
    <div className="flex h-[calc(100vh-64px)] overflow-hidden bg-gray-100 dark:bg-gray-900">
      {/* Email List Sidebar */}
      <div className="w-[400px] min-w-[350px] border-r border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-800 flex flex-col shadow-sm">
        {/* Header */}
        <div className="p-4 border-b border-gray-200 dark:border-gray-700 bg-gradient-to-r from-blue-600 to-blue-700">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-xl font-bold flex items-center gap-2 text-white">
              <FaInbox />
              Inbox
              {emails.filter(e => e.status === 'unread').length > 0 && (
                <span className="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">
                  {emails.filter(e => e.status === 'unread').length}
                </span>
              )}
            </h2>
          </div>
          <div className="flex gap-2">
            <button 
              onClick={() => setFilter('all')}
              className={`px-3 py-1 text-xs rounded-full transition ${
                filter === 'all' 
                  ? 'bg-white text-blue-700 font-medium' 
                  : 'bg-blue-500 text-white hover:bg-blue-400'
              }`}
            >
              All ({emails.length})
            </button>
            <button 
              onClick={() => setFilter('unread')}
              className={`px-3 py-1 text-xs rounded-full transition ${
                filter === 'unread' 
                  ? 'bg-white text-blue-700 font-medium' 
                  : 'bg-blue-500 text-white hover:bg-blue-400'
              }`}
            >
              Unread ({emails.filter(e => e.status === 'unread').length})
            </button>
          </div>
        </div>

        {/* Search */}
        <div className="p-3 border-b border-gray-100 dark:border-gray-700">
          <div className="relative">
            <FaSearch className="absolute left-3 top-3 text-gray-400 text-sm" />
            <input 
              type="text" 
              placeholder="Search emails..." 
              className="w-full pl-9 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-700 dark:border-gray-600"
            />
          </div>
        </div>

        {/* Email List */}
        <div className="flex-1 overflow-y-auto">
          {filteredEmails.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <FaInbox className="text-4xl mx-auto mb-4 text-gray-300" />
              <p className="font-medium">No emails</p>
              <p className="text-xs mt-1">Emails to support@sukfhyoke.com will appear here</p>
            </div>
          ) : (
            filteredEmails.map(email => (
              <div 
                key={email.id}
                onClick={() => handleSelectEmail(email)}
                className={`p-4 border-b border-gray-100 cursor-pointer transition-all hover:bg-blue-50 dark:border-gray-700 dark:hover:bg-gray-700 ${
                  selectedEmail?.id === email.id 
                    ? 'bg-blue-50 border-l-4 border-l-blue-500 dark:bg-gray-700' 
                    : ''
                } ${email.status === 'unread' ? 'bg-white dark:bg-gray-800' : 'bg-gray-50 dark:bg-gray-800/50'}`}
              >
                <div className="flex items-start gap-3">
                  {/* Status Icon */}
                  <div className={`mt-1 ${email.status === 'unread' ? 'text-blue-500' : 'text-gray-400'}`}>
                    {email.status === 'unread' ? <FaEnvelope /> : <FaEnvelopeOpen />}
                  </div>
                  
                  {/* Email Content */}
                  <div className="flex-1 min-w-0">
                    <div className="flex justify-between items-start mb-1">
                      <span className={`truncate ${email.status === 'unread' ? 'font-semibold text-gray-900 dark:text-white' : 'text-gray-700 dark:text-gray-300'}`}>
                        {email.from}
                      </span>
                      <span className="text-xs text-gray-500 ml-2 whitespace-nowrap">
                        {formatDate(email.receivedAt)}
                      </span>
                    </div>
                    <div className={`text-sm truncate mb-1 ${email.status === 'unread' ? 'font-medium text-gray-800 dark:text-gray-200' : 'text-gray-600 dark:text-gray-400'}`}>
                      {email.subject || '(No Subject)'}
                    </div>
                    <div className="text-xs text-gray-500 truncate">
                      {getEmailContent(email).substring(0, 80)}...
                    </div>
                    {/* Status Badge */}
                    <div className="flex items-center gap-2 mt-2">
                      {email.status === 'replied' && (
                        <span className="text-[10px] px-2 py-0.5 bg-green-100 text-green-700 rounded-full">
                          Replied
                        </span>
                      )}
                      {email.attachmentCount && email.attachmentCount > 0 && (
                        <span className="text-gray-400 flex items-center gap-1 text-[10px]">
                          <FaPaperclip /> {email.attachmentCount}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Email Detail View */}
      <div className="flex-1 flex flex-col bg-white dark:bg-gray-900">
        {selectedEmail ? (
          <>
            {/* Email Header */}
            <div className="p-6 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
              <div className="flex justify-between items-start mb-4">
                <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
                  {selectedEmail.subject || '(No Subject)'}
                </h1>
                <div className="flex gap-2">
                  <button className="p-2 text-gray-400 hover:text-yellow-500 transition">
                    <FaStar />
                  </button>
                  <button className="p-2 text-gray-400 hover:text-red-500 transition">
                    <FaTrash />
                  </button>
                </div>
              </div>
              
              <div className="flex items-center gap-4">
                {/* Avatar */}
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white text-lg font-bold shadow">
                  {(selectedEmail.from || 'U')[0].toUpperCase()}
                </div>
                
                {/* Sender Info */}
                <div className="flex-1">
                  <div className="font-semibold text-gray-900 dark:text-white">
                    {selectedEmail.fromFull || selectedEmail.from}
                  </div>
                  <div className="text-sm text-gray-500">
                    To: <span className="text-gray-700 dark:text-gray-300">{selectedEmail.to || 'support@sukfhyoke.com'}</span>
                  </div>
                </div>
                
                {/* Date */}
                <div className="text-sm text-gray-500">
                  {formatFullDate(selectedEmail.receivedAt)}
                </div>
              </div>
            </div>

            {/* Email Body */}
            <div className="flex-1 p-6 overflow-y-auto bg-white dark:bg-gray-900">
              <div className="max-w-3xl mx-auto">
                <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-6 shadow-sm border border-gray-100 dark:border-gray-700">
                  {selectedEmail.htmlBody ? (
                    <div 
                      className="prose dark:prose-invert max-w-none"
                      dangerouslySetInnerHTML={{ __html: selectedEmail.htmlBody }}
                    />
                  ) : (
                    <div className="whitespace-pre-wrap text-gray-800 dark:text-gray-200 leading-relaxed">
                      {getEmailContent(selectedEmail)}
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Reply Section */}
            <div className="p-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">
              <div className="max-w-3xl mx-auto">
                <div className="mb-3 text-sm font-medium text-gray-700 dark:text-gray-300 flex items-center gap-2">
                  <FaReply className="text-blue-500" /> 
                  Reply to <span className="font-semibold">{selectedEmail.from}</span>
                </div>
                <textarea
                  value={replyMessage}
                  onChange={(e) => setReplyMessage(e.target.value)}
                  placeholder="Type your reply here..."
                  className="w-full p-4 border border-gray-200 rounded-lg h-32 mb-3 focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                />
                <div className="flex justify-end">
                  <button
                    onClick={handleSendReply}
                    disabled={sending || !replyMessage.trim()}
                    className="bg-blue-600 text-white px-6 py-2.5 rounded-lg flex items-center gap-2 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition font-medium shadow-sm"
                  >
                    <FaPaperPlane />
                    {sending ? 'Sending...' : 'Send Reply'}
                  </button>
                </div>
              </div>
            </div>
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-gray-400 bg-gray-50 dark:bg-gray-900">
            <div className="text-center">
              <FaInbox className="text-6xl mb-4 text-gray-200" />
              <p className="text-lg font-medium text-gray-500">Select an email to read</p>
              <p className="text-sm text-gray-400 mt-1">Choose an email from the list to view its contents</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
