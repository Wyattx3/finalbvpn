"use client";

import { useState, useEffect, useCallback } from "react";
import { Plus, Search, Signal, Power, Edit, Trash2, X, Save, Copy, RefreshCw, Activity, Wifi } from "lucide-react";

// Helper function to format bytes
const formatBytes = (bytes: number): string => {
  if (!bytes || bytes === 0) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
};

interface V2RayServer {
  id: string;
  name: string;
  flag: string;
  address: string;
  port: number;
  uuid: string;
  alterId: number;
  security: "auto" | "none" | "aes-128-gcm" | "chacha20-poly1305";
  network: "tcp" | "ws" | "grpc" | "h2";
  path: string;
  tls: boolean;
  country: string;
  load: number;
  status: "online" | "offline" | "maintenance";
  latency?: number;
  bandwidthUsed?: number;
  totalConnections?: number;
  tcpPort?: number;
}

// Predefined Country List
const countryList = [
  { name: "Singapore", flag: "🇸🇬" },
  { name: "Japan", flag: "🇯🇵" },
  { name: "United States", flag: "🇺🇸" },
  { name: "United Kingdom", flag: "🇬🇧" },
  { name: "Germany", flag: "🇩🇪" },
  { name: "Canada", flag: "🇨🇦" },
  { name: "Australia", flag: "🇦🇺" },
  { name: "France", flag: "🇫🇷" },
  { name: "Netherlands", flag: "🇳🇱" },
  { name: "India", flag: "🇮🇳" },
  { name: "South Korea", flag: "🇰🇷" },
  { name: "Hong Kong", flag: "🇭🇰" },
  { name: "Taiwan", flag: "🇹🇼" },
  { name: "Thailand", flag: "🇹🇭" },
  { name: "Vietnam", flag: "🇻🇳" },
  { name: "Myanmar", flag: "🇲🇲" },
];

