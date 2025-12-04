"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { 
  FaTachometerAlt, 
  FaUsers, 
  FaServer, 
  FaWallet, 
  FaCog, 
  FaFileCode,
  FaSignOutAlt 
} from "react-icons/fa";

const navigation = [
  { name: "Dashboard", href: "/dashboard", icon: FaTachometerAlt },
  { name: "Users", href: "/users", icon: FaUsers },
  { name: "Servers", href: "/servers", icon: FaServer },
  { name: "Withdrawals", href: "/withdrawals", icon: FaWallet },
  { name: "App Content (SDUI)", href: "/sdui", icon: FaFileCode },
  { name: "Settings", href: "/settings", icon: FaCog },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  const handleLogout = () => {
    // Remove auth token
    document.cookie = "auth_token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT";
    router.push("/");
  };

  return (
    <div className="fixed top-0 left-0 z-40 flex h-screen w-64 flex-col bg-gray-900 text-white dark:border-r dark:border-gray-800">
      <div className="flex h-16 shrink-0 items-center justify-center border-b border-gray-800">
        <h1 className="text-xl font-bold">BVPN Admin</h1>
      </div>
      
      <nav className="flex-1 overflow-y-auto px-4 py-4 scrollbar-thin scrollbar-thumb-gray-700 scrollbar-track-transparent">
        <ul className="space-y-2">
          {navigation.map((item) => {
            const isActive = pathname === item.href;
            return (
              <li key={item.name}>
                <Link
                  href={item.href}
                  className={`flex items-center gap-3 rounded-lg px-3 py-2 transition-colors ${
                    isActive
                      ? "bg-blue-600 text-white"
                      : "text-gray-400 hover:bg-gray-800 hover:text-white"
                  }`}
                >
                  <item.icon className="h-5 w-5" />
                  <span>{item.name}</span>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="shrink-0 border-t border-gray-800 p-4">
        <button 
          onClick={handleLogout}
          className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
        >
          <FaSignOutAlt className="h-5 w-5" />
          <span>Logout</span>
        </button>
      </div>
    </div>
  );
}
