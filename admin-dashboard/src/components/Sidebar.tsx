"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
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
  { name: "Dashboard", href: "/", icon: FaTachometerAlt },
  { name: "Users", href: "/users", icon: FaUsers },
  { name: "Servers", href: "/servers", icon: FaServer },
  { name: "Withdrawals", href: "/withdrawals", icon: FaWallet },
  { name: "App Content (SDUI)", href: "/sdui", icon: FaFileCode },
  { name: "Settings", href: "/settings", icon: FaCog },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <div className="flex h-screen w-64 flex-col bg-gray-900 text-white dark:border-r dark:border-gray-800">
      <div className="flex h-16 items-center justify-center border-b border-gray-800">
        <h1 className="text-xl font-bold">BVPN Admin</h1>
      </div>
      
      <nav className="flex-1 overflow-y-auto px-4 py-4">
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

      <div className="border-t border-gray-800 p-4">
        <button className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-gray-400 transition-colors hover:bg-gray-800 hover:text-white">
          <FaSignOutAlt className="h-5 w-5" />
          <span>Logout</span>
        </button>
      </div>
    </div>
  );
}
