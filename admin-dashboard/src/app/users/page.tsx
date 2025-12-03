"use client";

import { useState } from "react";
import { Search, Filter, MoreVertical, Edit, Ban, Coins, Trash2, CheckCircle, X } from "lucide-react";

interface User {
  id: string;
  name: string;
  email: string;
  balance: number;
  status: "active" | "banned";
  joinedDate: string;
  lastLogin: string;
  deviceInfo: string;
}

const initialUsers: User[] = [
  {
    id: "U-1234",
    name: "Kyaw Kyaw",
    email: "kyawkyaw@example.com",
    balance: 5000,
    status: "active",
    joinedDate: "2024-01-15",
    lastLogin: "2024-03-20 10:30 AM",
    deviceInfo: "Android 13 (Samsung S23)",
  },
  {
    id: "U-5678",
    name: "Aye Aye",
    email: "ayeaye@example.com",
    balance: 150,
    status: "active",
    joinedDate: "2024-02-01",
    lastLogin: "2024-03-19 05:45 PM",
    deviceInfo: "iOS 17.2 (iPhone 14)",
  },
  {
    id: "U-9012",
    name: "Spammer 007",
    email: "spam@example.com",
    balance: 0,
    status: "banned",
    joinedDate: "2024-03-10",
    lastLogin: "2024-03-15 09:00 AM",
    deviceInfo: "Windows 10",
  },
  {
    id: "U-3456",
    name: "Thandar",
    email: "thandar@example.com",
    balance: 12500,
    status: "active",
    joinedDate: "2023-11-20",
    lastLogin: "2024-03-20 11:15 AM",
    deviceInfo: "Android 12 (Redmi Note 11)",
  },
];

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>(initialUsers);
  const [searchTerm, setSearchTerm] = useState("");
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [showBalanceModal, setShowBalanceModal] = useState(false);
  const [pointsAmount, setPointsAmount] = useState<number>(0);

  const filteredUsers = users.filter((user) => 
    user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleBanToggle = (userId: string) => {
    setUsers(users.map(u => {
      if (u.id === userId) {
        return { ...u, status: u.status === 'active' ? 'banned' : 'active' };
      }
      return u;
    }));
  };

  const handleAddPoints = () => {
    if (editingUser) {
      setUsers(users.map(u => {
        if (u.id === editingUser.id) {
          return { ...u, balance: u.balance + pointsAmount };
        }
        return u;
      }));
      setShowBalanceModal(false);
      setPointsAmount(0);
      setEditingUser(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">User Management</h1>
          <p className="text-gray-500 dark:text-gray-400">Manage registered users, balances and access</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-4 rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by Name, Email or ID..."
            className="w-full rounded-lg border border-gray-200 py-2 pl-10 pr-4 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-gray-400" />
          <select className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white">
            <option value="all">All Status</option>
            <option value="active">Active</option>
            <option value="banned">Banned</option>
          </select>
        </div>
      </div>

      {/* Users Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm dark:bg-gray-800">
        <table className="w-full text-left text-sm text-gray-500 dark:text-gray-400">
          <thead className="bg-gray-50 text-xs uppercase text-gray-700 dark:bg-gray-700 dark:text-gray-300">
            <tr>
              <th className="px-6 py-3">User</th>
              <th className="px-6 py-3">Status</th>
              <th className="px-6 py-3">Balance (Points)</th>
              <th className="px-6 py-3">Device</th>
              <th className="px-6 py-3">Last Login</th>
              <th className="px-6 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {filteredUsers.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                <td className="px-6 py-4">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 font-bold text-blue-600 dark:bg-blue-900/30 dark:text-blue-400">
                      {user.name.charAt(0)}
                    </div>
                    <div>
                      <div className="font-medium text-gray-900 dark:text-white">{user.name}</div>
                      <div className="text-xs text-gray-500 dark:text-gray-400">{user.email}</div>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <span
                    className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ${
                      user.status === 'active' 
                        ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' 
                        : 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'
                    }`}
                  >
                    {user.status === 'active' ? <CheckCircle className="mr-1 h-3 w-3" /> : <Ban className="mr-1 h-3 w-3" />}
                    {user.status.charAt(0).toUpperCase() + user.status.slice(1)}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <div className="font-semibold text-gray-900 dark:text-white">{user.balance.toLocaleString()}</div>
                </td>
                <td className="px-6 py-4 text-xs text-gray-500 dark:text-gray-400">
                  {user.deviceInfo}
                </td>
                <td className="px-6 py-4 text-xs">
                  <div>{user.lastLogin}</div>
                  <div className="text-gray-400 text-[10px] dark:text-gray-500">Joined: {user.joinedDate}</div>
                </td>
                <td className="px-6 py-4 text-right">
                  <div className="flex justify-end gap-2">
                    <button 
                      onClick={() => {
                        setEditingUser(user);
                        setShowBalanceModal(true);
                      }}
                      className="rounded p-1 text-gray-400 hover:bg-yellow-50 hover:text-yellow-600 dark:hover:bg-yellow-900/30 dark:hover:text-yellow-400"
                      title="Add/Remove Points"
                    >
                      <Coins className="h-4 w-4" />
                    </button>
                    <button 
                      onClick={() => handleBanToggle(user.id)}
                      className={`rounded p-1 ${
                        user.status === 'active' 
                          ? 'text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/30 dark:hover:text-red-400' 
                          : 'text-red-600 hover:bg-green-50 hover:text-green-600 dark:text-red-400 dark:hover:bg-green-900/30 dark:hover:text-green-400'
                      }`}
                      title={user.status === 'active' ? "Ban User" : "Unban User"}
                    >
                      {user.status === 'active' ? <Ban className="h-4 w-4" /> : <CheckCircle className="h-4 w-4" />}
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Balance Modal */}
      {showBalanceModal && editingUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-bold dark:text-white">Manage Balance</h2>
              <button 
                onClick={() => setShowBalanceModal(false)}
                className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            
            <div className="mb-6">
              <p className="text-sm text-gray-500 dark:text-gray-400">User: <span className="font-medium text-gray-900 dark:text-white">{editingUser.name}</span></p>
              <p className="text-sm text-gray-500 dark:text-gray-400">Current Balance: <span className="font-medium text-gray-900 dark:text-white">{editingUser.balance.toLocaleString()} Points</span></p>
            </div>

            <div className="mb-6">
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Amount to Add (use negative for deduction)</label>
              <input 
                type="number" 
                value={pointsAmount}
                onChange={(e) => setPointsAmount(parseInt(e.target.value) || 0)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                placeholder="e.g. 500 or -500"
              />
              <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
                New Balance will be: <strong>{(editingUser.balance + pointsAmount).toLocaleString()}</strong>
              </p>
            </div>

            <div className="flex justify-end gap-3">
              <button
                onClick={() => setShowBalanceModal(false)}
                className="rounded-lg px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleAddPoints}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
              >
                Update Balance
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
