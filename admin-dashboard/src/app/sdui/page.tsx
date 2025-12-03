"use client";

import { useState, useEffect } from "react";
import { Save, RefreshCw, Copy, Check } from "lucide-react";

// Initial SDUI Configurations (Mirrors Flutter App)
const initialConfigs: Record<string, any> = {
  home: {
    screen_id: "home",
    config: {
      type: "dashboard",
      app_bar: {
        title_disconnected: "Not Connected",
        title_connecting: "Connecting...",
        title_connected: "Connected"
      },
      timer_section: {
        show_timer: true
      },
      main_button: {
        status_text_disconnected: "Tap to Connect",
        status_text_connecting: "Establishing Connection...",
        status_text_connected: "VPN is On"
      },
      location_card: {
        label: "Selected Location",
        recent_label: "Recent Location",
        show_latency_toggle: true
      }
    }
  },
  popup_startup: {
    screen_id: "popup_startup",
    config: {
      enabled: true,
      display_type: "popup",
      image_url: "assets/images/onboarding/earn rewards.jpg",
      image_height: 180,
      title: "Special Offer! 🎉",
      message: "Get 50% bonus rewards for watching ads today! Limited time only.",
      is_dismissible: true,
      style: {
        background_color: "#FFFFFF",
        title_color: "#7E57C2",
        title_size: 22,
        message_color: "#666666",
        message_size: 15
      },
      buttons: [
        {
          label: "Earn Now",
          action: "close",
          color: "#7E57C2"
        },
        {
          label: "Maybe Later",
          action: "close",
          color: "#9E9E9E",
          outlined: true
        }
      ]
    }
  },
  onboarding: {
    screen_id: "onboarding",
    config: {
      type: "onboarding_flow",
      pages: [
        {
          title: "Global Servers",
          description: "Access content from around the world\nwith our extensive server network.",
          image: "assets/images/onboarding/Global servers.png"
        },
        {
          title: "High Speed",
          description: "Experience blazing fast connection\nspeeds for streaming and gaming.",
          image: "assets/images/onboarding/High Speed.png"
        },
        {
          title: "Secure & Private",
          description: "Your data is encrypted with bank-grade security protocols.",
          image: "assets/images/onboarding/Secure & Private.png"
        },
        {
          title: "Earn Rewards",
          description: "Watch ads and complete tasks to earn\nreal money rewards.",
          image: "assets/images/onboarding/earn rewards.jpg"
        }
      ],
      assets: {
        dot_prefix: "assets/images/onboarding/dot",
        next_button: "assets/images/onboarding/next.png",
        start_button: "assets/images/onboarding/get start.png"
      }
    }
  },
  earn_money: {
    screen_id: "earn_money",
    config: {
      title: "Earn Money",
      reward_per_ad: 30,
      max_ads_per_day: 100,
      currency: "Points",
      labels: {
        balance_label: "Total Points",
        watch_ad_button: "Watch Ad & Earn",
        daily_limit_reached: "Daily Limit Reached"
      }
    }
  },
  rewards: {
    screen_id: "rewards",
    config: {
      title: "My Rewards",
      payment_methods: ["KBZ Pay", "Wave Pay"],
      min_withdraw_mmk: 20000,
      min_withdraw_usd: 20.0,
      labels: {
        balance_label: "Total Points",
        withdraw_button: "Withdraw Now"
      }
    }
  },
  settings: {
    screen_id: "settings",
    config: {
      title: "Settings",
      account_id: "19a070***04eef7",
      share_text: "Check out VPN App - Secure, Fast & Private VPN!\n\nDownload now: https://play.google.com/store/apps/details?id=com.vpnapp",
      version: "V1.0.8 (latest)"
    }
  },
  contact_us: {
    screen_id: "contact_us",
    config: {
      title: "Contact Us",
      email: "support@vpnapp.com",
      telegram: "@vpnapp_support"
    }
  },
  about: {
    screen_id: "about",
    config: {
      title: "About",
      app_name: "VPN App",
      version: "1.0.8",
      description: "The best VPN app for secure and private internet access."
    }
  },
  privacy_policy: {
    screen_id: "privacy_policy",
    config: {
      title: "Privacy Policy",
      content: "Privacy Policy\n\n1. Introduction\nWe respect your privacy and are committed to protecting it.\n\n2. Data Collection\nWe do not collect any personal browsing data. We only collect connection logs for troubleshooting."
    }
  },
  terms_of_service: {
    screen_id: "terms_of_service",
    config: {
      title: "Terms of Service",
      content: "Terms of Service\n\n1. Acceptance\nBy using our app, you agree to these terms.\n\n2. Usage\nYou agree not to use the app for any illegal activities."
    }
  },
  language: {
    screen_id: "language",
    config: {
      title: "Language",
      languages: [
        {"name": "English", "native": "English", "code": "en"},
        {"name": "Myanmar", "native": "မြန်မာ", "code": "my"},
        {"name": "Chinese", "native": "中文", "code": "zh"}
      ]
    }
  },
  splash: {
    screen_id: "splash",
    config: {
      app_name: "SafeVPN",
      tagline: "Secure & Fast",
      gradient_colors: ["#7E57C2", "#B39DDB"],
      splash_duration_seconds: 3
    }
  },
  split_tunneling: {
    screen_id: "split_tunneling",
    config: {
      title: "Split Tunneling",
      options: [
        {"index": 0, "icon": "call_split", "title": "Disable", "subtitle": "No effect"},
        {"index": 1, "icon": "filter_list", "title": "Uses VPN", "subtitle": "Only allows selected applications to use the VPN"},
        {"index": 2, "icon": "block", "title": "Bypass VPN", "subtitle": "Disallows selected applications to use the VPN"}
      ],
      labels: {
        selected_apps: "Selected Applications",
        select_apps: "Select Applications",
        clear_all: "Clear All"
      }
    }
  },
  vpn_protocol: {
    screen_id: "vpn_protocol",
    config: {
      title: "VPN Protocol",
      protocols: [
        {"index": 0, "title": "Auto", "description": "Automatically select the best protocol"},
        {"index": 1, "title": "TCP", "description": "Transmission Control Protocol"},
        {"index": 2, "title": "UDP", "description": "User Datagram Protocol"}
      ]
    }
  },
  withdraw_history: {
    screen_id: "withdraw_history",
    config: {
      title: "Withdraw History",
      labels: {
        pending: "Pending",
        completed: "Completed",
        failed: "Failed"
      }
    }
  }
};

