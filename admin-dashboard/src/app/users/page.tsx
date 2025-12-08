"use client";

import { useState, useEffect, useCallback } from "react";
import { Search, Filter, Ban, Coins, CheckCircle, Smartphone, Globe, Activity, X, History, PlayCircle, Wallet, Download, Calendar, AlertTriangle, RefreshCw, Zap, Clock, Timer } from "lucide-react";
import { useRealtimeDevices, RealtimeDevice } from "@/hooks/useRealtimeDevices";

interface UserDevice extends RealtimeDevice {
  logs?: ActivityLog[];
}

interface ActivityLog {
  id: string;
  type: 'ad_reward' | 'withdrawal' | 'admin_adjustment';
  description: string;
  amount: number;
  timestamp: string;
}

// Format bytes to readable string
const formatDataUsage = (bytes: number): string => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
};

// Format date to relative time
const formatLastSeen = (dateString: string | null): string => {
  if (!dateString) return 'Unknown';
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins} mins ago`;
  if (diffMins < 1440) return `${Math.floor(diffMins / 60)} hours ago`;
  return `${Math.floor(diffMins / 1440)} days ago`;
};

// Format VPN time (seconds to hours:minutes)
const formatVpnTime = (seconds: number): string => {
  if (seconds <= 0) return '0h 0m';
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return `${hours}h ${minutes}m`;
};

export default function UsersPage() {
  // 🔴 REAL-TIME: Use Firebase real-time listener hook
  const { devices: realtimeDevices, isLoading, error: realtimeError } = useRealtimeDevices();
  
  const [searchTerm, setSearchTerm] = useState("");
  
  // Edit Balance State
  const [editingUser, setEditingUser] = useState<UserDevice | null>(null);
  const [showBalanceModal, setShowBalanceModal] = useState(false);
  const [pointsAmount, setPointsAmount] = useState<number>(0);
  const [balanceAction, setBalanceAction] = useState<'add' | 'deduct'>('add');
  const [balanceReason, setBalanceReason] = useState("");

  // VPN Time State (in minutes now)
  const [showVpnTimeModal, setShowVpnTimeModal] = useState(false);
  const [vpnTimeMinutes, setVpnTimeMinutes] = useState<number>(0);
  const [vpnTimeAction, setVpnTimeAction] = useState<'add' | 'deduct' | 'set'>('add');
  const [vpnTimeReason, setVpnTimeReason] = useState("");

  // History State
  const [viewingHistoryUser, setViewingHistoryUser] = useState<UserDevice | null>(null);
  const [historyLogs, setHistoryLogs] = useState<ActivityLog[]>([]);
  const [showHistoryModal, setShowHistoryModal] = useState(false);

  // Ban Confirmation State
  const [userToBan, setUserToBan] = useState<UserDevice | null>(null);
  const [showBanConfirmModal, setShowBanConfirmModal] = useState(false);

  // History Filters
  const [historyFilterType, setHistoryFilterType] = useState<'all' | 'earned' | 'used' | 'admin'>('all');
  const [timeFilterType, setTimeFilterType] = useState<'all' | 'date' | 'month' | 'year'>('all');
  const [selectedDate, setSelectedDate] = useState<string>(""); // For Date/Month/Year inputs

  // Convert realtime devices to UserDevice format
  const users: UserDevice[] = realtimeDevices;

  // Filter Logic
  const filteredUsers = users.filter((user) => 
    user.deviceModel.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.ipAddress.includes(searchTerm) ||
    user.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getFilteredHistory = () => {
    return historyLogs.filter(log => {
      // 1. Filter by Type
      if (historyFilterType === 'earned' && (log.type !== 'ad_reward')) return false;
      if (historyFilterType === 'used' && (log.type !== 'withdrawal')) return false;
      if (historyFilterType === 'admin' && (log.type !== 'admin_adjustment')) return false;

      // 2. Filter by Time
      if (timeFilterType !== 'all' && selectedDate) {
        const logDate = new Date(log.timestamp);
        
        if (timeFilterType === 'date') {
          // Input: "YYYY-MM-DD"
          return log.timestamp.startsWith(selectedDate);
        }
        if (timeFilterType === 'month') {
          // Input: "YYYY-MM"
          return log.timestamp.startsWith(selectedDate);
        }
        if (timeFilterType === 'year') {
          // Input: "YYYY" (from number input usually)
          return log.timestamp.startsWith(selectedDate);
        }
      }

      return true;
    });
  };

  const filteredHistory = getFilteredHistory();

  // Export to CSV
  const handleExportCSV = () => {
    if (!viewingHistoryUser) return;

    const csvHeaders = ["Date Time", "Type", "Description", "Points", "Status"];
    const csvRows = filteredHistory.map(log => {
      const status = log.amount > 0 ? "Earned" : "Used";
      return [
        `"${log.timestamp}"`,
        `"${log.type}"`,
        `"${log.description}"`,
        `"${log.amount}"`,
        `"${status}"`
      ].join(",");
    });

    const csvContent = [csvHeaders.join(","), ...csvRows].join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `activity_log_${viewingHistoryUser.id}_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const initiateBanToggle = (user: UserDevice) => {
    setUserToBan(user);
    setShowBanConfirmModal(true);
  };

  const confirmBanToggle = async () => {
    if (userToBan) {
      const isBanned = userToBan.status === 'banned';
      try {
        const response = await fetch('/api/devices', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: isBanned ? 'unban' : 'ban',
            deviceId: userToBan.id,
            reason: 'Banned by admin',
          }),
        });
        const data = await response.json();
        if (data.success) {
          // Real-time hook will automatically update UI when Firebase changes
          console.log(`✅ Device ${userToBan.id} ${isBanned ? 'unbanned' : 'banned'} successfully`);
        } else {
          console.error('Failed to toggle ban:', data.error);
        }
      } catch (error) {
        console.error('Failed to toggle ban:', error);
      }
      setShowBanConfirmModal(false);
      setUserToBan(null);
    }
  };

  const handleAddPoints = async () => {
    if (editingUser) {
      if (!balanceReason.trim()) {
        alert("Please provide a reason for this adjustment.");
        return;
      }

      const amount = balanceAction === 'add' ? pointsAmount : -pointsAmount;

      try {
        const response = await fetch('/api/devices', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'adjustBalance',
            deviceId: editingUser.id,
            amount,
            reason: balanceReason,
          }),
        });
        const data = await response.json();
        if (data.success) {
          // Real-time hook will automatically update UI when Firebase changes
          console.log(`✅ Balance adjusted for ${editingUser.id}: ${amount > 0 ? '+' : ''}${amount}`);
        } else {
          console.error('Failed to adjust balance:', data.error);
        }
      } catch (error) {
        console.error('Failed to adjust balance:', error);
      }
      
      setShowBalanceModal(false);
      setPointsAmount(0);
      setBalanceReason("");
      setEditingUser(null);
    }
  };

  const handleAdjustVpnTime = async () => {
    if (editingUser) {
      if (!vpnTimeReason.trim()) {
        alert("Please provide a reason for this adjustment.");
        return;
      }

      const seconds = vpnTimeMinutes * 60; // Convert minutes to seconds
      let newSeconds: number;
      
      if (vpnTimeAction === 'set') {
        newSeconds = seconds;
      } else if (vpnTimeAction === 'add') {
        newSeconds = (editingUser.vpnRemainingSeconds || 0) + seconds;
      } else {
        newSeconds = Math.max(0, (editingUser.vpnRemainingSeconds || 0) - seconds);
      }

      try {
        const response = await fetch('/api/devices', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'adjustVpnTime',
            deviceId: editingUser.id,
            seconds: newSeconds,
            reason: vpnTimeReason,
          }),
        });
        const data = await response.json();
        if (data.success) {
          console.log(`✅ VPN time adjusted for ${editingUser.id}: ${formatVpnTime(newSeconds)}`);
        } else {
          console.error('Failed to adjust VPN time:', data.error);
        }
      } catch (error) {
        console.error('Failed to adjust VPN time:', error);
      }
      
      setShowVpnTimeModal(false);
      setVpnTimeMinutes(0);
      setVpnTimeReason("");
      setEditingUser(null);
    }
  };

  const handleViewHistory = async (user: UserDevice) => {
    setViewingHistoryUser(user);
    setHistoryFilterType('all');
    setTimeFilterType('all');
    setSelectedDate('');
    setShowHistoryModal(true);
    
    // Fetch logs from Firebase API
    try {
      const response = await fetch('/api/devices', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'getLogs',
          deviceId: user.id,
          limit: 50,
        }),
      });
      const data = await response.json();
      if (data.success && data.logs) {
        setHistoryLogs(data.logs);
      } else {
        setHistoryLogs([]);
      }
    } catch (error) {
      console.error('Failed to fetch logs:', error);
      setHistoryLogs([]);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">User Management (Devices)</h1>
          <p className="text-gray-500 dark:text-gray-400">Monitor active devices, connections, and balances</p>
        </div>
        {/* Real-time indicator */}
        <div className="flex items-center gap-2 rounded-full bg-green-100 px-3 py-1.5 text-sm font-medium text-green-700 dark:bg-green-900/30 dark:text-green-400">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75"></span>
            <span className="relative inline-flex h-2 w-2 rounded-full bg-green-500"></span>
          </span>
          <Zap className="h-3.5 w-3.5" />
          Real-time
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-4 rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by Device Model, IP or ID..."
            className="w-full rounded-lg border border-gray-200 py-2 pl-10 pr-4 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-gray-400" />
          <select className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white">
            <option value="all">All Status</option>
            <option value="vpn_connected">VPN Connected</option>
            <option value="online">Online</option>
            <option value="offline">Offline</option>
            <option value="banned">Banned</option>
          </select>
        </div>
      </div>

      {/* Users Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm dark:bg-gray-800">
        <table className="w-full text-left text-sm text-gray-500 dark:text-gray-400">
          <thead className="bg-gray-50 text-xs uppercase text-gray-700 dark:bg-gray-700 dark:text-gray-300">
            <tr>
              <th className="px-4 py-3">Account ID</th>
              <th className="px-4 py-3">Device</th>
              <th className="px-4 py-3">Connection</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Balance</th>
              <th className="px-4 py-3">VPN Time</th>
              <th className="px-4 py-3">Usage</th>
              <th className="px-4 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {filteredUsers.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                {/* Account ID Column */}
                <td className="px-4 py-4">
                  <button 
                    onClick={() => navigator.clipboard.writeText(user.id)}
                    className="font-mono text-sm font-semibold text-purple-600 dark:text-purple-400 hover:text-purple-800 dark:hover:text-purple-300 flex items-center gap-2"
                    title="Click to copy"
                  >
                    {user.id}
                    <svg className="h-3.5 w-3.5 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                  </button>
                </td>
                {/* Device Column */}
                <td className="px-4 py-4">
                  <div className="flex items-center gap-2">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300">
                      <Smartphone className="h-4 w-4" />
                    </div>
                    <div>
                      <div className="font-medium text-gray-900 dark:text-white text-sm">{user.deviceModel}</div>
                      <div className="text-[10px] text-gray-500">{user.appVersion}</div>
                    </div>
                  </div>
                </td>
                {/* Connection Column */}
                <td className="px-4 py-4">
                  <div className="flex items-center gap-2">
                    <span className="text-lg">{user.flag || '🌍'}</span>
                    <div>
                      <div className="text-sm text-gray-900 dark:text-white">{user.country || 'Unknown'}</div>
                      <div className="text-[10px] text-gray-500 font-mono">{user.ipAddress || 'No IP'}</div>
                    </div>
                  </div>
                </td>
                {/* Status Column */}
                <td className="px-4 py-4">
                  <span
                    className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ${
                      user.status === 'vpn_connected'
                        ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400'
                        : user.status === 'online' 
                        ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' 
                        : user.status === 'banned'
                        ? 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'
                        : 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-400'
                    }`}
                  >
                    {user.status === 'vpn_connected' && <Zap className="mr-1 h-3 w-3" />}
                    {user.status === 'online' && <Activity className="mr-1 h-3 w-3" />}
                    {user.status === 'banned' && <Ban className="mr-1 h-3 w-3" />}
                    {user.status === 'vpn_connected' ? 'VPN Connected' : user.status.charAt(0).toUpperCase() + user.status.slice(1)}
                  </span>
                  {user.status !== 'online' && user.status !== 'vpn_connected' && user.lastSeen && (
                    <div className="mt-1 text-[10px] text-gray-400">{formatLastSeen(user.lastSeen)}</div>
                  )}
                </td>
                {/* Balance Column */}
                <td className="px-4 py-4">
                  <div className="font-semibold text-gray-900 dark:text-white">{user.balance.toLocaleString()}</div>
                  <div className="text-[10px] text-gray-500">Points</div>
                </td>
                {/* VPN Time Column */}
                <td className="px-4 py-4">
                  <div className={`font-semibold ${(user.vpnRemainingSeconds || 0) > 0 ? 'text-green-600 dark:text-green-400' : 'text-gray-400'}`}>
                    {formatVpnTime(user.vpnRemainingSeconds || 0)}
                  </div>
                  <div className="text-[10px] text-gray-500">Remaining</div>
                </td>
                {/* Data Usage Column - GB Format */}
                <td className="px-4 py-4">
                  <div className="font-medium text-gray-900 dark:text-white">{formatDataUsage(user.dataUsage || 0)}</div>
                  <div className="text-[10px] text-gray-500">Total used</div>
                </td>
                <td className="px-6 py-4 text-right">
                  <div className="flex justify-end gap-2">
                    <button 
                      onClick={() => handleViewHistory(user)}
                      className="rounded p-1 text-gray-400 hover:bg-blue-50 hover:text-blue-600 dark:hover:bg-blue-900/30 dark:hover:text-blue-400"
                      title="View Activity History"
                    >
                      <History className="h-4 w-4" />
                    </button>
                    <button 
                      onClick={() => {
                        setEditingUser(user);
                        setShowBalanceModal(true);
                      }}
                      className="rounded p-1 text-gray-400 hover:bg-yellow-50 hover:text-yellow-600 dark:hover:bg-yellow-900/30 dark:hover:text-yellow-400"
                      title="Add/Remove Balance"
                    >
                      <Coins className="h-4 w-4" />
                    </button>
                    <button 
                      onClick={() => {
                        setEditingUser(user);
                        setVpnTimeMinutes(0);
                        setVpnTimeAction('add');
                        setVpnTimeReason('');
                        setShowVpnTimeModal(true);
                      }}
                      className="rounded p-1 text-gray-400 hover:bg-green-50 hover:text-green-600 dark:hover:bg-green-900/30 dark:hover:text-green-400"
                      title="Adjust VPN Time"
                    >
                      <Timer className="h-4 w-4" />
                    </button>
                    <button 
                      onClick={() => initiateBanToggle(user)}
                      className={`rounded p-1 ${
                        user.status !== 'banned' 
                          ? 'text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/30 dark:hover:text-red-400' 
                          : 'text-red-600 hover:bg-green-50 hover:text-green-600 dark:text-red-400 dark:hover:bg-green-900/30 dark:hover:text-green-400'
                      }`}
                      title={user.status !== 'banned' ? "Ban Device" : "Unban Device"}
                    >
                      {user.status !== 'banned' ? <Ban className="h-4 w-4" /> : <CheckCircle className="h-4 w-4" />}
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
              <h2 className="text-lg font-bold dark:text-white">Manage Device Balance</h2>
              <button 
                onClick={() => setShowBalanceModal(false)}
                className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            
            <div className="mb-6">
              <div className="mb-2 flex items-center gap-3 rounded-lg bg-gray-50 p-3 dark:bg-gray-700/50">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-white shadow-sm dark:bg-gray-600">
                  <Smartphone className="h-5 w-5 text-gray-500 dark:text-gray-300" />
                </div>
                <div>
                  <p className="font-medium text-gray-900 dark:text-white">{editingUser.deviceModel}</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 font-mono">{editingUser.id}</p>
                </div>
              </div>
              <p className="text-sm text-gray-500 dark:text-gray-400">Current Balance: <span className="font-medium text-gray-900 dark:text-white">{editingUser.balance.toLocaleString()} Points</span></p>
            </div>

            <div className="mb-6">
              <div className="mb-4 flex rounded-lg bg-gray-100 p-1 dark:bg-gray-700">
                <button
                  onClick={() => setBalanceAction('add')}
                  className={`flex-1 rounded-md py-2 text-sm font-medium transition-all ${
                    balanceAction === 'add'
                      ? 'bg-white text-green-600 shadow-sm dark:bg-gray-600 dark:text-green-400'
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  Add Points (+)
                </button>
                <button
                  onClick={() => setBalanceAction('deduct')}
                  className={`flex-1 rounded-md py-2 text-sm font-medium transition-all ${
                    balanceAction === 'deduct'
                      ? 'bg-white text-red-600 shadow-sm dark:bg-gray-600 dark:text-red-400'
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  Deduct Points (-)
                </button>
              </div>

              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Amount
              </label>
              <input 
                type="number" 
                min="0"
                value={pointsAmount || ''}
                onChange={(e) => setPointsAmount(Math.abs(parseInt(e.target.value) || 0))}
                className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                placeholder="e.g. 500"
              />

              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Reason (Required)
              </label>
              <input 
                type="text" 
                value={balanceReason}
                onChange={(e) => setBalanceReason(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                placeholder="e.g. Bonus, Penalty, Adjustment"
              />

              <p className="mt-4 text-sm text-gray-500 dark:text-gray-400">
                New Balance will be: <strong>
                  {(editingUser.balance + (balanceAction === 'add' ? pointsAmount : -pointsAmount)).toLocaleString()}
                </strong>
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

      {/* Ban Confirmation Modal */}
      {showBanConfirmModal && userToBan && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
            <div className="mb-4 flex items-center gap-3 text-red-600 dark:text-red-400">
              <div className="rounded-full bg-red-100 p-2 dark:bg-red-900/30">
                <AlertTriangle className="h-6 w-6" />
              </div>
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">
                {userToBan.status === 'banned' ? 'Unban Device?' : 'Ban Device?'}
              </h2>
            </div>
            
            <p className="mb-6 text-sm text-gray-500 dark:text-gray-400">
              Are you sure you want to {userToBan.status === 'banned' ? 'unban' : 'ban'} <span className="font-medium text-gray-900 dark:text-white">{userToBan.deviceModel}</span>?
              {userToBan.status !== 'banned' && " This will prevent the device from accessing the VPN servers."}
            </p>

            <div className="flex justify-end gap-3">
              <button
                onClick={() => {
                  setShowBanConfirmModal(false);
                  setUserToBan(null);
                }}
                className="rounded-lg px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={confirmBanToggle}
                className={`rounded-lg px-4 py-2 text-sm font-medium text-white ${
                  userToBan.status === 'banned' 
                    ? 'bg-green-600 hover:bg-green-700' 
                    : 'bg-red-600 hover:bg-red-700'
                }`}
              >
                {userToBan.status === 'banned' ? 'Yes, Unban' : 'Yes, Ban Device'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* VPN Time Modal */}
      {showVpnTimeModal && editingUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
            <div className="mb-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="rounded-full bg-green-100 p-2 dark:bg-green-900/30">
                  <Timer className="h-5 w-5 text-green-600 dark:text-green-400" />
                </div>
                <h2 className="text-lg font-bold dark:text-white">Manage VPN Time</h2>
              </div>
              <button 
                onClick={() => setShowVpnTimeModal(false)}
                className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            
            <div className="mb-6">
              <div className="mb-2 flex items-center gap-3 rounded-lg bg-gray-50 p-3 dark:bg-gray-700/50">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-white shadow-sm dark:bg-gray-600">
                  <Smartphone className="h-5 w-5 text-gray-500 dark:text-gray-300" />
                </div>
                <div>
                  <p className="font-medium text-gray-900 dark:text-white">{editingUser.deviceModel}</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 font-mono">{editingUser.id}</p>
                </div>
              </div>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                Current VPN Time: <span className="font-medium text-green-600 dark:text-green-400">{formatVpnTime(editingUser.vpnRemainingSeconds || 0)}</span>
              </p>
            </div>

            <div className="mb-6">
              <div className="mb-4 flex rounded-lg bg-gray-100 p-1 dark:bg-gray-700">
                <button
                  onClick={() => setVpnTimeAction('add')}
                  className={`flex-1 rounded-md py-2 text-sm font-medium transition-all ${
                    vpnTimeAction === 'add'
                      ? 'bg-white text-green-600 shadow-sm dark:bg-gray-600 dark:text-green-400'
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  Add Time (+)
                </button>
                <button
                  onClick={() => setVpnTimeAction('deduct')}
                  className={`flex-1 rounded-md py-2 text-sm font-medium transition-all ${
                    vpnTimeAction === 'deduct'
                      ? 'bg-white text-red-600 shadow-sm dark:bg-gray-600 dark:text-red-400'
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  Deduct (-)
                </button>
                <button
                  onClick={() => setVpnTimeAction('set')}
                  className={`flex-1 rounded-md py-2 text-sm font-medium transition-all ${
                    vpnTimeAction === 'set'
                      ? 'bg-white text-blue-600 shadow-sm dark:bg-gray-600 dark:text-blue-400'
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  Set To
                </button>
              </div>

              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Minutes
              </label>
              <input 
                type="number" 
                min="1"
                step="1"
                value={vpnTimeMinutes || ''}
                onChange={(e) => setVpnTimeMinutes(Math.abs(parseInt(e.target.value) || 0))}
                className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                placeholder="e.g. 30"
              />

              {/* Quick Select Buttons */}
              <div className="mb-4 flex flex-wrap gap-2">
                {[1, 5, 10, 30, 60, 120, 240, 480].map((m) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => setVpnTimeMinutes(m)}
                    className={`rounded px-3 py-1.5 text-sm ${vpnTimeMinutes === m ? 'bg-green-500 text-white' : 'bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600'}`}
                  >
                    {m >= 60 ? `${m/60}h` : `${m}m`}
                  </button>
                ))}
              </div>

              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Reason (Required)
              </label>
              <input 
                type="text" 
                value={vpnTimeReason}
                onChange={(e) => setVpnTimeReason(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                placeholder="e.g. Bonus, Promotion, Adjustment"
              />

              <p className="mt-4 text-sm text-gray-500 dark:text-gray-400">
                New VPN Time will be: <strong className="text-green-600 dark:text-green-400">
                  {formatVpnTime(
                    vpnTimeAction === 'set' 
                      ? vpnTimeMinutes * 60 
                      : vpnTimeAction === 'add' 
                        ? (editingUser.vpnRemainingSeconds || 0) + vpnTimeMinutes * 60
                        : Math.max(0, (editingUser.vpnRemainingSeconds || 0) - vpnTimeMinutes * 60)
                  )}
                </strong>
              </p>
            </div>

            <div className="flex justify-end gap-3">
              <button
                onClick={() => setShowVpnTimeModal(false)}
                className="rounded-lg px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleAdjustVpnTime}
                className="rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700"
              >
                Update VPN Time
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Activity History Modal */}
      {showHistoryModal && viewingHistoryUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-3xl rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700 flex flex-col max-h-[90vh]">
            <div className="mb-4 flex items-center justify-between border-b border-gray-100 pb-4 dark:border-gray-700">
              <div>
                <h2 className="text-lg font-bold dark:text-white">Activity Log</h2>
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  {viewingHistoryUser.deviceModel} ({viewingHistoryUser.id})
                </p>
              </div>
              <button 
                onClick={() => setShowHistoryModal(false)}
                className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {/* Control Bar: Type Filters + Time Filters + Export */}
            <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              {/* Type Tabs */}
              <div className="flex rounded-lg bg-gray-100 p-1 dark:bg-gray-700">
                <button
                  onClick={() => setHistoryFilterType('all')}
                  className={`rounded-md px-3 py-1.5 text-xs font-medium transition-all ${
                    historyFilterType === 'all' 
                      ? 'bg-white text-gray-900 shadow-sm dark:bg-gray-600 dark:text-white' 
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  All
                </button>
                <button
                  onClick={() => setHistoryFilterType('earned')}
                  className={`rounded-md px-3 py-1.5 text-xs font-medium transition-all ${
                    historyFilterType === 'earned' 
                      ? 'bg-white text-green-600 shadow-sm dark:bg-gray-600 dark:text-green-400' 
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  Earned (Ads)
                </button>
                <button
                  onClick={() => setHistoryFilterType('used')}
                  className={`rounded-md px-3 py-1.5 text-xs font-medium transition-all ${
                    historyFilterType === 'used' 
                      ? 'bg-white text-red-600 shadow-sm dark:bg-gray-600 dark:text-red-400' 
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  Used (Withdraw)
                </button>
                <button
                  onClick={() => setHistoryFilterType('admin')}
                  className={`rounded-md px-3 py-1.5 text-xs font-medium transition-all ${
                    historyFilterType === 'admin' 
                      ? 'bg-white text-blue-600 shadow-sm dark:bg-gray-600 dark:text-blue-400' 
                      : 'text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white'
                  }`}
                >
                  From Admin
                </button>
              </div>

              {/* Time Filters & Export */}
              <div className="flex items-center gap-2">
                <select 
                  className="rounded-lg border border-gray-200 bg-white px-2 py-1.5 text-xs outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                  value={timeFilterType}
                  onChange={(e) => {
                    setTimeFilterType(e.target.value as any);
                    setSelectedDate('');
                  }}
                >
                  <option value="all">All Time</option>
                  <option value="date">By Date</option>
                  <option value="month">By Month</option>
                  <option value="year">By Year</option>
                </select>

                {timeFilterType === 'date' && (
                  <input 
                    type="date" 
                    className="rounded-lg border border-gray-200 bg-white px-2 py-1 text-xs outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    value={selectedDate}
                    onChange={(e) => setSelectedDate(e.target.value)}
                  />
                )}
                {timeFilterType === 'month' && (
                  <input 
                    type="month" 
                    className="rounded-lg border border-gray-200 bg-white px-2 py-1 text-xs outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    value={selectedDate}
                    onChange={(e) => setSelectedDate(e.target.value)}
                  />
                )}
                {timeFilterType === 'year' && (
                  <input 
                    type="number" 
                    placeholder="YYYY"
                    min="2023"
                    max="2030"
                    className="w-20 rounded-lg border border-gray-200 bg-white px-2 py-1 text-xs outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    value={selectedDate}
                    onChange={(e) => setSelectedDate(e.target.value)}
                  />
                )}

                <button 
                  onClick={handleExportCSV}
                  className="flex items-center gap-1 rounded-lg bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700"
                  title="Export to CSV"
                >
                  <Download className="h-3 w-3" />
                  <span>Export</span>
                </button>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto">
              {filteredHistory.length > 0 ? (
                <div className="space-y-3">
                  {filteredHistory.map((log) => (
                    <div key={log.id} className="flex items-center justify-between rounded-lg border border-gray-100 p-3 dark:border-gray-700 dark:bg-gray-800/50">
                      <div className="flex items-center gap-3">
                        <div className={`flex h-8 w-8 items-center justify-center rounded-full ${
                          log.type === 'ad_reward' ? 'bg-purple-100 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400' :
                          log.type === 'withdrawal' ? 'bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400' :
                          'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400'
                        }`}>
                          {log.type === 'ad_reward' && <PlayCircle className="h-4 w-4" />}
                          {log.type === 'withdrawal' && <Wallet className="h-4 w-4" />}
                          {log.type === 'admin_adjustment' && <Coins className="h-4 w-4" />}
                        </div>
                        <div>
                          <p className="font-medium text-gray-900 dark:text-white">{log.description}</p>
                          <p className="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-1">
                            <Calendar className="h-3 w-3" /> {log.timestamp}
                          </p>
                        </div>
                      </div>
                      <div className={`font-bold ${log.amount > 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'}`}>
                        {log.amount > 0 ? '+' : ''}{log.amount}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="flex h-40 flex-col items-center justify-center text-center text-gray-500 dark:text-gray-400">
                  <History className="mb-2 h-8 w-8 opacity-20" />
                  <p>No logs found matching your filters.</p>
                </div>
              )}
            </div>

            <div className="mt-4 flex justify-between border-t border-gray-100 pt-4 dark:border-gray-700">
               <div className="text-xs text-gray-500 dark:text-gray-400 content-center">
                 Showing {filteredHistory.length} records
               </div>
               <button
                onClick={() => setShowHistoryModal(false)}
                className="rounded-lg bg-gray-100 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
