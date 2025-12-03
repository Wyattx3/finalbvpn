"use client";

import { useState } from "react";
import { Plus, Search, MoreVertical, Signal, Power, Edit, Trash2, X, Save } from "lucide-react";

interface Server {
  id: number;
  name: string;
  flag: string;
  ip: string;
  country: string;
  protocol: "Auto" | "TCP" | "UDP" | "V2Ray" | "WireGuard" | "OpenVPN";
  load: number;
  status: "online" | "offline" | "maintenance";
  isPremium: boolean;
}

const initialServers: Server[] = [
  {
    id: 1,
    name: "Singapore SG1",
    flag: "🇸🇬",
    ip: "128.199.1.1",
    country: "Singapore",
    protocol: "V2Ray",
    load: 45,
    status: "online",
    isPremium: false,
  },
  {
    id: 2,
    name: "USA West",
    flag: "🇺🇸",
    ip: "104.236.1.1",
    country: "United States",
    protocol: "OpenVPN",
    load: 12,
    status: "online",
    isPremium: true,
  },
  {
    id: 3,
    name: "Germany DE1",
    flag: "🇩🇪",
    ip: "159.203.1.1",
    country: "Germany",
    protocol: "WireGuard",
    load: 89,
    status: "maintenance",
    isPremium: false,
  },
  {
    id: 4,
    name: "Japan JP1",
    flag: "🇯🇵",
    ip: "192.168.1.1",
    country: "Japan",
    protocol: "V2Ray",
    load: 0,
    status: "offline",
    isPremium: true,
  },
];

