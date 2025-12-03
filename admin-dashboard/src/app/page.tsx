"use client";

import { Users, Server, Wallet, ArrowUpRight } from "lucide-react";

export default function Home() {
  const stats = [
    {
      name: "Total Users",
      value: "12,345",
      change: "+12%",
      icon: Users,
      color: "bg-blue-500",
    },
    {
      name: "Active Servers",
      value: "48",
      change: "+2",
      icon: Server,
      color: "bg-green-500",
    },
    {
      name: "Pending Withdrawals",
      value: "$1,230",
      change: "5 pending",
      icon: Wallet,
      color: "bg-orange-500",
    },
  ];

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold tracking-tight dark:text-white">Dashboard Overview</h1>
      
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
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
              <span className="text-gray-400 dark:text-gray-500">from last month</span>
            </div>
          </div>
        ))}
      </div>

      <div className="rounded-xl bg-white p-6 shadow-sm dark:bg-gray-800">
        <h2 className="mb-4 text-lg font-semibold dark:text-white">Recent Activity</h2>
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="flex items-center justify-between border-b border-gray-100 pb-4 last:border-0 last:pb-0 dark:border-gray-700">
              <div className="flex items-center gap-4">
                <div className="h-10 w-10 rounded-full bg-gray-100 dark:bg-gray-700" />
                <div>
                  <p className="font-medium dark:text-white">User #{1000 + i} registered</p>
                  <p className="text-sm text-gray-500 dark:text-gray-400">2 minutes ago</p>
                </div>
              </div>
              <span className="text-sm text-gray-500 dark:text-gray-400">New User</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