const screens = Object.keys(initialConfigs).sort();

export default function SduiPage() {
  const [selectedScreen, setSelectedScreen] = useState("home");
  const [jsonContent, setJsonContent] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    // Load config when screen changes
    const config = initialConfigs[selectedScreen] || {};
    setJsonContent(JSON.stringify(config, null, 2));
    setError(null);
    setSaved(false);
  }, [selectedScreen]);

  const handleJsonChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value;
    setJsonContent(value);
    setSaved(false);
    
    try {
      JSON.parse(value);
      setError(null);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleSave = () => {
    try {
      const parsed = JSON.parse(jsonContent);
      // In a real app, you would send 'parsed' to your backend API here
      console.log("Saving SDUI config for", selectedScreen, parsed);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (err) {
      alert("Invalid JSON. Please fix errors before saving.");
    }
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(jsonContent);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleFormat = () => {
    try {
      const parsed = JSON.parse(jsonContent);
      setJsonContent(JSON.stringify(parsed, null, 2));
      setError(null);
    } catch (err) {
      // Ignore format error if JSON is invalid
    }
  };

  return (
    <div className="flex h-[calc(100vh-4rem)] flex-col gap-6 lg:flex-row">
      {/* Sidebar - Screen List */}
      <div className="w-full shrink-0 flex-col gap-4 lg:flex lg:w-64">
        <div>
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">App Content</h1>
          <p className="text-gray-500 dark:text-gray-400">Manage Server Driven UI (SDUI)</p>
        </div>
        
        <div className="flex-1 overflow-y-auto rounded-xl bg-white p-2 shadow-sm dark:bg-gray-800 dark:border dark:border-gray-700">
          {screens.map((screen) => (
            <button
              key={screen}
              onClick={() => setSelectedScreen(screen)}
              className={`flex w-full items-center justify-between rounded-lg px-4 py-3 text-left text-sm font-medium transition-colors ${
                selectedScreen === screen
                  ? "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-400"
                  : "text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-700"
              }`}
            >
              <span>{screen.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}</span>
              {selectedScreen === screen && <div className="h-2 w-2 rounded-full bg-blue-600" />}
            </button>
          ))}
        </div>
      </div>

      {/* Main Content - Editor */}
      <div className="flex flex-1 flex-col overflow-hidden rounded-xl bg-white shadow-sm dark:bg-gray-800 dark:border dark:border-gray-700">
        {/* Toolbar */}
        <div className="flex items-center justify-between border-b border-gray-100 p-4 dark:border-gray-700">
          <div className="flex items-center gap-2">
            <span className="font-mono text-sm font-bold text-gray-500 dark:text-gray-400">ID:</span>
            <span className="rounded bg-gray-100 px-2 py-1 font-mono text-sm text-gray-900 dark:bg-gray-700 dark:text-white">{selectedScreen}</span>
          </div>
          
          <div className="flex items-center gap-2">
            <button
              onClick={handleFormat}
              className="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
              title="Format JSON"
            >
              <RefreshCw className="h-4 w-4" />
              Format
            </button>
            <button
              onClick={handleCopy}
              className="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
            >
              {copied ? <Check className="h-4 w-4 text-green-600 dark:text-green-400" /> : <Copy className="h-4 w-4" />}
              Copy
            </button>
            <button
              onClick={handleSave}
              disabled={!!error}
              className={`flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium text-white transition-colors ${
                error 
                  ? "cursor-not-allowed bg-gray-400 dark:bg-gray-600" 
                  : saved 
                    ? "bg-green-600" 
                    : "bg-blue-600 hover:bg-blue-700"
              }`}
            >
              {saved ? <Check className="h-4 w-4" /> : <Save className="h-4 w-4" />}
              {saved ? "Saved!" : "Save Changes"}
            </button>
          </div>
        </div>

        {/* Editor Area */}
        <div className="relative flex-1">
          <textarea
            value={jsonContent}
            onChange={handleJsonChange}
            className="h-full w-full resize-none bg-gray-50 p-6 font-mono text-sm leading-relaxed text-gray-800 outline-none dark:bg-gray-900 dark:text-gray-200"
            spellCheck={false}
          />
          
          {/* Status Bar */}
          <div className={`absolute bottom-0 left-0 right-0 border-t px-4 py-2 text-xs font-medium ${
            error 
              ? "bg-red-50 text-red-600 border-red-100 dark:bg-red-900/20 dark:text-red-400 dark:border-red-900/30" 
              : "bg-white text-gray-500 border-gray-100 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-700"
          }`}>
            {error ? `Error: ${error}` : "JSON Valid"}
          </div>
        </div>
      </div>
    </div>
  );
}
