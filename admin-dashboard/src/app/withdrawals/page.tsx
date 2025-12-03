"use client";

import { useState } from "react";
import { Check, X, Search, Filter, AlertCircle, Eye } from "lucide-react";

interface Withdrawal {
  id: string;
  userId: string;
  userName: string;
  amount: number; // in MMK
  points: number;
  method: string; // KPay, WavePay, etc.
  accountNumber: string;
  accountName: string;
  status: "pending" | "approved" | "rejected";
  date: string;
}

const initialWithdrawals: Withdrawal[] = [
  {
    id: "W-1001",
    userId: "U-1234",
    userName: "Mg Mg",
    amount: 5000,
    points: 5000,
    method: "KPay",
    accountNumber: "09123456789",
    accountName: "Mg Mg",
    status: "pending",
    date: "2024-03-20 10:30 AM",
  },
  {
    id: "W-1002",
    userId: "U-5678",
    userName: "Aung Aung",
    amount: 10000,
    points: 10000,
    method: "WavePay",
    accountNumber: "09987654321",
    accountName: "Aung Aung",
    status: "approved",
    date: "2024-03-19 03:15 PM",
  },
  {
    id: "W-1003",
    userId: "U-9012",
    userName: "Su Su",
    amount: 3000,
    points: 3000,
    method: "KPay",
    accountNumber: "09112233445",
    accountName: "Su Su",
    status: "rejected",
    date: "2024-03-18 09:00 AM",
  },
];

export default function WithdrawalsPage() {
  const [withdrawals, setWithdrawals] = useState<Withdrawal[]>(initialWithdrawals);
  const [filterStatus, setFilterStatus] = useState<string>("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedWithdrawal, setSelectedWithdrawal] = useState<Withdrawal | null>(null);

  const filteredWithdrawals = withdrawals.filter((w) => {
    const matchesStatus = filterStatus === "all" || w.status === filterStatus;
    const matchesSearch = 
      w.userName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      w.accountNumber.includes(searchTerm) ||
      w.id.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesStatus && matchesSearch;
  });

  const handleStatusChange = (id: string, newStatus: "approved" | "rejected") => {
    if (confirm(`Are you sure you want to mark this request as ${newStatus}?`)) {
      setWithdrawals(withdrawals.map(w => 
        w.id === id ? { ...w, status: newStatus } : w
      ));
      if (selectedWithdrawal?.id === id) {
        setSelectedWithdrawal(null);
      }
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

  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">Withdrawals</h1>
          <p className="text-gray-500 dark:text-gray-400">Manage user withdrawal requests</p>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex flex-col gap-4 rounded-xl bg-white p-4 shadow-sm sm:flex-row sm:items-center dark:bg-gray-800">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by ID, Name or Phone..."
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
        <table className="w-full text-left text-sm text-gray-500 dark:text-gray-400">
          <thead className="bg-gray-50 text-xs uppercase text-gray-700 dark:bg-gray-700 dark:text-gray-300">
            <tr>
              <th className="px-6 py-3">Request ID</th>
              <th className="px-6 py-3">User</th>
              <th className="px-6 py-3">Amount (MMK)</th>
              <th className="px-6 py-3">Method</th>
              <th className="px-6 py-3">Status</th>
              <th className="px-6 py-3">Date</th>
              <th className="px-6 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {filteredWithdrawals.map((withdrawal) => (
              <tr key={withdrawal.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                <td className="px-6 py-4 font-medium text-gray-900 dark:text-white">{withdrawal.id}</td>
                <td className="px-6 py-4">
                  <div>
                    <div className="font-medium text-gray-900 dark:text-white">{withdrawal.userName}</div>
                    <div className="text-xs text-gray-500 dark:text-gray-400">{withdrawal.userId}</div>
                  </div>
                </td>
                <td className="px-6 py-4 font-bold text-gray-900 dark:text-white">{withdrawal.amount.toLocaleString()}</td>
                <td className="px-6 py-4">
                  <div>
                    <div className="font-medium text-gray-900 dark:text-white">{withdrawal.method}</div>
                    <div className="text-xs text-gray-500 dark:text-gray-400">{withdrawal.accountNumber}</div>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <span
                    className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ${getStatusColor(
                      withdrawal.status
                    )}`}
                  >
                    {withdrawal.status.charAt(0).toUpperCase() + withdrawal.status.slice(1)}
                  </span>
                </td>
                <td className="px-6 py-4 text-xs">{withdrawal.date}</td>
                <td className="px-6 py-4 text-right">
                  <div className="flex justify-end gap-2">
                    <button 
                      onClick={() => setSelectedWithdrawal(withdrawal)}
                      className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-blue-600 dark:hover:bg-gray-700 dark:hover:text-blue-400"
                      title="View Details"
                    >
                      <Eye className="h-4 w-4" />
                    </button>
                    {withdrawal.status === "pending" && (
                      <>
                        <button 
                          onClick={() => handleStatusChange(withdrawal.id, "approved")}
                          className="rounded p-1 text-gray-400 hover:bg-green-50 hover:text-green-600 dark:hover:bg-green-900/30 dark:hover:text-green-400"
                          title="Approve"
                        >
                          <Check className="h-4 w-4" />
                        </button>
                        <button 
                          onClick={() => handleStatusChange(withdrawal.id, "rejected")}
                          className="rounded p-1 text-gray-400 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-900/30 dark:hover:text-red-400"
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
      </div>

      {/* Details Modal */}
      {selectedWithdrawal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
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
                  <p className="text-3xl font-bold text-gray-900 dark:text-white">{selectedWithdrawal.amount.toLocaleString()} MMK</p>
                  <p className="text-xs text-gray-400">({selectedWithdrawal.points} Points)</p>
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
                  <span className="text-gray-500 dark:text-gray-400">User Name</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.userName}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">User ID</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.userId}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Payment Method</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.method}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Account Name</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.accountName}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Account Number</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.accountNumber}</span>
                </div>
                <div className="flex justify-between border-b border-gray-100 py-2 dark:border-gray-700">
                  <span className="text-gray-500 dark:text-gray-400">Request Date</span>
                  <span className="font-medium dark:text-white">{selectedWithdrawal.date}</span>
                </div>
              </div>

              {selectedWithdrawal.status === "pending" && (
                <div className="mt-6 grid grid-cols-2 gap-3">
                  <button
                    onClick={() => handleStatusChange(selectedWithdrawal.id, "rejected")}
                    className="rounded-lg border border-red-200 bg-red-50 py-2.5 text-sm font-medium text-red-600 hover:bg-red-100 dark:border-red-900/30 dark:bg-red-900/20 dark:text-red-400 dark:hover:bg-red-900/40"
                  >
                    Reject Request
                  </button>
                  <button
                    onClick={() => handleStatusChange(selectedWithdrawal.id, "approved")}
                    className="rounded-lg bg-green-600 py-2.5 text-sm font-medium text-white hover:bg-green-700"
                  >
                    Approve Request
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
