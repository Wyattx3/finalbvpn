"use client";

import { useState, useEffect, useCallback } from "react";
import { Users, Server, Wallet, ArrowUpRight, ArrowDownRight, Activity, RefreshCw, Zap, LogIn, Smartphone, Globe } from "lucide-react";
import { 
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, 
  BarChart, Bar, AreaChart, Area, PieChart, Pie, Cell, Legend
} from "recharts";
import { useRealtimeStats, useRealtimeWithdrawals } from "@/hooks/useRealtimeStats";
import { useRealtimeLoginActivity } from "@/hooks/useRealtimeLoginActivity";

const COLORS = ['#3B82F6', '#10B981', '#8B5CF6', '#F59E0B', '#6B7280', '#EF4444'];

// Format amount as MMK (Myanmar Kyat) - KPay style
const formatMMK = (amount: number): string => {
  if (amount >= 1000000) {
    // 1,000,000+ -> "1.5M MMK"
    return `${(amount / 1000000).toFixed(1)}M MMK`;
  } else if (amount >= 1000) {
    // 1,000+ -> "50,000 MMK" or "1.5K MMK" for shorter display
    return `${amount.toLocaleString()} MMK`;
  }
  return `${amount.toLocaleString()} MMK`;
};

// Shorter format for card values
const formatMMKShort = (amount: number): string => {
  if (amount >= 1000000) {
    return `${(amount / 1000000).toFixed(1)}M`;
  } else if (amount >= 100000) {
    return `${(amount / 1000).toFixed(0)}K`;
  } else if (amount >= 1000) {
    return amount.toLocaleString();
  }
  return amount.toString();
};

interface ChartDataItem {
  name: string;
  users: number;
  withdrawals: number;
  rewards: number;
}

interface CountryDataItem {
  name: string;
  value: number;
}

interface SummaryStats {
  totalUsers: number;
  newUsersToday: number;
  userChange: number;
  activeServers: number;
  withdrawalsThisMonth: number;
  withdrawalChange: number;
  rewardsThisMonth: number;
  pendingWithdrawals: number;
}