export default function ServersPage() {
  const [servers, setServers] = useState<V2RayServer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingServer, setEditingServer] = useState<V2RayServer | null>(null);

  // Fetch servers from Firebase
  const fetchServers = useCallback(async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/api/servers');
      const data = await response.json();
      if (data.success) {
        setServers(data.servers);
      }
    } catch (error) {
      console.error('Failed to fetch servers:', error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchServers();
  }, [fetchServers]);

  // Form State
  const [formData, setFormData] = useState<Partial<V2RayServer>>({
    name: "",
    flag: "🇸🇬",
    address: "",
    country: "Singapore",
    port: 443,
    uuid: "",
    alterId: 0,
    security: "auto",
    network: "ws",
    path: "/",
    tls: true,
    status: "online",
    load: 0,
  });

  const handleOpenModal = (server?: V2RayServer) => {
    if (server) {
      setEditingServer(server);
      setFormData(server);
    } else {
      setEditingServer(null);
      setFormData({
        name: "",
        flag: "🇸🇬",
        address: "",
        country: "Singapore",
        port: 443,
        uuid: crypto.randomUUID(),
        alterId: 0,
        security: "auto",
        network: "ws",
        path: "/",
        tls: true,
        status: "online",
        load: 0,
      });
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingServer(null);
  };

  const handleCountryChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const selectedCountry = countryList.find(c => c.name === e.target.value);
    if (selectedCountry) {
      setFormData({
        ...formData,
        country: selectedCountry.name,
        flag: selectedCountry.flag
      });
    }
  };

  const handleSave = async () => {
    try {
      if (editingServer) {
        // Update existing
        const response = await fetch('/api/servers', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'update',
            serverId: editingServer.id,
            ...formData,
          }),
        });
        const data = await response.json();
        if (data.success) {
          setServers(servers.map(s => s.id === editingServer.id ? { ...s, ...formData } as V2RayServer : s));
        }
      } else {
        // Add new
        const response = await fetch('/api/servers', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'add',
            ...formData,
            load: 0,
          }),
        });
        const data = await response.json();
        if (data.success) {
          const newServer = {
            ...formData,
            id: data.serverId,
            load: 0,
          } as V2RayServer;
          setServers([...servers, newServer]);
        }
      }
    } catch (error) {
      console.error('Failed to save server:', error);
    }
    handleCloseModal();
  };

  const handleDelete = async (id: string) => {
    if (confirm("Are you sure you want to delete this server?")) {
      try {
        const response = await fetch('/api/servers', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'delete',
            serverId: id,
          }),
        });
        const data = await response.json();
        if (data.success) {
          setServers(servers.filter(s => s.id !== id));
        }
      } catch (error) {
        console.error('Failed to delete server:', error);
      }
    }
  };

  const generateVmessLink = (server: Partial<V2RayServer>) => {
    // Basic Mock Vmess Link Generator for display
    return `vmess://${btoa(JSON.stringify({
      v: "2",
      ps: server.name,
      add: server.address,
      port: server.port,
      id: server.uuid,
      aid: server.alterId,
      scy: server.security,
      net: server.network,
      type: "none",
      host: "",
      path: server.path,
      tls: server.tls ? "tls" : ""
    }))}`;
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
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">V2Ray Servers</h1>
          <p className="text-gray-500 dark:text-gray-400">Manage your V2Ray VPN nodes</p>
        </div>
        <button 
          onClick={() => handleOpenModal()}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" />
          Add Node
        </button>
      </div>

      {/* Filters and Search */}
      <div className="flex items-center gap-4 rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search servers by name or address..."
            className="w-full rounded-lg border border-gray-200 py-2 pl-10 pr-4 text-sm outline-none focus:border-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {/* Servers Table */}
      <div className="overflow-hidden rounded-xl bg-white shadow-sm dark:bg-gray-800">
        <table className="w-full text-left text-sm text-gray-500 dark:text-gray-400">
          <thead className="bg-gray-50 text-xs uppercase text-gray-700 dark:bg-gray-700 dark:text-gray-300">
            <tr>
              <th className="px-6 py-3">Node Name</th>
              <th className="px-6 py-3">Address</th>
              <th className="px-6 py-3">Transport</th>
              <th className="px-6 py-3">Latency</th>
              <th className="px-6 py-3">Bandwidth</th>
              <th className="px-6 py-3">Status</th>
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
                      <div className="text-xs text-gray-500 dark:text-gray-400">{server.country}</div>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-col">
                    <span className="font-mono text-xs dark:text-gray-300">{server.address}:{server.port}</span>
                    <span className="text-[10px] text-gray-400 truncate w-32" title={server.uuid}>{server.uuid}</span>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex gap-2">
                    <span className="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10 dark:bg-blue-900/30 dark:text-blue-400 dark:ring-blue-400/30 uppercase">
                      {server.network}
                    </span>
                    {server.tls && (
                      <span className="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-700/10 dark:bg-green-900/30 dark:text-green-400 dark:ring-green-400/30">
                        TLS
                      </span>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex items-center gap-1">
                    <Wifi className={`h-3 w-3 ${
                      server.latency && server.latency < 100 ? 'text-green-500' : 
                      server.latency && server.latency < 200 ? 'text-yellow-500' : 'text-red-500'
                    }`} />
                    <span className={`text-xs font-medium ${
                      server.latency && server.latency < 100 ? 'text-green-600 dark:text-green-400' : 
                      server.latency && server.latency < 200 ? 'text-yellow-600 dark:text-yellow-400' : 'text-red-600 dark:text-red-400'
                    }`}>
                      {server.latency ? `${server.latency}ms` : '-'}
                    </span>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex flex-col">
                    <div className="flex items-center gap-1">
                      <Activity className="h-3 w-3 text-purple-500" />
                      <span className="text-xs font-medium text-gray-700 dark:text-gray-300">
                        {formatBytes(server.bandwidthUsed || 0)}
                      </span>
                    </div>
                    <span className="text-[10px] text-gray-400">
                      {server.totalConnections || 0} connections
                    </span>
                  </div>
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
                <td className="px-6 py-4 text-right">
                  <div className="flex justify-end gap-2">
                    <button 
                      onClick={() => {
                        navigator.clipboard.writeText(generateVmessLink(server));
                        alert("Vmess Link Copied!");
                      }}
                      className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-purple-600 dark:hover:bg-gray-700 dark:hover:text-purple-400"
                      title="Copy Vmess Link"
                    >
                      <Copy className="h-4 w-4" />
                    </button>
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
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="w-full max-w-lg rounded-xl bg-white p-5 shadow-xl dark:bg-gray-800 dark:border dark:border-gray-700 max-h-[90vh] overflow-y-auto">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-bold dark:text-white">
                {editingServer ? "Edit V2Ray Node" : "Add New V2Ray Node"}
              </h2>
              <button onClick={handleCloseModal} className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300">
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Basic Info */}
              <div className="rounded-lg bg-gray-50 p-3 dark:bg-gray-700/50">
                <h3 className="mb-2 text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Basic Information</h3>
                <div className="grid grid-cols-2 gap-3">
                  <div className="col-span-2">
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Node Name</label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => setFormData({...formData, name: e.target.value})}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                      placeholder="e.g. Singapore 1"
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Country & Flag</label>
                    <select
                      value={formData.country}
                      onChange={handleCountryChange}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    >
                      {countryList.map((c) => (
                        <option key={c.name} value={c.name}>
                          {c.flag} {c.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Status</label>
                    <select
                      value={formData.status}
                      onChange={(e) => setFormData({...formData, status: e.target.value as any})}
                      className="w-full rounded-md border border-gray-300 px-2 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    >
                      <option value="online">Online (Active)</option>
                      <option value="offline">Offline (Down)</option>
                      <option value="maintenance">Maintenance</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* V2Ray Config */}
              <div className="rounded-lg bg-gray-50 p-3 dark:bg-gray-700/50">
                <h3 className="mb-2 text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">V2Ray Config</h3>
                <div className="grid grid-cols-3 gap-3">
                  <div className="col-span-2">
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Address</label>
                    <input
                      type="text"
                      value={formData.address}
                      onChange={(e) => setFormData({...formData, address: e.target.value})}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                      placeholder="vpn.example.com"
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Port</label>
                    <input
                      type="number"
                      value={formData.port}
                      onChange={(e) => setFormData({...formData, port: parseInt(e.target.value)})}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                      placeholder="443"
                    />
                  </div>
                  <div className="col-span-3">
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">UUID</label>
                    <div className="relative">
                      <input
                        type="text"
                        value={formData.uuid}
                        onChange={(e) => setFormData({...formData, uuid: e.target.value})}
                        className="w-full rounded-md border border-gray-300 pl-3 pr-16 py-1.5 text-xs outline-none focus:border-blue-500 font-mono dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                        placeholder="UUID"
                      />
                      <button 
                        onClick={() => setFormData({...formData, uuid: crypto.randomUUID()})}
                        className="absolute right-1 top-1/2 -translate-y-1/2 rounded bg-gray-200 px-2 py-0.5 text-[10px] font-medium text-gray-600 hover:bg-gray-300 dark:bg-gray-600 dark:text-gray-300"
                      >
                        Generate
                      </button>
                    </div>
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">AlterId</label>
                    <input
                      type="number"
                      value={formData.alterId}
                      onChange={(e) => setFormData({...formData, alterId: parseInt(e.target.value)})}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                      placeholder="0"
                    />
                  </div>
                  <div className="col-span-2">
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Security</label>
                    <select
                      value={formData.security}
                      onChange={(e) => setFormData({...formData, security: e.target.value as any})}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    >
                      <option value="auto">Auto</option>
                      <option value="none">None</option>
                      <option value="aes-128-gcm">AES-128-GCM</option>
                      <option value="chacha20-poly1305">ChaCha20-Poly1305</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Transport Config */}
              <div className="rounded-lg bg-gray-50 p-3 dark:bg-gray-700/50">
                <h3 className="mb-2 text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Transport</h3>
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Network</label>
                    <select
                      value={formData.network}
                      onChange={(e) => setFormData({...formData, network: e.target.value as any})}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                    >
                      <option value="tcp">TCP</option>
                      <option value="ws">WS</option>
                      <option value="grpc">gRPC</option>
                    </select>
                  </div>
                  <div className="col-span-2">
                    <label className="mb-1 block text-xs font-medium text-gray-700 dark:text-gray-300">Path / Host</label>
                    <input
                      type="text"
                      value={formData.path}
                      onChange={(e) => setFormData({...formData, path: e.target.value})}
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm outline-none focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                      placeholder="/"
                    />
                  </div>
                  <div className="col-span-3 flex items-center gap-6 pt-1">
                    <div className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        id="tls"
                        checked={formData.tls}
                        onChange={(e) => setFormData({...formData, tls: e.target.checked})}
                        className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <label htmlFor="tls" className="text-xs font-medium text-gray-700 dark:text-gray-300">Enable TLS</label>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-5 flex justify-end gap-2 border-t border-gray-100 pt-4 dark:border-gray-700">
              <button
                onClick={handleCloseModal}
                className="rounded-md px-3 py-1.5 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                className="flex items-center gap-2 rounded-md bg-blue-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-blue-700"
              >
                <Save className="h-4 w-4" />
                Save Node
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
