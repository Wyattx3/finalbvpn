"use client";

import { useState, useMemo } from "react";
import { Users, Server, Wallet, ArrowUpRight, Calendar, Activity, Download, Upload } from "lucide-react";
import { 
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, 
  BarChart, Bar, AreaChart, Area, PieChart, Pie, Cell, Legend
} from "recharts";

// --- Mock Data Generators ---

const generateCountryData = () => [
  { name: 'Singapore', value: 400 },
  { name: 'United States', value: 300 },
  { name: 'Japan', value: 300 },
  { name: 'Germany', value: 200 },
  { name: 'Others', value: 150 },
];

const COLORS = ['#3B82F6', '#10B981', '#8B5CF6', '#F59E0B', '#6B7280'];

const generateDailyData = () => {
  const data = [];
  for (let i = 1; i <= 30; i++) {
    data.push({
      name: `Day ${i}`,
      users: Math.floor(Math.random() * 50) + 100 + (i * 5),
      usage: Math.floor(Math.random() * 500) + 200,
      withdrawals: Math.floor(Math.random() * 5000) + 1000,
    });
  }
  return data;
};

const generateMonthlyData = () => {
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return months.map(m => ({
    name: m,
    users: Math.floor(Math.random() * 1000) + 5000,
    usage: Math.floor(Math.random() * 10000) + 5000,
    withdrawals: Math.floor(Math.random() * 50000) + 10000,
  }));
};

const generateYearlyData = () => {
  return [
    { name: "2021", users: 1200, usage: 50000, withdrawals: 150000 },
    { name: "2022", users: 3500, usage: 120000, withdrawals: 450000 },
    { name: "2023", users: 8900, usage: 280000, withdrawals: 980000 },
    { name: "2024", users: 12345, usage: 450000, withdrawals: 1230000 },
  ];
};

export default function DashboardPage() {
  const [timeFilter, setTimeFilter] = useState<'day' | 'month' | 'year'>('month');
  
  // Get data based on filter
  const chartData = useMemo(() => {
    if (timeFilter === 'day') return generateDailyData();
    if (timeFilter === 'year') return generateYearlyData();
    return generateMonthlyData();
  }, [timeFilter]);

  const countryData = useMemo(() => generateCountryData(), []);

  // Calculate Summary Stats based on current data
  const stats = useMemo(() => {
    const lastItem = chartData[chartData.length - 1];
    const prevItem = chartData[chartData.length - 2] || chartData[0];
    
    const totalUsers = lastItem.users;
    const userChange = Math.round(((lastItem.users - prevItem.users) / prevItem.users) * 100);

    const totalUsage = lastItem.usage; // In GB
    const usageChange = Math.round(((lastItem.usage - prevItem.usage) / prevItem.usage) * 100);

    const totalWithdrawals = lastItem.withdrawals;
    const withdrawalChange = Math.round(((lastItem.withdrawals - prevItem.withdrawals) / prevItem.withdrawals) * 100);

    return [
      {
        name: "Total Users",
        value: totalUsers.toLocaleString(),
        change: `${userChange > 0 ? '+' : ''}${userChange}%`,
        icon: Users,
        color: "bg-blue-500",
      },
      {
        name: "Active Servers",
        value: "48", // Static for now as servers don't fluctuate like user stats
        change: "+2",
        icon: Server,
        color: "bg-green-500",
      },
      {
        name: "Total Data Usage",
        value: `${(totalUsage / 1000).toFixed(1)} TB`,
        change: `${usageChange > 0 ? '+' : ''}${usageChange}%`,
        icon: Activity,
        color: "bg-purple-500",
      },
      {
        name: "Pending Withdrawals",
        value: `${(totalWithdrawals / 1000).toFixed(1)}K Pts`,
        change: `${withdrawalChange > 0 ? '+' : ''}${withdrawalChange}%`,
        icon: Wallet,
        color: "bg-orange-500",
      },
    ];
  }, [chartData]);

  // Common Tooltip Style
  const tooltipStyle = {
    backgroundColor: 'rgba(255, 255, 255, 0.95)',
    borderRadius: '8px',
    border: '1px solid #e5e7eb',
    boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)',
    padding: '8px 12px',
  };

  const tooltipLabelStyle = {
    color: '#374151', // gray-700
    fontWeight: 600,
    marginBottom: '4px',
  };

  const tooltipItemStyle = {
    color: '#111827', // gray-900
    fontSize: '12px',
    fontWeight: 500,
  };

  return (
    <div className="space-y-6">
      {/* Header & Filter */}
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-3xl font-bold tracking-tight dark:text-white">Analytics Dashboard</h1>
          <p className="text-gray-500 dark:text-gray-400">Overview of your VPN performance</p>
        </div>
        
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
                <p className="text-2xl font-bold text-gray-900 dark:text-white">{stat.value}</p>
              </div>
            </div>
            <div className="mt-4 flex items-center gap-1 text-sm text-green-600 dark:text-green-400">
              <ArrowUpRight className="h-4 w-4" />
              <span className="font-medium">{stat.change}</span>
              <span className="text-gray-400 dark:text-gray-500">vs last period</span>
            </div>
          </div>
        ))}
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        
        {/* User Growth Chart */}
        <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">User Growth Trend</h2>
            <div className="rounded-full bg-blue-50 px-3 py-1 text-xs font-medium text-blue-600 dark:bg-blue-900/20 dark:text-blue-400">
              {timeFilter === 'day' ? 'Last 30 Days' : timeFilter === 'year' ? 'All Time' : 'This Year'}
            </div>
          </div>
          <div className="h-[300px] w-full">
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
                <YAxis stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `${value}`} />
                <Tooltip 
                  contentStyle={tooltipStyle}
                  labelStyle={tooltipLabelStyle}
                  itemStyle={tooltipItemStyle}
                />
                <Area type="monotone" dataKey="users" stroke="#3B82F6" strokeWidth={3} fillOpacity={1} fill="url(#colorUsers)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Data Usage Chart */}
        <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">Data Usage (GB)</h2>
            <div className="flex gap-2 text-xs">
              <span className="flex items-center gap-1 text-gray-500 dark:text-gray-400">
                <div className="h-2 w-2 rounded-full bg-purple-500"></div> Total
              </span>
            </div>
          </div>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E7EB" className="dark:stroke-gray-700" />
                <XAxis dataKey="name" stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                <Tooltip 
                  cursor={{ fill: 'rgba(107, 114, 128, 0.1)' }}
                  contentStyle={tooltipStyle}
                  labelStyle={tooltipLabelStyle}
                  itemStyle={tooltipItemStyle}
                />
                <Bar dataKey="usage" fill="#8B5CF6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Server Country Distribution Chart */}
        <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">Most Popular Server Countries</h2>
          </div>
          <div className="h-[300px] w-full">
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
          </div>
        </div>

        {/* Withdrawal History Chart */}
        <div className="col-span-1 lg:col-span-2 rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
          <div className="mb-6 flex items-center justify-between">
            <h2 className="text-lg font-semibold dark:text-white">Points Withdrawal History</h2>
          </div>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E7EB" className="dark:stroke-gray-700" />
                <XAxis dataKey="name" stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#9CA3AF" fontSize={12} tickLine={false} axisLine={false} />
                <Tooltip 
                  contentStyle={tooltipStyle}
                  labelStyle={tooltipLabelStyle}
                  itemStyle={tooltipItemStyle}
                />
                <Line type="monotone" dataKey="withdrawals" stroke="#F97316" strokeWidth={3} dot={{ r: 4, fill: "#F97316" }} activeDot={{ r: 6 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

      </div>
    </div>
  );
}