export default function ServersPage() {
  const [servers, setServers] = useState<Server[]>(initialServers);
  const [searchTerm, setSearchTerm] = useState("");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingServer, setEditingServer] = useState<Server | null>(null);

  // Form State
  const [formData, setFormData] = useState<Partial<Server>>({
    name: "",
    flag: "🏳️",
    ip: "",
    country: "",
    protocol: "Auto",
    status: "online",
    isPremium: false,
    load: 0,
  });

  const handleOpenModal = (server?: Server) => {
    if (server) {
      setEditingServer(server);
      setFormData(server);
    } else {
      setEditingServer(null);
      setFormData({
        name: "",
        flag: "🏳️",
        ip: "",
        country: "",
        protocol: "Auto",
        status: "online",
        isPremium: false,
        load: 0,
      });
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingServer(null);
  };

  const handleSave = () => {
    if (editingServer) {
      // Update existing
      setServers(servers.map(s => s.id === editingServer.id ? { ...s, ...formData } as Server : s));
    } else {
      // Add new
      const newServer = {
        ...formData,
        id: servers.length + 1,
        load: 0,
      } as Server;
      setServers([...servers, newServer]);
    }
    handleCloseModal();
  };

  const handleDelete = (id: number) => {
    if (confirm("Are you sure you want to delete this server?")) {
      setServers(servers.filter(s => s.id !== id));
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "online":
        return "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400";
      case "maintenance":
        return "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400";
      case "offline":
        return "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400";
      default:
        return "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400";
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">VPN Servers</h1>
          <p className="text-gray-500 dark:text-gray-400">Manage your VPN server infrastructure</p>
        </div>
        <button 
          onClick={() => handleOpenModal()}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" />
          Add Server
        </button>
      </div>

      {/* Filters and Search */}
      <div className="flex items-center gap-4 rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search servers by name or IP..."
            className="w-full rounded-lg border border-gray-200 py-2 pl-10 pr-4 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <select className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white">
          <option value="all">All Protocols</option>
          <option value="v2ray">V2Ray</option>
          <option value="openvpn">OpenVPN</option>
          <option value="wireguard">WireGuard</option>
        </select>
      </div>

      {/* Servers Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm dark:bg-gray-800">
        <table className="w-full text-left text-sm text-gray-500 dark:text-gray-400">
          <thead className="bg-gray-50 text-xs uppercase text-gray-700 dark:bg-gray-700 dark:text-gray-300">
            <tr>
              <th className="px-6 py-3">Server Info</th>
              <th className="px-6 py-3">Protocol</th>
              <th className="px-6 py-3">Status</th>
              <th className="px-6 py-3">Load</th>
              <th className="px-6 py-3">Type</th>
              <th className="px-6 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
            {servers.map((server) => (
              <tr key={server.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                <td className="px-6 py-4">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-100 text-2xl dark:bg-gray-700">
                      {server.flag}
                    </div>
                    <div>
                      <div className="font-medium text-gray-900 dark:text-white">{server.name}</div>
                      <div className="text-xs text-gray-500 dark:text-gray-400">{server.ip}</div>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <span className="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10 dark:bg-blue-900/30 dark:text-blue-400 dark:ring-blue-400/30">
                    {server.protocol}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <span
                    className={`inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ${getStatusColor(
                      server.status
                    )}`}
                  >
                    {server.status === "online" && <Signal className="mr-1 h-3 w-3" />}
                    {server.status === "offline" && <Power className="mr-1 h-3 w-3" />}
                    {server.status}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <div className="flex items-center gap-2">
                    <div className="h-2 w-24 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700">
                      <div
                        className={`h-full ${
                          server.load > 80 ? "bg-red-500" : "bg-green-500"
                        }`}
                        style={{ width: `${server.load}%` }}
                      />
                    </div>
                    <span className="text-xs">{server.load}%</span>
                  </div>
                </td>
                <td className="px-6 py-4">
                  {server.isPremium ? (
                    <span className="text-amber-600 font-semibold text-xs dark:text-amber-400">Premium</span>
                  ) : (
                    <span className="text-gray-500 text-xs dark:text-gray-400">Free</span>
                  )}
                </td>
                <td className="px-6 py-4 text-right">
                  <div className="flex justify-end gap-2">
                    <button 
                      onClick={() => handleOpenModal(server)}
                      className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-blue-600 dark:hover:bg-gray-700 dark:hover:text-blue-400"
                    >
                      <Edit className="h-4 w-4" />
                    </button>
                    <button 
                      onClick={() => handleDelete(server.id)}
                      className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-red-600 dark:hover:bg-gray-700 dark:hover:text-red-400"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Add/Edit Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700">
            <div className="mb-6 flex items-center justify-between">
              <h2 className="text-lg font-bold dark:text-white">
                {editingServer ? "Edit Server" : "Add New Server"}
              </h2>
              <button onClick={handleCloseModal} className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300">
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">Server Name</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({...formData, name: e.target.value})}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    placeholder="e.g. US West 1"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">Country</label>
                  <input
                    type="text"
                    value={formData.country}
                    onChange={(e) => setFormData({...formData, country: e.target.value})}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    placeholder="e.g. United States"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">IP Address</label>
                  <input
                    type="text"
                    value={formData.ip}
                    onChange={(e) => setFormData({...formData, ip: e.target.value})}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    placeholder="192.168.1.1"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">Flag Emoji</label>
                  <input
                    type="text"
                    value={formData.flag}
                    onChange={(e) => setFormData({...formData, flag: e.target.value})}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    placeholder="🇺🇸"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">Protocol</label>
                  <select
                    value={formData.protocol}
                    onChange={(e) => setFormData({...formData, protocol: e.target.value as any})}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                  >
                    <option value="Auto">Auto</option>
                    <option value="V2Ray">V2Ray</option>
                    <option value="OpenVPN">OpenVPN</option>
                    <option value="WireGuard">WireGuard</option>
                    <option value="TCP">TCP</option>
                    <option value="UDP">UDP</option>
                  </select>
                </div>
                <div>
                  <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">Status</label>
                  <select
                    value={formData.status}
                    onChange={(e) => setFormData({...formData, status: e.target.value as any})}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                  >
                    <option value="online">Online</option>
                    <option value="offline">Offline</option>
                    <option value="maintenance">Maintenance</option>
                  </select>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="isPremium"
                  checked={formData.isPremium}
                  onChange={(e) => setFormData({...formData, isPremium: e.target.checked})}
                  className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700"
                />
                <label htmlFor="isPremium" className="text-sm font-medium text-gray-700 dark:text-gray-300">Premium Server (Requires Subscription)</label>
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-3">
              <button
                onClick={handleCloseModal}
                className="rounded-lg px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
              >
                <Save className="h-4 w-4" />
                Save Server
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
