"use client";

import { useState, useRef } from "react";
import { Check, X, Search, Filter, AlertCircle, Eye, Zap, Upload, Image as ImageIcon, FileText } from "lucide-react";
import { useRealtimeWithdrawals, RealtimeWithdrawal } from "@/hooks/useRealtimeWithdrawals";

// Format date
const formatDate = (dateString: string | null): string => {
  if (!dateString) return 'Unknown';
  const date = new Date(dateString);
  return date.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

export default function WithdrawalsPage() {
  // 🔴 REAL-TIME: Use Firebase real-time listener hook
  const { withdrawals: realtimeWithdrawals, isLoading, error } = useRealtimeWithdrawals();
  
  const [filterStatus, setFilterStatus] = useState<string>("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedWithdrawal, setSelectedWithdrawal] = useState<RealtimeWithdrawal | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  // Approve Modal State
  const [showApproveModal, setShowApproveModal] = useState(false);
  const [approveWithdrawal, setApproveWithdrawal] = useState<RealtimeWithdrawal | null>(null);
  const [receiptFile, setReceiptFile] = useState<File | null>(null);
  const [receiptPreview, setReceiptPreview] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Auto-generate Transaction ID
  const generateTransactionId = () => {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `TXN-${timestamp}-${random}`;
  };

  // Reject Modal State
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectWithdrawal, setRejectWithdrawal] = useState<RealtimeWithdrawal | null>(null);
  const [rejectionReason, setRejectionReason] = useState("");

  // View Receipt Modal
  const [viewReceiptUrl, setViewReceiptUrl] = useState<string | null>(null);

  // Filter withdrawals
  const filteredWithdrawals = realtimeWithdrawals.filter((w) => {
    const matchesStatus = filterStatus === 'all' || w.status === filterStatus;
    const matchesSearch = 
      w.accountName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      w.accountNumber?.includes(searchTerm) ||
      w.id?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      w.deviceId?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (w as any).transactionId?.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesStatus && matchesSearch;
  });

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setReceiptFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setReceiptPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const openApproveModal = (withdrawal: RealtimeWithdrawal) => {
    setApproveWithdrawal(withdrawal);
    setReceiptFile(null);
    setReceiptPreview(null);
    setShowApproveModal(true);
  };

  const openRejectModal = (withdrawal: RealtimeWithdrawal) => {
    setRejectWithdrawal(withdrawal);
    setRejectionReason("");
    setShowRejectModal(true);
  };

  const handleApprove = async () => {
    if (!approveWithdrawal || !receiptFile) {
      alert('Receipt Image is required!');
      return;
    }

    setIsProcessing(true);
    try {
      // Auto-generate transaction ID
      const autoTransactionId = generateTransactionId();
      
      // Convert file to base64
      const reader = new FileReader();
      reader.readAsDataURL(receiptFile);
      reader.onloadend = async () => {
        const base64 = reader.result as string;
        
        const response = await fetch('/api/withdrawals', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            withdrawalId: approveWithdrawal.id,
            action: 'approved',
            transactionId: autoTransactionId,
            receiptImage: base64,
          }),
        });
        
        const data = await response.json();
        if (data.success) {
          console.log(`✅ Withdrawal ${approveWithdrawal.id} approved with TXN: ${autoTransactionId}`);
          setShowApproveModal(false);
          setSelectedWithdrawal(null);
        } else {
          alert('Failed to approve withdrawal: ' + data.error);
        }
        setIsProcessing(false);
      };
    } catch (error) {
      console.error('Failed to approve withdrawal:', error);
      alert('Failed to approve withdrawal');
      setIsProcessing(false);
    }
  };

  const handleReject = async () => {
    if (!rejectWithdrawal || !rejectionReason.trim()) {
      alert('Rejection reason is required!');
      return;
    }

    setIsProcessing(true);
    try {
      const response = await fetch('/api/withdrawals', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          withdrawalId: rejectWithdrawal.id,
          action: 'rejected',
          rejectionReason: rejectionReason.trim(),
        }),
      });
      
      const data = await response.json();
      if (data.success) {
        console.log(`✅ Withdrawal ${rejectWithdrawal.id} rejected`);
        setShowRejectModal(false);
        setSelectedWithdrawal(null);
      } else {
        alert('Failed to reject withdrawal: ' + data.error);
      }
    } catch (error) {
      console.error('Failed to reject withdrawal:', error);
      alert('Failed to reject withdrawal');
    } finally {
      setIsProcessing(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "approved":
        return "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400";
      case "rejected":
        return "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400";
      case "pending":
        return "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400";
      default:
        return "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400";
    }
  };

  // Stats
  const pendingCount = realtimeWithdrawals.filter(w => w.status === 'pending').length;
  const approvedCount = realtimeWithdrawals.filter(w => w.status === 'approved').length;
  const rejectedCount = realtimeWithdrawals.filter(w => w.status === 'rejected').length;
  const totalPending = realtimeWithdrawals
    .filter(w => w.status === 'pending')
    .reduce((sum, w) => sum + w.points, 0);

  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold tracking-tight dark:text-white">Withdrawals</h1>
            <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700 dark:bg-green-900/30 dark:text-green-400">
              <Zap className="h-3 w-3" />
              Real-time
            </span>
          </div>
          <p className="text-gray-500 dark:text-gray-400">Manage user withdrawal requests</p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
          <p className="text-sm text-gray-500 dark:text-gray-400">Pending</p>
          <p className="text-2xl font-bold text-yellow-600 dark:text-yellow-400">{pendingCount}</p>
          <p className="text-xs text-gray-400">{totalPending.toLocaleString()} Points</p>
        </div>
        <div className="rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
          <p className="text-sm text-gray-500 dark:text-gray-400">Approved</p>
          <p className="text-2xl font-bold text-green-600 dark:text-green-400">{approvedCount}</p>
        </div>
        <div className="rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
          <p className="text-sm text-gray-500 dark:text-gray-400">Rejected</p>
          <p className="text-2xl font-bold text-red-600 dark:text-red-400">{rejectedCount}</p>
        </div>
        <div className="rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
          <p className="text-sm text-gray-500 dark:text-gray-400">Total</p>
          <p className="text-2xl font-bold text-gray-900 dark:text-white">{realtimeWithdrawals.length}</p>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex flex-col gap-4 rounded-xl bg-white p-4 shadow-sm sm:flex-row sm:items-center dark:bg-gray-800">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by ID, Name, Phone, Device or Transaction ID..."
            className="w-full rounded-lg border border-gray-200 py-2 pl-10 pr-4 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-gray-400" />
          <select 
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
          >
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>
      </div>

      {/* Withdrawals Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm dark:bg-gray-800">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-500 border-t-transparent" />
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <AlertCircle className="mb-2 h-10 w-10 text-red-400" />
            <p className="text-red-500">{error}</p>
          </div>
        ) : (
          <>
            <table className="w-full text-left text-sm text-gray-500 dark:text-gray-400">
              <thead className="bg-gray-50 text-xs uppercase text-gray-700 dark:bg-gray-700 dark:text-gray-300">
                <tr>
                  <th className="px-4 py-3">Request ID</th>
                  <th className="px-4 py-3">User</th>
                  <th className="px-4 py-3">Points</th>
                  <th className="px-4 py-3">Method</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Transaction ID</th>
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                {filteredWithdrawals.map((withdrawal) => (
                  <tr key={withdrawal.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                    <td className="px-4 py-4">
                      <span className="font-mono text-xs text-gray-500 dark:text-gray-400">
                        {withdrawal.id.slice(0, 8)}...
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      <div>
                        <div className="font-medium text-gray-900 dark:text-white">{withdrawal.accountName}</div>
                        <div className="text-xs text-gray-500 dark:text-gray-400">{withdrawal.accountNumber}</div>
                      </div>
                    </td>
                    <td className="px-4 py-4 font-bold text-gray-900 dark:text-white">
                      {withdrawal.points.toLocaleString()}
                    </td>
                    <td className="px-4 py-4">
                      <span className="font-medium text-gray-900 dark:text-white">{withdrawal.method}</span>
                    </td>
                    <td className="px-4 py-4">
                      <span
                        className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ${getStatusColor(
                          withdrawal.status
                        )}`}
                      >
                        {withdrawal.status.charAt(0).toUpperCase() + withdrawal.status.slice(1)}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      {(withdrawal as any).transactionId ? (
                        <span className="font-mono text-xs text-green-600 dark:text-green-400">
                          {(withdrawal as any).transactionId}
                        </span>
                      ) : (
                        <span className="text-xs text-gray-400">-</span>
                      )}
                    </td>
                    <td className="px-4 py-4 text-xs">{formatDate(withdrawal.createdAt)}</td>
                    <td className="px-4 py-4 text-right">
                      <div className="flex justify-end gap-1">
                        <button 
                          onClick={() => setSelectedWithdrawal(withdrawal)}
                          className="rounded p-1.5 text-gray-400 hover:bg-gray-100 hover:text-blue-600 dark:hover:bg-gray-700 dark:hover:text-blue-400"
                          title="View Details"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        {(withdrawal as any).receiptUrl && (
                          <button 
                            onClick={() => setViewReceiptUrl((withdrawal as any).receiptUrl)}
                            className="rounded p-1.5 text-gray-400 hover:bg-purple-50 hover:text-purple-600 dark:hover:bg-purple-900/30 dark:hover:text-purple-400"
                            title="View Receipt"
                          >
                            <ImageIcon className="h-4 w-4" />
                          </button>
                        )}
                        {withdrawal.status === "pending" && (
                          <>
                            <button 
                              onClick={() => openApproveModal(withdrawal)}
                              disabled={isProcessing}
                              className="rounded p-1.5 text-gray-400 hover:bg-green-50 hover:text-green-600 dark:hover:bg-green-900/30 dark:hover:text-green-400 disabled:opacity-50"
                              title="Approve"
                            >
                              <Check className="h-4 w-4" />
                            </button>
                            <button 
                              onClick={() => openRejectModal(withdrawal)}
                              disabled={isProcessing}
                              className="rounded p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-900/30 dark:hover:text-red-400 disabled:opacity-50"
                              title="Reject"
                            >
                              <X className="h-4 w-4" />
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {filteredWithdrawals.length === 0 && (
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <AlertCircle className="mb-2 h-10 w-10 text-gray-300" />
                <p className="text-gray-500 dark:text-gray-400">No withdrawal requests found</p>
              </div>
            )}
          </>
        )}
      </div>

      {/* Details Modal */}
      {selectedWithdrawal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md max-h-[90vh] overflow-y-auto rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
            <div className="mb-6 flex items-center justify-between">
              <h2 className="text-lg font-bold dark:text-white">Withdrawal Details</h2>
              <button 
                onClick={() => setSelectedWithdrawal(null)}
                className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div className="rounded-lg bg-gray-50 p-4 dark:bg-gray-700">
                <div className="text-center">
                  <p className="text-sm text-gray-500 dark:text-gray-300">Amount Requested</p>
                  <p className="text-3xl font-bold text-gray-900 dark:text-white">{selectedWithdrawal.points.toLocaleString()}</p>
                  <p className="text-xs text-gray-400">Points</p>
                </div>
              </div>

              <div className="space-y-3 text-sm">
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Status</span>
                  <span className={`font-medium capitalize ${
                    selectedWithdrawal.status === 'approved' ? 'text-green-600 dark:text-green-400' : 
                    selectedWithdrawal.status === 'rejected' ? 'text-red-600 dark:text-red-400' : 'text-yellow-600 dark:text-yellow-400'
                  }`}>
                    {selectedWithdrawal.status}
                  </span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Account Name</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.accountName}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Payment Method</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.method}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Account Number</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.accountNumber}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Request Date</span>
                  <span className="font-medium dark:text-white">{formatDate(selectedWithdrawal.createdAt)}</span>
                </div>
                {(selectedWithdrawal as any).transactionId && (
                  <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                    <span className="text-gray-500 dark:text-gray-400">Transaction ID</span>
                    <span className="font-medium text-green-600 dark:text-green-400 font-mono">
                      {(selectedWithdrawal as any).transactionId}
                    </span>
                  </div>
                )}
                {selectedWithdrawal.processedAt && (
                  <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                    <span className="text-gray-500 dark:text-gray-400">Processed Date</span>
                    <span className="font-medium dark:text-white">{formatDate(selectedWithdrawal.processedAt)}</span>
                  </div>
                )}
                {selectedWithdrawal.rejectionReason && (
                  <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                    <span className="text-gray-500 dark:text-gray-400">Rejection Reason</span>
                    <span className="font-medium text-red-600 dark:text-red-400">{selectedWithdrawal.rejectionReason}</span>
                  </div>
                )}
              </div>

              {/* Receipt Image */}
              {(selectedWithdrawal as any).receiptUrl && (
                <div className="mt-4">
                  <p className="mb-2 text-sm font-medium text-gray-700 dark:text-gray-300">Receipt</p>
                  <img 
                    src={(selectedWithdrawal as any).receiptUrl} 
                    alt="Receipt" 
                    className="w-full rounded-lg border border-gray-200 dark:border-gray-600 cursor-pointer hover:opacity-90"
                    onClick={() => setViewReceiptUrl((selectedWithdrawal as any).receiptUrl)}
                  />
                </div>
              )}

              {selectedWithdrawal.status === "pending" && (
                <div className="mt-6 grid grid-cols-2 gap-3">
                  <button
                    onClick={() => {
                      setSelectedWithdrawal(null);
                      openRejectModal(selectedWithdrawal);
                    }}
                    disabled={isProcessing}
                    className="rounded-lg border border-red-200 bg-red-50 py-2.5 text-sm font-medium text-red-600 hover:bg-red-100 dark:border-red-900/30 dark:bg-red-900/20 dark:text-red-400 dark:hover:bg-red-900/40 disabled:opacity-50"
                  >
                    Reject
                  </button>
                  <button
                    onClick={() => {
                      setSelectedWithdrawal(null);
                      openApproveModal(selectedWithdrawal);
                    }}
                    disabled={isProcessing}
                    className="rounded-lg bg-green-600 py-2.5 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
                  >
                    Approve
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Approve Modal with Receipt Upload */}
      {showApproveModal && approveWithdrawal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
            <div className="mb-6 flex items-center justify-between">
              <h2 className="text-lg font-bold text-green-600 dark:text-green-400">Approve Withdrawal</h2>
              <button 
                onClick={() => setShowApproveModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="mb-4 rounded-lg bg-green-50 p-3 dark:bg-green-900/20">
              <p className="text-sm text-green-800 dark:text-green-300">
                <strong>{approveWithdrawal.accountName}</strong> - {approveWithdrawal.points.toLocaleString()} Points
              </p>
              <p className="text-xs text-green-600 dark:text-green-400">{approveWithdrawal.method} • {approveWithdrawal.accountNumber}</p>
            </div>

            <div className="space-y-4">
              {/* Auto-generated Transaction ID Info */}
              <div className="rounded-lg bg-blue-50 p-3 dark:bg-blue-900/20">
                <p className="text-xs text-blue-600 dark:text-blue-400">
                  <span className="font-medium">📝 Note:</span> Transaction ID will be auto-generated when approved (e.g., TXN-ABC123-XYZ789)
                </p>
              </div>

              {/* Receipt Upload */}
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Receipt Image <span className="text-red-500">*</span>
                </label>
                <input
                  type="file"
                  ref={fileInputRef}
                  onChange={handleFileChange}
                  accept="image/*"
                  className="hidden"
                />
                {receiptPreview ? (
                  <div className="relative">
                    <img 
                      src={receiptPreview} 
                      alt="Receipt Preview" 
                      className="w-full max-h-48 object-contain rounded-lg border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700"
                    />
                    <button
                      onClick={() => {
                        setReceiptFile(null);
                        setReceiptPreview(null);
                      }}
                      className="absolute top-2 right-2 rounded-full bg-red-500 p-1.5 text-white hover:bg-red-600 shadow-lg"
                    >
                      <X className="h-4 w-4" />
                    </button>
                    <p className="mt-2 text-center text-xs text-gray-500">Click X to remove and upload a different image</p>
                  </div>
                ) : (
                  <button
                    onClick={() => fileInputRef.current?.click()}
                    className="flex w-full items-center justify-center gap-2 rounded-lg border-2 border-dashed border-gray-300 py-8 text-gray-400 hover:border-green-400 hover:text-green-500 dark:border-gray-600"
                  >
                    <Upload className="h-6 w-6" />
                    <span>Upload Receipt Image</span>
                  </button>
                )}
              </div>
            </div>

            <div className="mt-6 flex gap-3">
              <button
                onClick={() => setShowApproveModal(false)}
                className="flex-1 rounded-lg border border-gray-200 py-2.5 text-sm font-medium text-gray-600 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleApprove}
                disabled={isProcessing || !receiptFile}
                className="flex-1 rounded-lg bg-green-600 py-2.5 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isProcessing ? 'Processing...' : 'Approve & Send Receipt'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reject Modal */}
      {showRejectModal && rejectWithdrawal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
            <div className="mb-6 flex items-center justify-between">
              <h2 className="text-lg font-bold text-red-600 dark:text-red-400">Reject Withdrawal</h2>
              <button 
                onClick={() => setShowRejectModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="mb-4 rounded-lg bg-red-50 p-3 dark:bg-red-900/20">
              <p className="text-sm text-red-800 dark:text-red-300">
                <strong>{rejectWithdrawal.accountName}</strong> - {rejectWithdrawal.points.toLocaleString()} Points
              </p>
              <p className="text-xs text-red-600 dark:text-red-400">{rejectWithdrawal.method} • {rejectWithdrawal.accountNumber}</p>
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Rejection Reason <span className="text-red-500">*</span>
              </label>
              <textarea
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                placeholder="Enter reason for rejection..."
                rows={3}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm outline-none focus:border-red-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
            </div>

            <div className="mt-6 flex gap-3">
              <button
                onClick={() => setShowRejectModal(false)}
                className="flex-1 rounded-lg border border-gray-200 py-2.5 text-sm font-medium text-gray-600 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={isProcessing || !rejectionReason.trim()}
                className="flex-1 rounded-lg bg-red-600 py-2.5 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isProcessing ? 'Processing...' : 'Reject Request'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* View Receipt Full Screen */}
      {viewReceiptUrl && (
        <div 
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm"
          onClick={() => setViewReceiptUrl(null)}
        >
          <div className="relative max-w-3xl max-h-[90vh]">
            <button
              onClick={() => setViewReceiptUrl(null)}
              className="absolute -top-10 right-0 text-white hover:text-gray-300"
            >
              <X className="h-8 w-8" />
            </button>
            <img 
              src={viewReceiptUrl} 
              alt="Receipt" 
              className="max-h-[85vh] rounded-lg"
              onClick={(e) => e.stopPropagation()}
            />
          </div>
        </div>
      )}
    </div>
  );
}
