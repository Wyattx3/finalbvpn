"use client";

import { useState, useEffect } from "react";
import { Save, Lock, User, Bell, Shield, Moon, Sun, Laptop, RefreshCw, Monitor, Globe, Zap, Users } from "lucide-react";
import { useTheme } from "@/components/theme-provider";
import { useAdminLoginActivity, useSessionHeartbeat } from "@/hooks/useAdminLoginActivity";

export default function SettingsPage() {
  const [activeTab, setActiveTab] = useState("profile");
  const { theme, setTheme } = useTheme();
  
  // 🔴 REAL-TIME: Use Firebase real-time ADMIN login activity
  const { activities: loginActivities, isLoading: loginLoading, activeCount } = useAdminLoginActivity(100);
  
  // Keep session alive with heartbeat
  useSessionHeartbeat();

  // Load settings from localStorage or default
  const [preferences, setPreferences] = useState({
    emailNotifications: true,
    securityAlerts: true,
    autoLogout: 30, // minutes
  });

  useEffect(() => {
    // Load Preferences
    const storedPrefs = localStorage.getItem('admin_preferences');
    if (storedPrefs) {
      try {
        setPreferences(JSON.parse(storedPrefs));
      } catch (e) {}
    }
  }, []);

  // Save preferences when changed
  useEffect(() => {
    localStorage.setItem('admin_preferences', JSON.stringify(preferences));
  }, [preferences]);

  // Mock Settings State
  const [adminProfile, setAdminProfile] = useState({
    name: "Super Admin",
    email: "admin@bvpn.com",
    currentPassword: "",
    newPassword: "",
    confirmPassword: "",
  });

  // Remove duplicate handleSave here

  // Remove duplicate preferences state here

  const handleSave = () => {
    alert("Settings saved successfully!");
  };

  const renderTabContent = () => {
    switch (activeTab) {
      case "profile":
        return (
          <div className="space-y-6">
            <h2 className="text-lg font-semibold dark:text-white">Admin Profile</h2>
            <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Display Name</label>
                <input
                  type="text"
                  value={adminProfile.name}
                  onChange={(e) => setAdminProfile({ ...adminProfile, name: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Email Address</label>
                <input
                  type="email"
                  value={adminProfile.email}
                  onChange={(e) => setAdminProfile({ ...adminProfile, email: e.target.value })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                />
              </div>
            </div>

            <div className="border-t border-gray-100 dark:border-gray-700 pt-6">
              <h3 className="mb-4 text-sm font-semibold uppercase text-gray-500 dark:text-gray-400">Change Password</h3>
              <div className="space-y-4 max-w-md">
                <div>
                  <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Current Password</label>
                  <input
                    type="password"
                    value={adminProfile.currentPassword}
                    onChange={(e) => setAdminProfile({ ...adminProfile, currentPassword: e.target.value })}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">New Password</label>
                  <input
                    type="password"
                    value={adminProfile.newPassword}
                    onChange={(e) => setAdminProfile({ ...adminProfile, newPassword: e.target.value })}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">Confirm New Password</label>
                  <input
                    type="password"
                    value={adminProfile.confirmPassword}
                    onChange={(e) => setAdminProfile({ ...adminProfile, confirmPassword: e.target.value })}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                  />
                </div>
              </div>
            </div>
          </div>
        );

      case "security":
        return (
          <div className="space-y-6">
            <h2 className="text-lg font-semibold dark:text-white">Security & Access</h2>
            
            <div className="space-y-4">
              <div className="flex items-center justify-between rounded-lg border border-gray-100 p-4 dark:border-gray-700">
                <div className="flex items-center gap-3">
                  <div className="rounded-full bg-yellow-100 p-2 text-yellow-600 dark:bg-yellow-900/30 dark:text-yellow-400">
                    <Lock className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-white">Session Timeout</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">Automatically logout after inactivity.</p>
                  </div>
                </div>
                <select 
                  value={preferences.autoLogout}
                  onChange={(e) => setPreferences({...preferences, autoLogout: parseInt(e.target.value)})}
                  className="rounded-lg border border-gray-300 px-2 py-1.5 text-sm outline-none dark:border-gray-600 dark:bg-gray-800 dark:text-white"
                >
                  <option value="15">15 Minutes</option>
                  <option value="30">30 Minutes</option>
                  <option value="60">1 Hour</option>
                </select>
              </div>
            </div>

            {/* Active Sessions Count */}
            <div className="mt-6 mb-4 flex items-center justify-between rounded-lg border border-green-200 bg-green-50 p-4 dark:border-green-900 dark:bg-green-900/20">
              <div className="flex items-center gap-3">
                <div className="rounded-full bg-green-100 p-2 text-green-600 dark:bg-green-900/50 dark:text-green-400">
                  <Users className="h-5 w-5" />
                </div>
                <div>
                  <p className="font-medium text-green-800 dark:text-green-300">Active Sessions</p>
                  <p className="text-sm text-green-600 dark:text-green-400">Currently using the dashboard</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="relative flex h-3 w-3">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75"></span>
                  <span className="relative inline-flex h-3 w-3 rounded-full bg-green-500"></span>
                </span>
                <span className="text-2xl font-bold text-green-700 dark:text-green-300">{activeCount}</span>
              </div>
            </div>

            <div className="mt-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-semibold uppercase text-gray-500 dark:text-gray-400">Admin Dashboard Login History</h3>
                  {/* Real-time indicator */}
                  <div className="flex items-center gap-1 text-xs text-green-600 dark:text-green-400">
                    <span className="relative flex h-1.5 w-1.5">
                      <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75"></span>
                      <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-green-500"></span>
                    </span>
                    <Zap className="h-3 w-3" />
                    Live
                  </div>
                </div>
                <span className="text-xs text-gray-400">Last 100 records</span>
              </div>
              <div className="rounded-lg border border-gray-100 dark:border-gray-700 max-h-[400px] overflow-y-auto">
                {loginLoading ? (
                  <div className="flex items-center justify-center p-8">
                    <RefreshCw className="h-6 w-6 animate-spin text-gray-400" />
                  </div>
                ) : loginActivities.length > 0 ? (
                  loginActivities.map((activity) => {
                    const currentSessionId = typeof window !== 'undefined' ? localStorage.getItem('admin_session_id') : null;
                    const isCurrentSession = activity.sessionId === currentSessionId;
                    
                    return (
                      <div key={activity.id} className={`flex items-center justify-between border-b border-gray-100 p-3 last:border-0 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors ${activity.isActive ? 'bg-green-50/50 dark:bg-green-900/10' : ''}`}>
                        <div className="flex items-center gap-3">
                          <div className={`flex h-9 w-9 items-center justify-center rounded-full ${activity.isActive ? 'bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400' : 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400'}`}>
                            <Monitor className="h-4 w-4" />
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                              <p className="text-sm font-medium text-gray-900 dark:text-white truncate">
                                {activity.device}
                              </p>
                              {activity.isActive && (
                                <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                                  <span className="relative flex h-1.5 w-1.5">
                                    <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75"></span>
                                    <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-green-500"></span>
                                  </span>
                                  Active
                                </span>
                              )}
                              {isCurrentSession && (
                                <span className="inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900/30 dark:text-blue-400">
                                  This Device
                                </span>
                              )}
                            </div>
                            <div className="flex items-center gap-1 text-xs text-gray-500 dark:text-gray-400">
                              <Globe className="h-3 w-3" />
                              <span>{activity.location}</span>
                              <span>•</span>
                              <span className="font-mono">{activity.ip}</span>
                            </div>
                          </div>
                        </div>
                        <div className="text-right ml-4">
                          <div className="text-xs font-medium text-gray-900 dark:text-white whitespace-nowrap">
                            {activity.timestamp.toLocaleTimeString()}
                          </div>
                          <div className="text-xs text-gray-500 dark:text-gray-400 whitespace-nowrap">
                            {activity.timestamp.toLocaleDateString()}
                          </div>
                        </div>
                      </div>
                    );
                  })
                ) : (
                   <div className="p-8 text-center text-sm text-gray-500 dark:text-gray-400">
                     <Monitor className="mx-auto mb-2 h-8 w-8 opacity-30" />
                     <p>No admin login activity recorded yet.</p>
                     <p className="text-xs mt-1">Dashboard logins will appear here in real-time.</p>
                   </div>
                )}
              </div>
            </div>
          </div>
        );

      case "preferences":
        return (
          <div className="space-y-6">
            <h2 className="text-lg font-semibold dark:text-white">Dashboard Preferences</h2>
            
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="emailNotif"
                  checked={preferences.emailNotifications}
                  onChange={(e) => setPreferences({ ...preferences, emailNotifications: e.target.checked })}
                  className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <label htmlFor="emailNotif" className="text-sm font-medium text-gray-700 dark:text-gray-300">Receive email notifications for withdrawal requests</label>
              </div>
              
              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="securityNotif"
                  checked={preferences.securityAlerts}
                  onChange={(e) => setPreferences({ ...preferences, securityAlerts: e.target.checked })}
                  className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <label htmlFor="securityNotif" className="text-sm font-medium text-gray-700 dark:text-gray-300">Receive security alerts (failed logins, etc.)</label>
              </div>

              <div className="pt-4">
                <p className="mb-3 text-sm font-medium text-gray-700 dark:text-gray-300">Theme Preference</p>
                <div className="flex flex-wrap gap-4">
                   <button 
                    onClick={() => setTheme("light")}
                    className={`flex items-center gap-2 rounded-lg border px-4 py-3 text-sm font-medium transition-colors ${
                      theme === 'light' 
                        ? 'border-blue-600 bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400' 
                        : 'border-gray-200 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'
                    }`}
                   >
                     <Sun className="h-4 w-4" />
                     Light
                   </button>
                   <button 
                    onClick={() => setTheme("dark")}
                    className={`flex items-center gap-2 rounded-lg border px-4 py-3 text-sm font-medium transition-colors ${
                      theme === 'dark' 
                        ? 'border-blue-600 bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400' 
                        : 'border-gray-200 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'
                    }`}
                   >
                     <Moon className="h-4 w-4" />
                     Dark
                   </button>
                   <button 
                    onClick={() => setTheme("system")}
                    className={`flex items-center gap-2 rounded-lg border px-4 py-3 text-sm font-medium transition-colors ${
                      theme === 'system' 
                        ? 'border-blue-600 bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400' 
                        : 'border-gray-200 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'
                    }`}
                   >
                     <Laptop className="h-4 w-4" />
                     System
                   </button>
                </div>
              </div>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">Admin Settings</h1>
          <p className="text-gray-500 dark:text-gray-400">Manage your admin account and dashboard preferences</p>
        </div>
        <button 
          onClick={handleSave}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Save className="h-4 w-4" />
          Save Changes
        </button>
      </div>

      <div className="flex flex-col gap-6 lg:flex-row">
        {/* Sidebar Tabs */}
        <div className="w-full lg:w-64 shrink-0">
          <div className="flex flex-col gap-1 rounded-xl bg-white p-2 shadow-sm dark:bg-gray-800 dark:border dark:border-gray-700">
            <button
              onClick={() => setActiveTab("profile")}
              className={`flex items-center gap-3 rounded-lg px-4 py-3 text-sm font-medium transition-colors ${
                activeTab === "profile" 
                  ? "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400" 
                  : "text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-700"
              }`}
            >
              <User className="h-4 w-4" />
              Profile
            </button>
            <button
              onClick={() => setActiveTab("security")}
              className={`flex items-center gap-3 rounded-lg px-4 py-3 text-sm font-medium transition-colors ${
                activeTab === "security" 
                  ? "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400" 
                  : "text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-700"
              }`}
            >
              <Shield className="h-4 w-4" />
              Security
            </button>
            <button
              onClick={() => setActiveTab("preferences")}
              className={`flex items-center gap-3 rounded-lg px-4 py-3 text-sm font-medium transition-colors ${
                activeTab === "preferences" 
                  ? "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400" 
                  : "text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-700"
              }`}
            >
              <Bell className="h-4 w-4" />
              Preferences
            </button>
          </div>
        </div>

        {/* Content Area */}
        <div className="flex-1 rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800 dark:border dark:border-gray-700">
          {renderTabContent()}
        </div>
      </div>
    </div>
  );
}