export default function DashboardPage() {
  // 🔴 REAL-TIME hooks for live data
  const { stats: realtimeStats, isLoading: statsLoading } = useRealtimeStats();
  const { pendingCount: pendingWithdrawals, isLoading: withdrawalsLoading } = useRealtimeWithdrawals();
  const { activities: loginActivities, isLoading: loginLoading } = useRealtimeLoginActivity(10);
  
  const [timeFilter, setTimeFilter] = useState<'day' | 'month' | 'year'>('month');
  const [chartData, setChartData] = useState<ChartDataItem[]>([]);
  const [countryData, setCountryData] = useState<CountryDataItem[]>([]);
  const [summaryStats, setSummaryStats] = useState<SummaryStats>({
    totalUsers: 0,
    newUsersToday: 0,
    userChange: 0,
    activeServers: 0,
    withdrawalsThisMonth: 0,
    withdrawalChange: 0,
    rewardsThisMonth: 0,
    pendingWithdrawals: 0,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  
  // Update summary stats with real-time data
  useEffect(() => {
    if (!statsLoading) {
      setSummaryStats(prev => ({
        ...prev,
        totalUsers: realtimeStats.totalUsers,
        pendingWithdrawals: pendingWithdrawals,
        // Don't override rewardsThisMonth - let it come from the summary API
        // which correctly calculates: balance + approved withdrawals only
      }));
    }
  }, [realtimeStats, pendingWithdrawals, statsLoading]);

  // Fetch chart data from Firebase
  const fetchChartData = useCallback(async () => {
    try {
      const response = await fetch(`/api/analytics?period=${timeFilter}`);
      const data = await response.json();
      if (data.success) {
        setChartData(data.data);
      }
    } catch (error) {
      console.error('Failed to fetch chart data:', error);
    }
  }, [timeFilter]);

  // Fetch country distribution
  const fetchCountryData = useCallback(async () => {
    try {
      const response = await fetch('/api/analytics/countries');
      const data = await response.json();
      if (data.success) {
        setCountryData(data.data);
      }
    } catch (error) {
      console.error('Failed to fetch country data:', error);
    }
  }, []);

  // Fetch summary stats
  const fetchSummaryStats = useCallback(async () => {
    try {
      const response = await fetch('/api/analytics/summary');
      const data = await response.json();
      if (data.success) {
        setSummaryStats(data.stats);
      }
    } catch (error) {
      console.error('Failed to fetch summary stats:', error);
    }
  }, []);

  // Initial load
  useEffect(() => {
    const loadAllData = async () => {
      setIsLoading(true);
      await Promise.all([
        fetchChartData(),
        fetchCountryData(),
        fetchSummaryStats(),
      ]);
      setIsLoading(false);
    };
    loadAllData();
  }, [fetchChartData, fetchCountryData, fetchSummaryStats]);

  // Refresh when time filter changes
  useEffect(() => {
    fetchChartData();
  }, [timeFilter, fetchChartData]);

  // Refresh all data
  const handleRefresh = async () => {
    setIsRefreshing(true);
    await Promise.all([
      fetchChartData(),
      fetchCountryData(),
      fetchSummaryStats(),
    ]);
    setIsRefreshing(false);
  };

  // Stats cards data
  const stats = [
    {
      name: "Total Users",
      value: summaryStats.totalUsers.toLocaleString(),
      change: summaryStats.userChange,
      subtext: `+${summaryStats.newUsersToday} today`,
      icon: Users,
      color: "bg-blue-500",
    },
    {
      name: "Active Servers",
      value: summaryStats.activeServers.toString(),
      change: 0,
      subtext: `${realtimeStats.onlineUsers} users online`,
      icon: Server,
      color: "bg-green-500",
    },
    {
      name: "Rewards (This Month)",
      value: formatMMKShort(summaryStats.rewardsThisMonth),
      change: 0,
      subtext: `+${formatMMK(realtimeStats.totalEarnings)} today`,
      icon: Activity,
      color: "bg-purple-500",
      unit: "MMK",
    },
    {
      name: "Withdrawals",
      value: formatMMKShort(summaryStats.withdrawalsThisMonth),
      change: summaryStats.withdrawalChange,
      subtext: `${summaryStats.pendingWithdrawals} pending`,
      icon: Wallet,
      color: "bg-orange-500",
      unit: "MMK",
    },
  ];

  // Common Tooltip Style
  const tooltipStyle = {
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    borderRadius: '8px',
    border: '1px solid #e5e7eb',
    boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)',
    padding: '8px 12px',
  };

  const tooltipLabelStyle = {
    color: '#374151',
    fontWeight: 600,
    marginBottom: '4px',
  };

  const tooltipItemStyle = {
    color: '#111827',
    fontSize: '12px',
    fontWeight: 500,
  };

  if (isLoading) {
    return (
      <div className="flex h-[60vh] items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <RefreshCw className="h-8 w-8 animate-spin text-blue-500" />
          <p className="text-gray-500 dark:text-gray-400">Loading analytics...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header & Filter */}
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-3xl font-bold tracking-tight dark:text-white">Analytics Dashboard</h1>
          <p className="text-gray-500 dark:text-gray-400">Real-time data from Firebase</p>
        </div>
        
        <div className="flex items-center gap-3">
          {/* Real-time indicator */}
          <div className="flex items-center gap-2 rounded-full bg-green-100 px-3 py-1.5 text-sm font-medium text-green-700 dark:bg-green-900/30 dark:text-green-400">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75"></span>
              <span className="relative inline-flex h-2 w-2 rounded-full bg-green-500"></span>
            </span>
            <Zap className="h-3.5 w-3.5" />
            Live
          </div>
          
          <button
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="flex items-center gap-2 rounded-lg bg-white px-3 py-2 text-sm font-medium text-gray-600 shadow-sm transition-all hover:bg-gray-50 disabled:opacity-50 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-700"
          >
            <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
            Refresh
          </button>
          
          <div className="flex items-center gap-2 rounded-lg bg-white p-1 shadow-sm dark:bg-gray-800">
            <button
              onClick={() => setTimeFilter('day')}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-all ${
                timeFilter === 'day' 
                  ? 'bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400' 
                  : 'text-gray-500 hover:bg-gray-50 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white'
              }`}
            >
              Daily
            </button>
            <button
              onClick={() => setTimeFilter('month')}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-all ${
                timeFilter === 'month' 
                  ? 'bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400' 
                  : 'text-gray-500 hover:bg-gray-50 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white'
              }`}
            >
              Monthly
            </button>
            <button
              onClick={() => setTimeFilter('year')}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-all ${
                timeFilter === 'year' 
                  ? 'bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400' 
                  : 'text-gray-500 hover:bg-gray-50 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white'
              }`}
            >
              Yearly
            </button>
          </div>
        </div>
      </div>
      
      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
          <div
            key={stat.name}
            className="overflow-hidden rounded-xl bg-white p-6 shadow-sm transition-shadow hover:shadow-md dark:bg-gray-800 dark:shadow-none"
          >
            <div className="flex items-center gap-4">
              <div className={`rounded-lg p-3 ${stat.color} text-white`}>
                <stat.icon className="h-6 w-6" />
              </div>
              <div>
                <p className="text-sm font-medium text-gray-500 dark:text-gray-400">{stat.name}</p>
                <p className="text-2xl font-bold text-gray-900 dark:text-white">
                  {stat.value}
                  {stat.unit && <span className="ml-1 text-sm font-medium text-gray-500 dark:text-gray-400">{stat.unit}</span>}
                </p>
              </div>
            </div>
            <div className="mt-4 flex items-center gap-1 text-sm">
              {stat.change !== 0 && (
                <>
                  {stat.change > 0 ? (
                    <ArrowUpRight className="h-4 w-4 text-green-600 dark:text-green-400" />
                  ) : (
                    <ArrowDownRight className="h-4 w-4 text-red-600 dark:text-red-400" />
                  )}
                  <span className={`font-medium ${stat.change > 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'}`}>
                    {stat.change > 0 ? '+' : ''}{stat.change}%
                  </span>
                </>
              )}
              <span className="text-gray-400 dark:text-gray-500">{stat.subtext}</span>
            </div>
          </div>
        ))}
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        
        {/* User Growth Chart */}
        <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">User Registrations</h2>
            <div className="rounded-full bg-blue-50 px-3 py-1 text-xs font-medium text-blue-600 dark:bg-blue-900/20 dark:text-blue-400">
              {timeFilter === 'day' ? 'Last 30 Days' : timeFilter === 'year' ? 'Last 4 Years' : 'Last 12 Months'}
            </div>
          </div>
          <div className="h-[300px] w-full">
            {chartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorUsers" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#3B82F6" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E7EB" className="dark:stroke-gray-700" />
                  <XAxis dataKey="name" stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                  <Tooltip 
                    contentStyle={tooltipStyle}
                    labelStyle={tooltipLabelStyle}
                    itemStyle={tooltipItemStyle}
                  />
                  <Area type="monotone" dataKey="users" stroke="#3B82F6" strokeWidth={3} fillOpacity={1} fill="url(#colorUsers)" name="New Users" />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-gray-400">No data available</div>
            )}
          </div>
        </div>

        {/* Rewards Earned Chart */}
        <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">Rewards Earned (Points)</h2>
            <div className="flex gap-2 text-xs">
              <span className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                <div className="h-2 w-2 rounded-full bg-purple-500"></div> Total Points
              </span>
            </div>
          </div>
          <div className="h-[300px] w-full">
            {chartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData} margin={{ top: 10, right: 10, left: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E7EB" className="dark:stroke-gray-700" />
                  <XAxis dataKey="name" stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis 
                    stroke="#9CA3AF" 
                    fontSize={12} 
                    tickLine={false} 
                    axisLine={false}
                    tickFormatter={(value) => value >= 1000 ? `${(value/1000).toFixed(0)}K` : value}
                  />
                  <Tooltip 
                    cursor={{ fill: 'rgba(107, 114, 128, 0.1)' }}
                    contentStyle={tooltipStyle}
                    labelStyle={tooltipLabelStyle}
                    formatter={(value: number) => [`${value.toLocaleString()} MMK`, 'Rewards']}
                  />
                  <Bar dataKey="rewards" fill="#8B5CF6" radius={[4, 4, 0, 0]} name="Rewards" />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-gray-400">No data available</div>
            )}
          </div>
        </div>

        {/* User Country Distribution Chart */}
        <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">Users by Country</h2>
          </div>
          <div className="h-[300px] w-full">
            {countryData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={countryData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={80}
                    fill="#8884d8"
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {countryData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip 
                    contentStyle={tooltipStyle}
                    itemStyle={tooltipItemStyle}
                  />
                  <Legend 
                    verticalAlign="bottom" 
                    height={36}
                    iconType="circle"
                    formatter={(value) => <span className="text-sm text-gray-600 dark:text-gray-300 ml-1">{value}</span>}
                  />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-gray-400">No data available</div>
            )}
          </div>
        </div>

        {/* Withdrawal History Chart */}
        <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">Withdrawal Trends</h2>
          </div>
          <div className="h-[300px] w-full">
            {chartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData} margin={{ top: 10, right: 10, left: 10, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E7EB" className="dark:stroke-gray-700" />
                  <XAxis dataKey="name" stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                  <YAxis 
                    stroke="#9CA3AF" 
                    fontSize={12} 
                    tickLine={false} 
                    axisLine={false}
                    tickFormatter={(value) => value >= 1000 ? `${(value/1000).toFixed(0)}K` : value}
                  />
                  <Tooltip 
                    contentStyle={tooltipStyle}
                    labelStyle={tooltipLabelStyle}
                    formatter={(value: number) => [`${value.toLocaleString()} MMK`, 'Withdrawals']}
                  />
                  <Line type="monotone" dataKey="withdrawals" stroke="#F97316" strokeWidth={3} dot={{ r: 4, fill: "#F97316" }} activeDot={{ r: 6 }} name="Withdrawals" />
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-gray-400">No data available</div>
            )}
          </div>
        </div>

      </div>

      {/* Recent Login Activity - Real-time */}
      <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <LogIn className="h-5 w-5 text-blue-500" />
            <h2 className="text-lg font-semibold dark:text-white">Recent Login Activity</h2>
          </div>
          <div className="flex items-center gap-1.5 text-xs text-green-600 dark:text-green-400">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-green-400 opacity-75"></span>
              <span className="relative inline-flex h-2 w-2 rounded-full bg-green-500"></span>
            </span>
            Live
          </div>
        </div>
        
        {loginLoading ? (
          <div className="flex h-40 items-center justify-center">
            <RefreshCw className="h-6 w-6 animate-spin text-gray-400" />
          </div>
        ) : loginActivities.length > 0 ? (
          <div className="space-y-3 max-h-[400px] overflow-y-auto">
            {loginActivities.map((activity) => (
              <div 
                key={activity.id} 
                className="flex items-center justify-between rounded-lg border border-gray-100 p-3 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400">
                    <Smartphone className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-gray-900 dark:text-white">{activity.deviceModel}</span>
                      <span className="text-lg">{activity.flag}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
                      <Globe className="h-3 w-3" />
                      <span>{activity.ipAddress}</span>
                      <span>•</span>
                      <span>{activity.country}{activity.city ? `, ${activity.city}` : ''}</span>
                    </div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-xs font-medium text-gray-900 dark:text-white">
                    {activity.timestamp.toLocaleTimeString()}
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">
                    {activity.timestamp.toLocaleDateString()}
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="flex h-40 flex-col items-center justify-center text-gray-400">
            <LogIn className="mb-2 h-8 w-8 opacity-30" />
            <p>No recent login activity</p>
          </div>
        )}
      </div>
    </div>
  );
}
