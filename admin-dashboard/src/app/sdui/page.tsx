"use client";

import { useState, useEffect } from "react";
import { 
  Settings, Code, Eye, Save, Plus, Trash2, RefreshCw, 
  Smartphone, Home, Gift, Bell, Shield, Zap,
  ChevronRight, Check, X, Edit3, Copy, AlertTriangle
} from "lucide-react";
import { db, doc, collection, getDocs, setDoc, deleteDoc, onSnapshot } from "@/lib/firebase";

// SDUI Screen Types - All screens from the VPN app
const SCREEN_TYPES = {
  // Main Screens
  home: { name: "Home Screen", icon: Home, color: "bg-blue-500", description: "Main VPN connection screen" },
  rewards: { name: "Rewards Screen", icon: Gift, color: "bg-purple-500", description: "Withdrawal and balance" },
  earn_money: { name: "Earn Money Screen", icon: Zap, color: "bg-yellow-500", description: "Watch ads to earn" },
  settings: { name: "Settings Screen", icon: Settings, color: "bg-gray-500", description: "App settings" },
  
  // Flow Screens
  onboarding: { name: "Onboarding Flow", icon: Smartphone, color: "bg-indigo-500", description: "First-time user guide" },
  splash: { name: "Splash Screen", icon: Zap, color: "bg-violet-500", description: "App loading screen" },
  
  // Popup (Single unified popup)
  popup_startup: { name: "App Popup", icon: Bell, color: "bg-orange-500", description: "Show popup when app opens (announcements, updates, promos)" },
  
  // Special Screens
  banned_screen: { name: "Banned Screen", icon: Shield, color: "bg-red-500", description: "Shown when device is banned" },
  server_maintenance: { name: "Server Maintenance", icon: Settings, color: "bg-amber-500", description: "Show when server is under maintenance" },
};

interface SduiConfig {
  id: string;
  config: Record<string, unknown>;
  updatedAt?: string;
}

export default function SduiManagementPage() {
  const [configs, setConfigs] = useState<SduiConfig[]>([]);
  const [selectedConfig, setSelectedConfig] = useState<SduiConfig | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [viewMode, setViewMode] = useState<"visual" | "json">("visual");
  const [jsonError, setJsonError] = useState<string | null>(null);
  const [editedJson, setEditedJson] = useState("");
  const [showNewConfigModal, setShowNewConfigModal] = useState(false);
  const [newConfigId, setNewConfigId] = useState("");
  const [saveSuccess, setSaveSuccess] = useState(false);

  // Load SDUI configs (only show configs that are in SCREEN_TYPES)
  useEffect(() => {
    const validScreenIds = Object.keys(SCREEN_TYPES);
    
    const unsubscribe = onSnapshot(
      collection(db, "sdui_configs"),
      (snapshot) => {
        const configsList: SduiConfig[] = [];
        snapshot.forEach((doc) => {
          // Only include configs that are in SCREEN_TYPES
          if (validScreenIds.includes(doc.id)) {
            configsList.push({
              id: doc.id,
              config: doc.data().config || doc.data(),
              updatedAt: doc.data().updatedAt?.toDate?.()?.toISOString(),
            });
          }
        });
        setConfigs(configsList);
        setIsLoading(false);
      },
      (error) => {
        console.error("Error loading SDUI configs:", error);
        setIsLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  // Update JSON editor when config changes
  useEffect(() => {
    if (selectedConfig) {
      setEditedJson(JSON.stringify(selectedConfig.config, null, 2));
      setJsonError(null);
    }
  }, [selectedConfig]);

  const handleSaveConfig = async () => {
    if (!selectedConfig) return;

    setIsSaving(true);
    try {
      let configToSave = selectedConfig.config;

      // If in JSON mode, parse the edited JSON
      if (viewMode === "json") {
        try {
          configToSave = JSON.parse(editedJson);
          setJsonError(null);
        } catch (e) {
          setJsonError("Invalid JSON format");
          setIsSaving(false);
          return;
        }
      }

      // Log what we're saving
      console.log('💾 Saving config:', selectedConfig.id);
      console.log('💾 Config data:', JSON.stringify(configToSave, null, 2));
      console.log('💾 Buttons specifically:', (configToSave as Record<string, unknown>).buttons);
      
      await setDoc(doc(db, "sdui_configs", selectedConfig.id), {
        config: configToSave,
        updatedAt: new Date(),
        // Force unique value to ensure Firestore detects change
        _lastModified: Date.now(),
      });

      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 2000);
    } catch (error) {
      console.error("Error saving config:", error);
      alert("Failed to save config");
    }
    setIsSaving(false);
  };

  const handleCreateConfig = async () => {
    if (!newConfigId.trim()) return;

    try {
      const defaultConfig = getDefaultConfig(newConfigId);
      await setDoc(doc(db, "sdui_configs", newConfigId), {
        config: defaultConfig,
        updatedAt: new Date(),
      });
      setShowNewConfigModal(false);
      setNewConfigId("");
    } catch (error) {
      console.error("Error creating config:", error);
    }
  };

  const handleDeleteConfig = async (configId: string) => {
    if (!confirm(`Are you sure you want to delete "${configId}"?`)) return;

    try {
      await deleteDoc(doc(db, "sdui_configs", configId));
      if (selectedConfig?.id === configId) {
        setSelectedConfig(null);
      }
    } catch (error) {
      console.error("Error deleting config:", error);
    }
  };

  const getDefaultConfig = (screenId: string): Record<string, unknown> => {
    switch (screenId) {
      case "popup_startup":
        return {
          enabled: false,
          popup_type: "announcement", // announcement, update, promo
          display_type: "popup",
          title: "Welcome!",
          message: "Welcome to Suk Fhyoke VPN",
          image: "",
          buttons: [
            { text: "OK", action: "dismiss" }
          ],
          is_dismissible: true,
          background_color: "#1A1625",
          // For update popups
          required_app_version: "", // If set, popup shows until user updates to this version
        };
      case "banned_screen":
        return {
          title: "Account Suspended",
          message: "Your account has been suspended due to violation of our terms of service.",
          support_button: {
            text: "Contact Support",
            url: "https://t.me/bvpn_support",
          },
          quit_button: {
            text: "Quit App",
          },
          show_quit_button: true,
        };
      case "server_maintenance":
        return {
          enabled: false,
          title: "Under Maintenance",
          message: "We're currently performing scheduled maintenance.\nPlease check back soon.",
          estimated_time: "",
          show_progress: true,
          progress_text: "Working on it...",
        };
      case "home":
        return {
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
        };
      case "rewards":
        return {
          title: "My Rewards",
          payment_methods: ["KBZ Pay", "Wave Pay"],
          min_withdraw_mmk: 20000,
          labels: {
            balance_label: "Total Points",
            withdraw_button: "Withdraw Now",
          }
        };
      case "earn_money":
        return {
          title: "Earn Money",
          reward_per_ad: 30,
          max_ads_per_day: 100,
          time_bonus_seconds: 7200,
          cooldown_ads_count: 10,
          cooldown_minutes: 10,
        };
      case "splash":
        return {
          app_name: "Suk Fhyoke VPN",
          tagline: "Secure & Fast",
          gradient_colors: ["#7E57C2", "#B39DDB"],
          splash_duration_seconds: 3,
          logo_path: "assets/images/logo.png",
        };
      case "onboarding":
        return {
          pages: [
            {
              title: "Global Servers",
              description: "Access content from around the world with our extensive server network.",
              image: "assets/images/onboarding/Global servers.png"
            },
            {
              title: "High Speed",
              description: "Experience blazing fast connection speeds for streaming and gaming.",
              image: "assets/images/onboarding/High Speed.png"
            },
            {
              title: "Secure & Private",
              description: "Your data is protected with military-grade encryption.",
              image: "assets/images/onboarding/Secure & Private.png"
            },
            {
              title: "Earn Rewards",
              description: "Watch ads and earn rewards that you can withdraw.",
              image: "assets/images/onboarding/earn rewards.jpg"
            }
          ],
          buttons: {
            skip: "Skip",
            next: "Next",
            get_started: "Get Started"
          }
        };
      case "settings":
        return {
          title: "Settings",
          sections: [
            { title: "General", items: ["Theme", "Language"] },
            { title: "VPN", items: ["Protocol", "Split Tunneling"] },
            { title: "About", items: ["About", "Privacy Policy", "Terms of Service"] }
          ],
          theme_options: ["System", "Light", "Dark"],
          language_options: ["English", "Myanmar"]
        };
      default:
        return {};
    }
  };

  const getScreenInfo = (screenId: string) => {
    return SCREEN_TYPES[screenId as keyof typeof SCREEN_TYPES] || {
      name: screenId,
      icon: Settings,
      color: "bg-gray-500"
    };
  };

  const updateConfigField = (path: string, value: unknown) => {
    if (!selectedConfig) return;

    const keys = path.split(".");
    const newConfig = JSON.parse(JSON.stringify(selectedConfig.config));
    
    let current: Record<string, unknown> = newConfig;
    for (let i = 0; i < keys.length - 1; i++) {
      if (!current[keys[i]]) {
        current[keys[i]] = {};
      }
      current = current[keys[i]] as Record<string, unknown>;
    }
    current[keys[keys.length - 1]] = value;

    setSelectedConfig({ ...selectedConfig, config: newConfig });
  };

  if (isLoading) {
    return (
      <div className="flex h-[60vh] items-center justify-center">
        <RefreshCw className="h-8 w-8 animate-spin text-blue-500" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight dark:text-white">SDUI Management</h1>
          <p className="text-gray-500 dark:text-gray-400">Control all app screens and popups remotely</p>
        </div>
        <button
          onClick={() => setShowNewConfigModal(true)}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" />
          New Config
        </button>
      </div>

      <div className="grid grid-cols-12 gap-6">
        {/* Sidebar - Config List */}
        <div className="col-span-12 lg:col-span-4 xl:col-span-3">
          <div className="rounded-xl bg-white p-4 shadow-sm dark:bg-gray-800">
            <h2 className="mb-4 text-sm font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Screen Configs ({configs.length})
            </h2>
            <div className="space-y-2">
              {configs.map((config) => {
                const info = getScreenInfo(config.id);
                const Icon = info.icon;
                const isSelected = selectedConfig?.id === config.id;

                return (
                  <div
                    key={config.id}
                    onClick={() => setSelectedConfig(config)}
                    className={`flex items-center justify-between rounded-lg p-3 cursor-pointer transition-all ${
                      isSelected
                        ? "bg-blue-50 border-2 border-blue-500 dark:bg-blue-900/20"
                        : "hover:bg-gray-50 dark:hover:bg-gray-700/50 border-2 border-transparent"
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <div className={`rounded-lg p-2 ${info.color} text-white`}>
                        <Icon className="h-4 w-4" />
                      </div>
                      <div>
                        <p className={`font-medium text-sm ${isSelected ? "text-blue-600 dark:text-blue-400" : "text-gray-900 dark:text-white"}`}>
                          {info.name}
                        </p>
                        <p className="text-xs text-gray-500 dark:text-gray-400 font-mono">
                          {config.id}
                        </p>
                      </div>
                    </div>
                    <ChevronRight className={`h-4 w-4 ${isSelected ? "text-blue-500" : "text-gray-400"}`} />
                  </div>
                );
              })}

              {configs.length === 0 && (
                <div className="py-8 text-center text-gray-400">
                  <Settings className="mx-auto h-8 w-8 opacity-50 mb-2" />
                  <p>No configs yet</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Main Editor */}
        <div className="col-span-12 lg:col-span-8 xl:col-span-9">
          {selectedConfig ? (
            <div className="rounded-xl bg-white shadow-sm dark:bg-gray-800">
              {/* Editor Header */}
              <div className="flex items-center justify-between border-b border-gray-100 p-4 dark:border-gray-700">
                <div className="flex items-center gap-3">
                  {(() => {
                    const info = getScreenInfo(selectedConfig.id);
                    const Icon = info.icon;
                    return (
                      <>
                        <div className={`rounded-lg p-2 ${info.color} text-white`}>
                          <Icon className="h-5 w-5" />
                        </div>
                        <div>
                          <h2 className="font-semibold text-gray-900 dark:text-white">{info.name}</h2>
                          <p className="text-xs text-gray-500 font-mono">{selectedConfig.id}</p>
                        </div>
                      </>
                    );
                  })()}
                </div>

                <div className="flex items-center gap-3">
                  {/* View Mode Toggle */}
                  <div className="flex rounded-lg bg-gray-100 p-1 dark:bg-gray-700">
                    <button
                      onClick={() => setViewMode("visual")}
                      className={`flex items-center gap-1 rounded-md px-3 py-1.5 text-sm font-medium transition-all ${
                        viewMode === "visual"
                          ? "bg-white text-gray-900 shadow-sm dark:bg-gray-600 dark:text-white"
                          : "text-gray-500 hover:text-gray-900 dark:text-gray-400"
                      }`}
                    >
                      <Eye className="h-4 w-4" />
                      Visual
                    </button>
                    <button
                      onClick={() => setViewMode("json")}
                      className={`flex items-center gap-1 rounded-md px-3 py-1.5 text-sm font-medium transition-all ${
                        viewMode === "json"
                          ? "bg-white text-gray-900 shadow-sm dark:bg-gray-600 dark:text-white"
                          : "text-gray-500 hover:text-gray-900 dark:text-gray-400"
                      }`}
                    >
                      <Code className="h-4 w-4" />
                      JSON
                    </button>
                  </div>

                  {/* Delete Button */}
                  <button
                    onClick={() => handleDeleteConfig(selectedConfig.id)}
                    className="rounded-lg p-2 text-gray-400 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-900/20"
                    title="Delete Config"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>

                  {/* Save Button */}
                  <button
                    onClick={handleSaveConfig}
                    disabled={isSaving}
                    className={`flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium text-white transition-all ${
                      saveSuccess
                        ? "bg-green-500"
                        : "bg-blue-600 hover:bg-blue-700"
                    } disabled:opacity-50`}
                  >
                    {isSaving ? (
                      <RefreshCw className="h-4 w-4 animate-spin" />
                    ) : saveSuccess ? (
                      <Check className="h-4 w-4" />
                    ) : (
                      <Save className="h-4 w-4" />
                    )}
                    {saveSuccess ? "Saved!" : "Save Changes"}
                  </button>
                </div>
              </div>

              {/* Editor Content */}
              <div className="p-6">
                {viewMode === "json" ? (
                  <div className="space-y-4">
                    {jsonError && (
                      <div className="flex items-center gap-2 rounded-lg bg-red-50 p-3 text-sm text-red-600 dark:bg-red-900/20 dark:text-red-400">
                        <AlertTriangle className="h-4 w-4" />
                        {jsonError}
                      </div>
                    )}
                    <textarea
                      value={editedJson}
                      onChange={(e) => setEditedJson(e.target.value)}
                      className="h-[500px] w-full rounded-lg border border-gray-200 bg-gray-50 p-4 font-mono text-sm dark:border-gray-700 dark:bg-gray-900 dark:text-white"
                      spellCheck={false}
                    />
                  </div>
                ) : (
                  <VisualEditor
                    screenId={selectedConfig.id}
                    config={selectedConfig.config}
                    onUpdate={updateConfigField}
                  />
                )}
              </div>
            </div>
          ) : (
            <div className="flex h-[400px] items-center justify-center rounded-xl bg-white shadow-sm dark:bg-gray-800">
              <div className="text-center">
                <Smartphone className="mx-auto h-12 w-12 text-gray-300 dark:text-gray-600" />
                <p className="mt-4 text-gray-500 dark:text-gray-400">Select a config to edit</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* New Config Modal */}
      {showNewConfigModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl dark:bg-gray-800">
            <h2 className="mb-4 text-lg font-bold dark:text-white">Create New Config</h2>
            
            <div className="mb-4">
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Config ID
              </label>
              <select
                value={newConfigId}
                onChange={(e) => setNewConfigId(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              >
                <option value="">Select a screen type...</option>
                {Object.entries(SCREEN_TYPES)
                  .filter(([id]) => !configs.some(c => c.id === id))
                  .map(([id, info]) => (
                    <option key={id} value={id}>{info.name} ({id})</option>
                  ))}
              </select>
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                Only screens not yet configured are shown
              </p>
            </div>

            <div className="flex justify-end gap-3">
              <button
                onClick={() => setShowNewConfigModal(false)}
                className="rounded-lg px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={handleCreateConfig}
                disabled={!newConfigId}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                Create
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// Helper: Extract English/default value from multi-language object
function getTextValue(value: unknown): string {
  if (typeof value === "string") return value;
  if (typeof value === "object" && value !== null) {
    const obj = value as Record<string, string>;
    return obj.en || obj.my_unicode || Object.values(obj)[0] || "";
  }
  return "";
}

// Supported Languages
const LANGUAGES = [
  { code: "en", name: "English", flag: "🇺🇸" },
  { code: "my_zawgyi", name: "Myanmar (Zawgyi)", flag: "🇲🇲" },
  { code: "my_unicode", name: "Myanmar (Unicode)", flag: "🇲🇲" },
  { code: "ja", name: "Japanese", flag: "🇯🇵" },
  { code: "zh", name: "Chinese", flag: "🇨🇳" },
  { code: "th", name: "Thai", flag: "🇹🇭" },
];

// Multi-Language Text Input Component
function MultiLanguageTextInput({
  label,
  value,
  onChange,
  placeholder,
  multiline = false,
}: {
  label: string;
  value: unknown;
  onChange: (value: Record<string, string>) => void;
  placeholder?: string;
  multiline?: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  
  // Convert value to multi-language format
  const getMultiLangValue = (): Record<string, string> => {
    if (typeof value === "string") {
      return { en: value };
    }
    if (typeof value === "object" && value !== null) {
      return value as Record<string, string>;
    }
    return { en: "" };
  };
  
  const multiValue = getMultiLangValue();
  
  const handleChange = (langCode: string, text: string) => {
    onChange({ ...multiValue, [langCode]: text });
  };
  
  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
          {label}
        </label>
        <button
          type="button"
          onClick={() => setExpanded(!expanded)}
          className="text-xs text-blue-600 hover:text-blue-700 dark:text-blue-400 flex items-center gap-1"
        >
          🌐 {expanded ? "Hide Languages" : "Add Translations"}
        </button>
      </div>
      
      {/* English (default) */}
      {multiline ? (
        <textarea
          value={multiValue.en || ""}
          onChange={(e) => handleChange("en", e.target.value)}
          placeholder={placeholder}
          rows={3}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        />
      ) : (
        <input
          type="text"
          value={multiValue.en || ""}
          onChange={(e) => handleChange("en", e.target.value)}
          placeholder={placeholder}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        />
      )}
      
      {/* Other Languages (expandable) */}
      {expanded && (
        <div className="mt-3 space-y-3 rounded-lg border border-blue-200 bg-blue-50 p-3 dark:border-blue-800 dark:bg-blue-900/20">
          <p className="text-xs text-blue-600 dark:text-blue-400">
            Add translations for other languages. Leave empty to use English.
          </p>
          {LANGUAGES.filter(l => l.code !== "en").map((lang) => (
            <div key={lang.code}>
              <label className="mb-1 block text-xs text-gray-600 dark:text-gray-400">
                {lang.flag} {lang.name}
              </label>
              {multiline ? (
                <textarea
                  value={multiValue[lang.code] || ""}
                  onChange={(e) => handleChange(lang.code, e.target.value)}
                  placeholder={`${placeholder || label} in ${lang.name}`}
                  rows={2}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                />
              ) : (
                <input
                  type="text"
                  value={multiValue[lang.code] || ""}
                  onChange={(e) => handleChange(lang.code, e.target.value)}
                  placeholder={`${placeholder || label} in ${lang.name}`}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                />
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// Visual Editor Component
function VisualEditor({
  screenId,
  config,
  onUpdate,
}: {
  screenId: string;
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  // Render different editors based on screen type
  switch (screenId) {
    case "popup_startup":
      return <PopupEditor config={config} onUpdate={onUpdate} />;
    case "banned_screen":
      return <BannedScreenEditor config={config} onUpdate={onUpdate} />;
    case "server_maintenance":
      return <ServerMaintenanceEditor config={config} onUpdate={onUpdate} />;
    case "home":
      return <HomeScreenEditor config={config} onUpdate={onUpdate} />;
    case "rewards":
      return <RewardsScreenEditor config={config} onUpdate={onUpdate} />;
    case "earn_money":
      return <EarnMoneyEditor config={config} onUpdate={onUpdate} />;
    case "splash":
      return <SplashScreenEditor config={config} onUpdate={onUpdate} />;
    case "onboarding":
      return <OnboardingEditor config={config} onUpdate={onUpdate} />;
    case "settings":
      return <SettingsScreenEditor config={config} onUpdate={onUpdate} />;
    default:
      return <GenericEditor config={config} onUpdate={onUpdate} />;
  }
}

// Popup Editor
function PopupEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const buttons = (config.buttons as Array<{text: string; action: string; target?: string}>) || [];
  
  // Debug log
  console.log('🔘 PopupEditor buttons:', buttons);

  return (
    <div className="space-y-6">
      {/* Enable Toggle */}
      <div className="flex items-center justify-between rounded-lg bg-gray-50 p-4 dark:bg-gray-700/50">
        <div>
          <p className="font-medium text-gray-900 dark:text-white">Enable Popup</p>
          <p className="text-sm text-gray-500 dark:text-gray-400">Show this popup when app starts</p>
        </div>
        <label className="relative inline-flex cursor-pointer items-center">
          <input
            type="checkbox"
            checked={config.enabled as boolean || false}
            onChange={(e) => onUpdate("enabled", e.target.checked)}
            className="peer sr-only"
          />
          <div className="peer h-6 w-11 rounded-full bg-gray-300 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-all after:content-[''] peer-checked:bg-blue-600 peer-checked:after:translate-x-full dark:bg-gray-600"></div>
        </label>
      </div>

      {/* Popup Type */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
          Popup Type
        </label>
        <select
          value={(config.popup_type as string) || "announcement"}
          onChange={(e) => onUpdate("popup_type", e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        >
          <option value="announcement">📢 Announcement</option>
          <option value="update">🔄 Update Required</option>
          <option value="promo">🎁 Promotion</option>
        </select>
        <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
          {config.popup_type === "update" 
            ? "Update popup will force user to update if dismiss is disabled" 
            : "Announcement or promo popup"}
        </p>
      </div>

      {/* Required App Version (for update type) */}
      {(config.popup_type as string) === "update" && (
        <div className="rounded-lg border border-orange-200 bg-orange-50 p-4 dark:border-orange-800 dark:bg-orange-900/20">
          <label className="mb-2 block text-sm font-medium text-orange-700 dark:text-orange-300">
            🔄 Required App Version
          </label>
          <input
            type="text"
            value={(config.required_app_version as string) || ""}
            onChange={(e) => onUpdate("required_app_version", e.target.value)}
            placeholder="e.g. 1.0.1"
            className="w-full rounded-lg border border-orange-300 px-3 py-2 dark:border-orange-600 dark:bg-gray-700 dark:text-white"
          />
          <p className="mt-1 text-xs text-orange-600 dark:text-orange-400">
            Popup will keep showing until user updates to this version or higher. Leave empty to show to all versions.
          </p>
        </div>
      )}

      <div className="grid grid-cols-2 gap-6">
        {/* Title */}
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Title
          </label>
          <input
            type="text"
            value={getTextValue(config.title)}
            onChange={(e) => onUpdate("title", e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>

        {/* Display Type */}
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Display Type
          </label>
          <select
            value={(config.display_type as string) || "popup"}
            onChange={(e) => onUpdate("display_type", e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          >
            <option value="popup">Popup Dialog</option>
            <option value="fullscreen">Full Screen</option>
            <option value="bottom_sheet">Bottom Sheet</option>
          </select>
        </div>
      </div>

      {/* Message */}
      <div>
        <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
          Message
        </label>
        <textarea
          value={getTextValue(config.message)}
          onChange={(e) => onUpdate("message", e.target.value)}
          rows={3}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        />
      </div>

      {/* Image Upload */}
      <div>
        <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
          Background Image
        </label>
        
        {/* Current Image Preview */}
        {(config.image as string) && (
          <div className="mb-3 relative">
            <img 
              src={config.image as string} 
              alt="Preview" 
              className="w-full h-40 object-cover rounded-lg border border-gray-300 dark:border-gray-600"
            />
            <button
              onClick={() => onUpdate("image", "")}
              className="absolute top-2 right-2 bg-red-500 text-white rounded-full p-1 hover:bg-red-600"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        )}
        
        {/* Upload Button */}
        <div className="flex gap-2">
          <label className="flex-1 cursor-pointer">
            <div className="flex items-center justify-center gap-2 rounded-lg border-2 border-dashed border-gray-300 px-4 py-3 hover:border-blue-500 dark:border-gray-600 dark:hover:border-blue-400">
              <svg className="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <span className="text-sm text-gray-600 dark:text-gray-400">
                {(config.image as string) ? "Change Image" : "Upload Image"}
              </span>
            </div>
            <input
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) {
                  // Check file size (max 2MB)
                  if (file.size > 2 * 1024 * 1024) {
                    alert("Image size must be less than 2MB");
                    return;
                  }
                  const reader = new FileReader();
                  reader.onload = (event) => {
                    const base64 = event.target?.result as string;
                    onUpdate("image", base64);
                  };
                  reader.readAsDataURL(file);
                }
              }}
            />
          </label>
        </div>
        <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
          Max 2MB. Supported: JPG, PNG, GIF, WebP
        </p>
      </div>

      {/* Button (Max 1) */}
      <div>
        <div className="mb-2 flex items-center justify-between">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Action Button
          </label>
          {buttons.length === 0 && (
            <button
              onClick={() => onUpdate("buttons", [{ text: "OK", action: "dismiss", target: "" }])}
              className="text-sm text-blue-600 hover:text-blue-700 dark:text-blue-400"
            >
              + Add Button
            </button>
          )}
        </div>
        
        {buttons.length > 0 && (
          <div className="space-y-3 rounded-lg border border-gray-200 p-4 dark:border-gray-700">
            {/* Button Text */}
            <div>
              <label className="mb-1 block text-xs text-gray-500 dark:text-gray-400">Button Text</label>
              <input
                type="text"
                value={buttons[0]?.text || ""}
                onChange={(e) => {
                  const newButtons = [...buttons];
                  newButtons[0] = { ...newButtons[0], text: e.target.value };
                  onUpdate("buttons", newButtons);
                }}
                placeholder="Button text"
                className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
            </div>
            
            {/* Button Action */}
            <div>
              <label className="mb-1 block text-xs text-gray-500 dark:text-gray-400">Button Action</label>
              <select
                value={buttons[0]?.action || "dismiss"}
                onChange={(e) => {
                  const newButtons = [...buttons];
                  newButtons[0] = { ...newButtons[0], action: e.target.value, target: "" };
                  onUpdate("buttons", newButtons);
                }}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              >
                <option value="dismiss">Dismiss (Close Popup)</option>
                <option value="open_url">Open URL (External Link)</option>
                <option value="update">Update (Open Play Store)</option>
              </select>
            </div>
            
            {/* URL Input (only for open_url) */}
            {buttons[0]?.action === "open_url" && (
              <div>
                <label className="mb-1 block text-xs text-gray-500 dark:text-gray-400">URL to Open</label>
                <input
                  type="url"
                  value={buttons[0]?.target || ""}
                  onChange={(e) => {
                    const newButtons = [...buttons];
                    newButtons[0] = { ...newButtons[0], target: e.target.value };
                    onUpdate("buttons", newButtons);
                  }}
                  onBlur={(e) => {
                    // Auto-add https:// if missing
                    let url = e.target.value.trim();
                    if (url && !url.startsWith('http://') && !url.startsWith('https://')) {
                      url = 'https://' + url;
                      const newButtons = [...buttons];
                      newButtons[0] = { ...newButtons[0], target: url };
                      onUpdate("buttons", newButtons);
                    }
                  }}
                  placeholder="https://example.com"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                />
                <p className="mt-1 text-xs text-gray-500">⚠️ URL must start with https:// (auto-added if missing)</p>
              </div>
            )}
            
            {/* Remove Button */}
            <button
              onClick={() => onUpdate("buttons", [])}
              className="flex items-center gap-1 text-sm text-red-500 hover:text-red-600"
            >
              <X className="h-4 w-4" />
              Remove Button
            </button>
          </div>
        )}
        
        {buttons.length === 0 && (
          <p className="text-sm text-gray-500 dark:text-gray-400">No button added. Click "+ Add Button" to add one.</p>
        )}
      </div>

      {/* Dismissible */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <div className="flex items-center gap-3">
          <input
            type="checkbox"
            id="dismissible"
            checked={config.is_dismissible as boolean ?? true}
            onChange={(e) => onUpdate("is_dismissible", e.target.checked)}
            className="h-5 w-5 rounded border-gray-300 text-blue-600"
          />
          <div>
            <label htmlFor="dismissible" className="text-sm font-medium text-gray-700 dark:text-gray-300">
              Allow user to dismiss
            </label>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {(config.is_dismissible as boolean ?? true) 
                ? "✅ User can tap outside or press back to close" 
                : "🔒 User must click the button to close"}
            </p>
          </div>
        </div>
      </div>

      {/* Color Customization */}
      <div className="border-t border-gray-200 pt-6 dark:border-gray-700">
        <h4 className="mb-4 text-sm font-semibold text-gray-900 dark:text-white">🎨 Color Customization</h4>
        
        <div className="grid grid-cols-2 gap-4">
          {/* Title Color */}
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Title Color
            </label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={(config.title_color as string) || "#FFFFFF"}
                onChange={(e) => onUpdate("title_color", e.target.value)}
                className="h-10 w-14 cursor-pointer rounded border border-gray-300 dark:border-gray-600"
              />
              <input
                type="text"
                value={(config.title_color as string) || "#FFFFFF"}
                onChange={(e) => onUpdate("title_color", e.target.value)}
                placeholder="#FFFFFF"
                className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
            </div>
          </div>

          {/* Message Color */}
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Message Color
            </label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={(config.message_color as string) || "#E0E0E0"}
                onChange={(e) => onUpdate("message_color", e.target.value)}
                className="h-10 w-14 cursor-pointer rounded border border-gray-300 dark:border-gray-600"
              />
              <input
                type="text"
                value={(config.message_color as string) || "#E0E0E0"}
                onChange={(e) => onUpdate("message_color", e.target.value)}
                placeholder="#E0E0E0"
                className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
            </div>
          </div>

          {/* Button Background Color */}
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Button Background
            </label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={(config.button_color as string) || "#7C3AED"}
                onChange={(e) => onUpdate("button_color", e.target.value)}
                className="h-10 w-14 cursor-pointer rounded border border-gray-300 dark:border-gray-600"
              />
              <input
                type="text"
                value={(config.button_color as string) || "#7C3AED"}
                onChange={(e) => onUpdate("button_color", e.target.value)}
                placeholder="#7C3AED"
                className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
            </div>
          </div>

          {/* Button Text Color */}
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Button Text Color
            </label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={(config.button_text_color as string) || "#FFFFFF"}
                onChange={(e) => onUpdate("button_text_color", e.target.value)}
                className="h-10 w-14 cursor-pointer rounded border border-gray-300 dark:border-gray-600"
              />
              <input
                type="text"
                value={(config.button_text_color as string) || "#FFFFFF"}
                onChange={(e) => onUpdate("button_text_color", e.target.value)}
                placeholder="#FFFFFF"
                className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
            </div>
          </div>
        </div>

        {/* Live Preview - Changes based on Display Type */}
        <div className="mt-4">
          <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">
            📱 Live Preview - <span className="font-semibold text-blue-500">
              {(config.display_type as string) === "fullscreen" ? "Full Screen" : 
               (config.display_type as string) === "bottom_sheet" ? "Bottom Sheet" : "Popup Dialog"}
            </span>
          </p>
          
          {/* Phone Frame */}
          <div className="flex justify-center">
            <div 
              className="relative overflow-hidden shadow-2xl"
              style={{ 
                width: '220px',
                height: '440px',
                backgroundColor: '#0f0f1a',
                borderRadius: '24px',
                border: '6px solid #1f1f2e',
              }}
            >
              {/* Status bar */}
              <div className="absolute top-0 left-0 right-0 h-6 flex items-center justify-between px-4 z-30" style={{ backgroundColor: 'rgba(0,0,0,0.3)' }}>
                <span className="text-[8px] text-white/70">9:17</span>
                <div className="flex items-center gap-1">
                  <div className="w-3 h-2 border border-white/50 rounded-sm">
                    <div className="w-2 h-1 bg-white/70 m-[1px]"></div>
                  </div>
                </div>
              </div>

              {/* ===== POPUP DIALOG STYLE ===== */}
              {((config.display_type as string) === "popup" || !(config.display_type as string)) && (
                <>
                  {/* Dark backdrop */}
                  <div className="absolute inset-0 top-6 bg-black/50 z-10"></div>
                  
                  {/* Center Dialog */}
                  <div className="absolute inset-6 top-12 bottom-12 flex items-center justify-center z-20">
                    <div 
                      className="relative w-full overflow-hidden"
                      style={{ 
                        borderRadius: '20px',
                        backgroundColor: '#1a1a2e',
                        maxHeight: '320px',
                      }}
                    >
                      {/* Background Image */}
                      {(config.image as string) && (
                        <div 
                          className="absolute inset-0"
                          style={{ 
                            backgroundImage: `url(${config.image as string})`,
                            backgroundSize: 'cover',
                            backgroundPosition: 'center',
                          }}
                        />
                      )}
                      
                      {/* Gradient overlay */}
                      <div className="absolute inset-0" style={{ background: 'linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(0,0,0,0.4) 100%)' }} />
                      
                      {/* Close button */}
                      {(config.is_dismissible as boolean ?? true) && (
                        <div className="absolute top-2 right-2 z-10">
                          <div className="w-6 h-6 rounded-full flex items-center justify-center" style={{ backgroundColor: 'rgba(255,255,255,0.15)' }}>
                            <X className="w-3 h-3 text-white/80" />
                          </div>
                        </div>
                      )}
                      
                      {/* Content */}
                      <div className="relative p-4 pt-16 z-10">
                        <p className="text-center font-bold" style={{ color: (config.title_color as string) || "#FFFFFF", fontSize: '14px' }}>
                          {getTextValue(config.title) || "Title"}
                        </p>
                        <p className="text-center mt-1" style={{ color: (config.message_color as string) || "#E0E0E0", fontSize: '10px', lineHeight: '1.4' }}>
                          {getTextValue(config.message) || "Message text..."}
                        </p>
                        {buttons.length > 0 && (
                          <button className="w-full mt-3 py-2 font-semibold text-xs" style={{ backgroundColor: (config.button_color as string) || "#7C3AED", color: (config.button_text_color as string) || "#FFFFFF", borderRadius: '12px' }}>
                            {buttons[0]?.text || "Button"}
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {/* ===== FULL SCREEN STYLE ===== */}
              {(config.display_type as string) === "fullscreen" && (
                <div className="absolute inset-0 top-6 z-10">
                  {/* Background Image - Full screen */}
                  {(config.image as string) && (
                    <div 
                      className="absolute inset-0"
                      style={{ 
                        backgroundImage: `url(${config.image as string})`,
                        backgroundSize: 'cover',
                        backgroundPosition: 'center',
                      }}
                    />
                  )}
                  
                  {/* Gradient overlay */}
                  <div className="absolute inset-0" style={{ background: 'linear-gradient(to bottom, rgba(0,0,0,0.2) 0%, rgba(0,0,0,0.5) 100%)' }} />
                  
                  {/* Close button */}
                  {(config.is_dismissible as boolean ?? true) && (
                    <div className="absolute top-2 right-3 z-10">
                      <div className="w-8 h-8 rounded-full flex items-center justify-center" style={{ backgroundColor: 'rgba(0,0,0,0.3)' }}>
                        <X className="w-5 h-5 text-white" />
                      </div>
                    </div>
                  )}
                  
                  {/* Content - Bottom */}
                  <div className="absolute bottom-8 left-0 right-0 p-6 z-10">
                    <p className="text-center font-bold" style={{ color: (config.title_color as string) || "#FFFFFF", fontSize: '18px' }}>
                      {getTextValue(config.title) || "Title"}
                    </p>
                    <p className="text-center mt-2" style={{ color: (config.message_color as string) || "#E0E0E0", fontSize: '11px', lineHeight: '1.5' }}>
                      {getTextValue(config.message) || "Message text..."}
                    </p>
                    {buttons.length > 0 && (
                      <button className="w-full mt-4 py-3 font-semibold text-sm" style={{ backgroundColor: (config.button_color as string) || "#7C3AED", color: (config.button_text_color as string) || "#FFFFFF", borderRadius: '14px' }}>
                        {buttons[0]?.text || "Button"}
                      </button>
                    )}
                  </div>
                </div>
              )}

              {/* ===== BOTTOM SHEET STYLE ===== */}
              {(config.display_type as string) === "bottom_sheet" && (
                <>
                  {/* Dark backdrop */}
                  <div className="absolute inset-0 top-6 bg-black/50 z-10"></div>
                  
                  {/* Bottom Sheet - 50% height */}
                  <div className="absolute bottom-0 left-0 right-0 z-20" style={{ borderTopLeftRadius: '24px', borderTopRightRadius: '24px', overflow: 'hidden', height: '50%' }}>
                    {/* Background */}
                    <div className="relative" style={{ backgroundColor: '#1a1a2e', minHeight: '200px' }}>
                      {/* Background Image */}
                      {(config.image as string) && (
                        <div 
                          className="absolute inset-0"
                          style={{ 
                            backgroundImage: `url(${config.image as string})`,
                            backgroundSize: 'cover',
                            backgroundPosition: 'center',
                          }}
                        />
                      )}
                      
                      {/* Gradient overlay */}
                      <div className="absolute inset-0" style={{ background: 'linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(0,0,0,0.5) 100%)' }} />
                      
                      {/* Handle bar */}
                      <div className="absolute top-3 left-1/2 -translate-x-1/2 w-10 h-1 bg-white/40 rounded-full z-10"></div>
                      
                      {/* Close button */}
                      {(config.is_dismissible as boolean ?? true) && (
                        <div className="absolute top-2 right-2 z-10">
                          <div className="w-6 h-6 rounded-full flex items-center justify-center" style={{ backgroundColor: 'rgba(255,255,255,0.15)' }}>
                            <X className="w-3 h-3 text-white/80" />
                          </div>
                        </div>
                      )}
                      
                      {/* Content */}
                      <div className="relative p-4 pt-10 pb-6 z-10">
                        <p className="text-center font-bold" style={{ color: (config.title_color as string) || "#FFFFFF", fontSize: '14px' }}>
                          {getTextValue(config.title) || "Title"}
                        </p>
                        <p className="text-center mt-2" style={{ color: (config.message_color as string) || "#E0E0E0", fontSize: '10px', lineHeight: '1.4' }}>
                          {getTextValue(config.message) || "Message text..."}
                        </p>
                        {buttons.length > 0 && (
                          <button className="w-full mt-4 py-2.5 font-semibold text-xs" style={{ backgroundColor: (config.button_color as string) || "#7C3AED", color: (config.button_text_color as string) || "#FFFFFF", borderRadius: '12px' }}>
                            {buttons[0]?.text || "Button"}
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                </>
              )}
              
              {/* Home indicator */}
              <div className="absolute bottom-2 left-1/2 -translate-x-1/2 w-16 h-1 bg-white/30 rounded-full z-30"></div>
            </div>
          </div>
          
          {/* Legend */}
          <div className="mt-4 flex justify-center gap-4 text-xs text-gray-500 dark:text-gray-400">
            <div className="flex items-center gap-1">
              <span className="w-3 h-3 rounded" style={{ backgroundColor: (config.title_color as string) || "#FFFFFF" }}></span>
              Title
            </div>
            <div className="flex items-center gap-1">
              <span className="w-3 h-3 rounded" style={{ backgroundColor: (config.message_color as string) || "#E0E0E0" }}></span>
              Message
            </div>
            <div className="flex items-center gap-1">
              <span className="w-3 h-3 rounded" style={{ backgroundColor: (config.button_color as string) || "#7C3AED" }}></span>
              Button
            </div>
          </div>
          
          {/* Status */}
          <div className="mt-2 text-center">
            <span className={`text-xs px-3 py-1 rounded-full ${(config.is_dismissible as boolean ?? true) ? 'bg-green-500/10 text-green-500' : 'bg-red-500/10 text-red-500'}`}>
              {(config.is_dismissible as boolean ?? true) ? "✓ User can tap X or outside to close" : "✗ User must click button to close"}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

// Banned Screen Editor
function BannedScreenEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const supportButton = (config.support_button as {text: string; url: string}) || { text: "", url: "" };
  const quitButton = (config.quit_button as {text: string}) || { text: "" };
  const showQuitButton = (config.show_quit_button as boolean) ?? true;

  return (
    <div className="space-y-6">
      {/* Info Banner */}
      <div className="rounded-lg bg-red-50 p-4 dark:bg-red-900/20 border border-red-200 dark:border-red-800">
        <p className="text-sm text-red-700 dark:text-red-300">
          🚫 This screen shows when a user's device is banned. Uses white background with app logo.
        </p>
      </div>

      {/* Title & Message */}
      <div className="grid grid-cols-1 gap-4">
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Title
          </label>
          <input
            type="text"
            value={getTextValue(config.title)}
            onChange={(e) => onUpdate("title", e.target.value)}
            placeholder="Account Suspended"
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Message
          </label>
          <textarea
            value={getTextValue(config.message)}
            onChange={(e) => onUpdate("message", e.target.value)}
            rows={3}
            placeholder="Your account has been suspended..."
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
      </div>

      {/* Support Button */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h3 className="mb-3 font-medium text-gray-900 dark:text-white">Support Button</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-1 block text-sm text-gray-600 dark:text-gray-400">Button Text</label>
            <input
              type="text"
              value={getTextValue(supportButton.text)}
              onChange={(e) => onUpdate("support_button", { ...supportButton, text: e.target.value })}
              placeholder="Contact Support"
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm text-gray-600 dark:text-gray-400">URL</label>
            <input
              type="text"
              value={supportButton.url}
              onChange={(e) => onUpdate("support_button", { ...supportButton, url: e.target.value })}
              placeholder="https://t.me/support"
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
        </div>
      </div>

      {/* Quit Button */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-medium text-gray-900 dark:text-white">Quit Button</h3>
          <label className="relative inline-flex cursor-pointer items-center">
            <input
              type="checkbox"
              checked={showQuitButton}
              onChange={(e) => onUpdate("show_quit_button", e.target.checked)}
              className="peer sr-only"
            />
            <div className="peer h-6 w-11 rounded-full bg-gray-200 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-gray-300 after:bg-white after:transition-all after:content-[''] peer-checked:bg-blue-600 peer-checked:after:translate-x-full peer-focus:outline-none dark:bg-gray-600"></div>
        </label>
        </div>
        {showQuitButton && (
          <div>
            <label className="mb-1 block text-sm text-gray-600 dark:text-gray-400">Button Text</label>
        <input
          type="text"
          value={quitButton.text}
          onChange={(e) => onUpdate("quit_button", { text: e.target.value })}
              placeholder="Quit App"
          className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        />
      </div>
        )}
      </div>
    </div>
  );
}

// Server Maintenance Editor
function ServerMaintenanceEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const isEnabled = (config.enabled as boolean) ?? false;
  const showProgress = (config.show_progress as boolean) ?? true;

  return (
    <div className="space-y-6">
      {/* Enable/Disable Toggle */}
      <div className="flex items-center justify-between rounded-lg bg-amber-50 p-4 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800">
        <div>
          <p className="font-medium text-amber-900 dark:text-amber-100">
            🔧 Enable Maintenance Mode
          </p>
          <p className="text-sm text-amber-700 dark:text-amber-300">
            {isEnabled ? "⚠️ App will show maintenance screen & auto-disconnect VPN" : "Maintenance mode is disabled"}
          </p>
        </div>
        <label className="relative inline-flex cursor-pointer items-center">
          <input
            type="checkbox"
            checked={isEnabled}
            onChange={(e) => onUpdate("enabled", e.target.checked)}
            className="peer sr-only"
          />
          <div className="peer h-6 w-11 rounded-full bg-gray-200 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-gray-300 after:bg-white after:transition-all after:content-[''] peer-checked:bg-amber-500 peer-checked:after:translate-x-full peer-focus:outline-none dark:bg-gray-600"></div>
        </label>
      </div>

      {/* Info Banner */}
      <div className="rounded-lg bg-blue-50 p-3 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800">
        <p className="text-sm text-blue-700 dark:text-blue-300">
          ℹ️ Uses white background with app logo, progress bar, and text only.
        </p>
      </div>

      {/* Title & Message */}
      <div className="grid grid-cols-1 gap-4">
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Title
          </label>
          <input
            type="text"
            value={getTextValue(config.title)}
            onChange={(e) => onUpdate("title", e.target.value)}
            placeholder="Under Maintenance"
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Message
          </label>
          <textarea
            value={getTextValue(config.message)}
            onChange={(e) => onUpdate("message", e.target.value)}
            rows={3}
            placeholder="We're currently performing scheduled maintenance..."
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
      </div>

      {/* Estimated Time */}
      <div>
        <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
          Estimated Time (optional)
        </label>
        <input
          type="text"
          value={getTextValue(config.estimated_time)}
          onChange={(e) => onUpdate("estimated_time", e.target.value)}
          placeholder="e.g., 2 hours, 30 minutes"
          className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        />
      </div>

      {/* Show Progress Toggle */}
      <div className="flex items-center justify-between rounded-lg bg-gray-50 p-4 dark:bg-gray-700/50">
        <div>
          <p className="font-medium text-gray-900 dark:text-white">Show Progress Bar</p>
          <p className="text-sm text-gray-500 dark:text-gray-400">Display animated loading indicator</p>
        </div>
        <label className="relative inline-flex cursor-pointer items-center">
          <input
            type="checkbox"
            checked={showProgress}
            onChange={(e) => onUpdate("show_progress", e.target.checked)}
            className="peer sr-only"
          />
          <div className="peer h-6 w-11 rounded-full bg-gray-200 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-gray-300 after:bg-white after:transition-all after:content-[''] peer-checked:bg-blue-600 peer-checked:after:translate-x-full peer-focus:outline-none dark:bg-gray-600"></div>
        </label>
      </div>

      {/* Progress Text */}
      {showProgress && (
          <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Progress Text
          </label>
              <input
                type="text"
            value={getTextValue(config.progress_text)}
            onChange={(e) => onUpdate("progress_text", e.target.value)}
            placeholder="Working on it..."
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
          </div>
        )}
    </div>
  );
}

// Home Screen Editor
function HomeScreenEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const appBar = (config.app_bar as Record<string, string>) || {};
  const mainButton = (config.main_button as Record<string, string>) || {};
  const timerSection = (config.timer_section as Record<string, boolean>) || {};

  return (
    <div className="space-y-6">
      {/* App Bar Settings */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h3 className="mb-3 font-medium text-gray-900 dark:text-white">🌐 App Bar Titles (Multi-Language)</h3>
        <div className="space-y-4">
          <MultiLanguageTextInput
            label="Disconnected Title"
            value={appBar.title_disconnected}
            onChange={(value) => onUpdate("app_bar.title_disconnected", value)}
            placeholder="Not Connected"
            />
          <MultiLanguageTextInput
            label="Connecting Title"
            value={appBar.title_connecting}
            onChange={(value) => onUpdate("app_bar.title_connecting", value)}
            placeholder="Connecting..."
            />
          <MultiLanguageTextInput
            label="Connected Title"
            value={appBar.title_connected}
            onChange={(value) => onUpdate("app_bar.title_connected", value)}
            placeholder="Connected"
            />
        </div>
      </div>

      {/* Main Button */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h3 className="mb-3 font-medium text-gray-900 dark:text-white">🌐 Main Button Text (Multi-Language)</h3>
        <div className="space-y-4">
          <MultiLanguageTextInput
            label="Disconnected Status"
            value={mainButton.status_text_disconnected}
            onChange={(value) => onUpdate("main_button.status_text_disconnected", value)}
            placeholder="Tap to Connect"
            />
          <MultiLanguageTextInput
            label="Connecting Status"
            value={mainButton.status_text_connecting}
            onChange={(value) => onUpdate("main_button.status_text_connecting", value)}
            placeholder="Establishing Connection..."
            />
          <MultiLanguageTextInput
            label="Connected Status"
            value={mainButton.status_text_connected}
            onChange={(value) => onUpdate("main_button.status_text_connected", value)}
            placeholder="VPN is On"
            />
        </div>
      </div>

      {/* Timer Section */}
      <div className="flex items-center gap-3">
        <input
          type="checkbox"
          id="show_timer"
          checked={timerSection.show_timer || false}
          onChange={(e) => onUpdate("timer_section.show_timer", e.target.checked)}
          className="h-4 w-4 rounded border-gray-300 text-blue-600"
        />
        <label htmlFor="show_timer" className="text-sm text-gray-700 dark:text-gray-300">
          Show Timer Section
        </label>
      </div>
    </div>
  );
}

// Rewards Screen Editor
function RewardsScreenEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const paymentMethods = (config.payment_methods as string[]) || [];
  const labels = (config.labels as Record<string, string>) || {};

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Title
          </label>
          <input
            type="text"
            value={getTextValue(config.title)}
            onChange={(e) => onUpdate("title", e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Min Withdraw (MMK)
          </label>
          <input
            type="number"
            value={(config.min_withdraw_mmk as number) || 20000}
            onChange={(e) => onUpdate("min_withdraw_mmk", parseInt(e.target.value))}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
      </div>

      {/* Payment Methods */}
      <div>
        <div className="mb-2 flex items-center justify-between">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Payment Methods
          </label>
          <button
            onClick={() => onUpdate("payment_methods", [...paymentMethods, "New Method"])}
            className="text-sm text-blue-600 hover:text-blue-700"
          >
            + Add Method
          </button>
        </div>
        <div className="space-y-2">
          {paymentMethods.map((method, index) => (
            <div key={index} className="flex items-center gap-2">
              <input
                type="text"
                value={method}
                onChange={(e) => {
                  const newMethods = [...paymentMethods];
                  newMethods[index] = e.target.value;
                  onUpdate("payment_methods", newMethods);
                }}
                className="flex-1 rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              />
              <button
                onClick={() => {
                  const newMethods = paymentMethods.filter((_, i) => i !== index);
                  onUpdate("payment_methods", newMethods);
                }}
                className="rounded-lg p-2 text-red-500 hover:bg-red-50"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Labels */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h3 className="mb-3 font-medium text-gray-900 dark:text-white">Labels</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-1 block text-sm text-gray-600 dark:text-gray-400">Balance Label</label>
            <input
              type="text"
              value={labels.balance_label || ""}
              onChange={(e) => onUpdate("labels.balance_label", e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm text-gray-600 dark:text-gray-400">Withdraw Button</label>
            <input
              type="text"
              value={labels.withdraw_button || ""}
              onChange={(e) => onUpdate("labels.withdraw_button", e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
        </div>
      </div>
    </div>
  );
}

// Earn Money Screen Editor
function EarnMoneyEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  // Convert seconds to hours for display
  const timeBonusSeconds = (config.time_bonus_seconds as number) || 7200;
  const timeBonusHours = timeBonusSeconds / 3600;

  return (
    <div className="space-y-6">
      <div>
        <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
          Title
        </label>
        <input
          type="text"
          value={getTextValue(config.title)}
          onChange={(e) => onUpdate("title", e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        />
      </div>

      {/* Points Rewards */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h4 className="mb-3 text-sm font-semibold text-gray-900 dark:text-white">💰 Points Rewards</h4>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Reward Per Ad (Points)
            </label>
            <input
              type="number"
              value={(config.reward_per_ad as number) || 30}
              onChange={(e) => onUpdate("reward_per_ad", parseInt(e.target.value))}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
            <p className="mt-1 text-xs text-gray-500">Points earned per ad watch</p>
          </div>
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Max Ads Per Day
            </label>
            <input
              type="number"
              value={(config.max_ads_per_day as number) || 100}
              onChange={(e) => onUpdate("max_ads_per_day", parseInt(e.target.value))}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
            <p className="mt-1 text-xs text-gray-500">Daily ad watch limit</p>
          </div>
        </div>
      </div>

      {/* VPN Time Bonus */}
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-4 dark:border-blue-700 dark:bg-blue-900/20">
        <h4 className="mb-3 text-sm font-semibold text-blue-900 dark:text-blue-300">⏱️ VPN Time Bonus (VPN Page Ads Only)</h4>
        <p className="mb-3 text-xs text-blue-700 dark:text-blue-400">
          This time bonus is ONLY given when user watches ads from VPN connection page (when no connection time left).
          Earn Money screen ads only give points, not VPN time.
        </p>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              VPN Time Bonus (Hours)
            </label>
            <input
              type="number"
              step="0.5"
              min="0"
              value={timeBonusHours}
              onChange={(e) => onUpdate("time_bonus_seconds", parseFloat(e.target.value) * 3600)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
            <p className="mt-1 text-xs text-gray-500">Hours of VPN time per ad ({timeBonusSeconds} seconds)</p>
          </div>
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Quick Select
            </label>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => onUpdate("time_bonus_seconds", 1800)}
                className={`rounded px-3 py-2 text-sm ${timeBonusSeconds === 1800 ? 'bg-blue-500 text-white' : 'bg-gray-200 dark:bg-gray-700'}`}
              >
                30m
              </button>
              <button
                type="button"
                onClick={() => onUpdate("time_bonus_seconds", 3600)}
                className={`rounded px-3 py-2 text-sm ${timeBonusSeconds === 3600 ? 'bg-blue-500 text-white' : 'bg-gray-200 dark:bg-gray-700'}`}
              >
                1h
              </button>
              <button
                type="button"
                onClick={() => onUpdate("time_bonus_seconds", 7200)}
                className={`rounded px-3 py-2 text-sm ${timeBonusSeconds === 7200 ? 'bg-blue-500 text-white' : 'bg-gray-200 dark:bg-gray-700'}`}
              >
                2h
              </button>
              <button
                type="button"
                onClick={() => onUpdate("time_bonus_seconds", 14400)}
                className={`rounded px-3 py-2 text-sm ${timeBonusSeconds === 14400 ? 'bg-blue-500 text-white' : 'bg-gray-200 dark:bg-gray-700'}`}
              >
                4h
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Cooldown Settings */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h4 className="mb-3 text-sm font-semibold text-gray-900 dark:text-white">⏳ Cooldown Settings</h4>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Ads Before Cooldown
            </label>
            <input
              type="number"
              value={(config.cooldown_ads_count as number) || 10}
              onChange={(e) => onUpdate("cooldown_ads_count", parseInt(e.target.value))}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
            <p className="mt-1 text-xs text-gray-500">Number of ads before cooldown starts</p>
          </div>
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Cooldown Duration (Minutes)
            </label>
            <input
              type="number"
              value={(config.cooldown_minutes as number) || 10}
              onChange={(e) => onUpdate("cooldown_minutes", parseInt(e.target.value))}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
            <p className="mt-1 text-xs text-gray-500">Wait time after cooldown starts</p>
          </div>
        </div>
      </div>
    </div>
  );
}

// Splash Screen Editor
function SplashScreenEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const gradientColors = (config.gradient_colors as string[]) || ["#7E57C2", "#B39DDB"];

  return (
    <div className="space-y-6">
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            App Name
          </label>
          <input
            type="text"
            value={(config.app_name as string) || ""}
            onChange={(e) => onUpdate("app_name", e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>

      {/* Multi-Language Tagline */}
      <MultiLanguageTextInput
        label="Tagline"
        value={config.tagline}
        onChange={(value) => onUpdate("tagline", value)}
        placeholder="Secure & Fast"
          />

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Logo Path
          </label>
          <input
            type="text"
            value={(config.logo_path as string) || ""}
            onChange={(e) => onUpdate("logo_path", e.target.value)}
            placeholder="assets/images/logo.png"
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Duration (seconds)
          </label>
          <input
            type="number"
            value={(config.splash_duration_seconds as number) || 3}
            onChange={(e) => onUpdate("splash_duration_seconds", parseInt(e.target.value))}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
      </div>

      {/* Gradient Colors */}
      <div>
        <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
          Background Gradient
        </label>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <input
              type="color"
              value={gradientColors[0]}
              onChange={(e) => onUpdate("gradient_colors", [e.target.value, gradientColors[1]])}
              className="h-10 w-10 cursor-pointer rounded border-0"
            />
            <input
              type="text"
              value={gradientColors[0]}
              onChange={(e) => onUpdate("gradient_colors", [e.target.value, gradientColors[1]])}
              className="w-24 rounded-lg border border-gray-300 px-2 py-1 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
          <span className="text-gray-400">→</span>
          <div className="flex items-center gap-2">
            <input
              type="color"
              value={gradientColors[1]}
              onChange={(e) => onUpdate("gradient_colors", [gradientColors[0], e.target.value])}
              className="h-10 w-10 cursor-pointer rounded border-0"
            />
            <input
              type="text"
              value={gradientColors[1]}
              onChange={(e) => onUpdate("gradient_colors", [gradientColors[0], e.target.value])}
              className="w-24 rounded-lg border border-gray-300 px-2 py-1 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
        </div>
      </div>

      {/* Preview */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h3 className="mb-3 font-medium text-gray-900 dark:text-white">Preview</h3>
        <div 
          className="mx-auto h-40 w-32 rounded-xl flex flex-col items-center justify-center"
          style={{
            background: `linear-gradient(135deg, ${gradientColors[0]}, ${gradientColors[1]})`
          }}
        >
          <span className="text-xl font-bold text-white">{getTextValue(config.app_name) || "Suk Fhyoke"}</span>
          <span className="text-xs text-white/70">{getTextValue(config.tagline) || "Secure & Fast"}</span>
        </div>
      </div>
    </div>
  );
}

// Onboarding Editor
function OnboardingEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const pages = (config.pages as Array<{title: string; description: string; image: string}>) || [];
  const buttons = (config.buttons as Record<string, string>) || {};

  return (
    <div className="space-y-6">
      {/* Pages */}
      <div>
        <div className="mb-3 flex items-center justify-between">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Onboarding Pages ({pages.length})
          </label>
          <button
            onClick={() => onUpdate("pages", [...pages, { title: "New Page", description: "Description", image: "" }])}
            className="text-sm text-blue-600 hover:text-blue-700"
          >
            + Add Page
          </button>
        </div>
        <div className="space-y-4">
          {pages.map((page, index) => (
            <div key={index} className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
              <div className="mb-3 flex items-center justify-between">
                <span className="text-sm font-medium text-gray-500">Page {index + 1}</span>
                <button
                  onClick={() => onUpdate("pages", pages.filter((_, i) => i !== index))}
                  className="text-red-500 hover:text-red-600"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
              <div className="space-y-3">
                <div>
                  <label className="mb-1 block text-xs text-gray-500">Title</label>
                  <input
                    type="text"
                    value={getTextValue(page.title)}
                    onChange={(e) => {
                      const newPages = [...pages];
                      newPages[index] = { ...page, title: e.target.value };
                      onUpdate("pages", newPages);
                    }}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-xs text-gray-500">Description</label>
                  <textarea
                    value={getTextValue(page.description)}
                    onChange={(e) => {
                      const newPages = [...pages];
                      newPages[index] = { ...page, description: e.target.value };
                      onUpdate("pages", newPages);
                    }}
                    rows={2}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                  />
                </div>
                {/* Direct Image Upload */}
                <div>
                  <label className="mb-1 block text-xs text-gray-500">Image (Direct Upload)</label>
                  <div className="flex items-center gap-3">
                    {page.image && page.image.startsWith('data:') && (
                      <img src={page.image} alt="Preview" className="h-16 w-16 rounded object-cover" />
                    )}
                    <label className="cursor-pointer rounded-lg border border-dashed border-gray-300 px-4 py-2 text-sm text-gray-600 hover:border-blue-500 hover:text-blue-500 dark:border-gray-600 dark:text-gray-400">
                      {page.image ? "Change Image" : "Upload Image"}
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) {
                            if (file.size > 2 * 1024 * 1024) {
                              alert("Image size must be less than 2MB");
                              return;
                            }
                            const reader = new FileReader();
                            reader.onload = (event) => {
                              const base64 = event.target?.result as string;
                              const newPages = [...pages];
                              newPages[index] = { ...page, image: base64 };
                              onUpdate("pages", newPages);
                            };
                            reader.readAsDataURL(file);
                          }
                        }}
                      />
                    </label>
                    {page.image && (
                      <button
                        onClick={() => {
                          const newPages = [...pages];
                          newPages[index] = { ...page, image: "" };
                          onUpdate("pages", newPages);
                        }}
                        className="text-red-500 hover:text-red-600"
                      >
                        <X className="h-4 w-4" />
                      </button>
                    )}
                  </div>
                  <p className="mt-1 text-xs text-gray-400">Max 2MB. Supported: JPG, PNG, GIF, WebP</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Button Labels - Removed Skip */}
      <div className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
        <h3 className="mb-3 font-medium text-gray-900 dark:text-white">Button Labels</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-1 block text-sm text-gray-600 dark:text-gray-400">Next</label>
            <input
              type="text"
              value={getTextValue(buttons.next)}
              onChange={(e) => onUpdate("buttons.next", e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm text-gray-600 dark:text-gray-400">Get Started</label>
            <input
              type="text"
              value={getTextValue(buttons.get_started)}
              onChange={(e) => onUpdate("buttons.get_started", e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            />
          </div>
        </div>
      </div>
    </div>
  );
}

// Settings Screen Editor
interface SettingsItem {
  id: string;
  label: string;
  type: string;
  default?: unknown;
  url?: string;
}

interface SettingsSection {
  title: string;
  items: SettingsItem[];
}

function SettingsScreenEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const sections = (config.sections as SettingsSection[]) || [];
  const themeOptions = (config.theme_options as string[]) || ["System", "Light", "Dark"];
  const languageOptions = (config.language_options as string[]) || ["English", "Myanmar"];

  const getItemLabel = (item: SettingsItem | string): string => {
    if (typeof item === 'string') return item;
    return item.label || item.id || 'Unknown';
  };

  return (
    <div className="space-y-6">
      {/* Multi-Language Title */}
      <MultiLanguageTextInput
        label="Title"
        value={config.title}
        onChange={(value) => onUpdate("title", value)}
        placeholder="Settings"
        />

      {/* Sections */}
      <div>
        <div className="mb-3 flex items-center justify-between">
          <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Settings Sections ({sections.length})
          </label>
          <button
            onClick={() => onUpdate("sections", [...sections, { title: "New Section", items: [] }])}
            className="text-sm text-blue-600 hover:text-blue-700"
          >
            + Add Section
          </button>
        </div>
        <div className="space-y-4">
          {sections.map((section, index) => (
            <div key={index} className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
              <div className="mb-3 flex items-center justify-between">
                <input
                  type="text"
                  value={section.title}
                  onChange={(e) => {
                    const newSections = [...sections];
                    newSections[index] = { ...section, title: e.target.value };
                    onUpdate("sections", newSections);
                  }}
                  className="font-medium rounded-lg border border-gray-300 px-2 py-1 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                />
                <button
                  onClick={() => onUpdate("sections", sections.filter((_, i) => i !== index))}
                  className="text-red-500 hover:text-red-600"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
              <div className="space-y-2">
                {section.items.map((item, itemIndex) => (
                  <div key={itemIndex} className="flex items-center justify-between rounded-lg bg-gray-50 px-3 py-2 dark:bg-gray-700/50">
                    <div className="flex items-center gap-3">
                      <span className="text-sm font-medium text-gray-900 dark:text-white">{getItemLabel(item)}</span>
                      {typeof item === 'object' && (
                        <span className="rounded bg-gray-200 px-2 py-0.5 text-xs text-gray-600 dark:bg-gray-600 dark:text-gray-300">
                          {item.type}
                        </span>
                      )}
                    </div>
                    <button
                      onClick={() => {
                        const newSections = [...sections];
                        newSections[index] = {
                          ...section,
                          items: section.items.filter((_, i) => i !== itemIndex)
                        };
                        onUpdate("sections", newSections);
                      }}
                      className="text-gray-400 hover:text-red-500"
                    >
                      <X className="h-4 w-4" />
                    </button>
                  </div>
                ))}
                <button
                  onClick={() => {
                    const newLabel = prompt("Enter item label:");
                    if (newLabel) {
                      const newId = newLabel.toLowerCase().replace(/\s+/g, '_');
                      const newItem: SettingsItem = {
                        id: newId,
                        label: newLabel,
                        type: 'toggle',
                        default: false
                      };
                      const newSections = [...sections];
                      newSections[index] = {
                        ...section,
                        items: [...section.items, newItem]
                      };
                      onUpdate("sections", newSections);
                    }
                  }}
                  className="w-full rounded-lg border-2 border-dashed border-gray-300 py-2 text-sm text-gray-400 hover:border-blue-400 hover:text-blue-500"
                >
                  + Add Item
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Theme & Language Options */}
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Theme Options
          </label>
          <input
            type="text"
            value={themeOptions.join(", ")}
            onChange={(e) => onUpdate("theme_options", e.target.value.split(",").map(s => s.trim()))}
            placeholder="System, Light, Dark"
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Language Options
          </label>
          <input
            type="text"
            value={languageOptions.join(", ")}
            onChange={(e) => onUpdate("language_options", e.target.value.split(",").map(s => s.trim()))}
            placeholder="English, Myanmar"
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
      </div>
    </div>
  );
}


// Generic Editor (fallback)
function GenericEditor({
  config,
  onUpdate,
}: {
  config: Record<string, unknown>;
  onUpdate: (path: string, value: unknown) => void;
}) {
  const renderField = (key: string, value: unknown, path: string = key) => {
    if (typeof value === "string") {
      return (
        <div key={key}>
          <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300 capitalize">
            {key.replace(/_/g, " ")}
          </label>
          <input
            type="text"
            value={value}
            onChange={(e) => onUpdate(path, e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
      );
    }
    if (typeof value === "number") {
      return (
        <div key={key}>
          <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300 capitalize">
            {key.replace(/_/g, " ")}
          </label>
          <input
            type="number"
            value={value}
            onChange={(e) => onUpdate(path, parseFloat(e.target.value))}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          />
        </div>
      );
    }
    if (typeof value === "boolean") {
      return (
        <div key={key} className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={value}
            onChange={(e) => onUpdate(path, e.target.checked)}
            className="h-4 w-4 rounded border-gray-300 text-blue-600"
          />
          <label className="text-sm text-gray-700 dark:text-gray-300 capitalize">
            {key.replace(/_/g, " ")}
          </label>
        </div>
      );
    }
    if (typeof value === "object" && value !== null && !Array.isArray(value)) {
      return (
        <div key={key} className="rounded-lg border border-gray-200 p-4 dark:border-gray-700">
          <h4 className="mb-3 font-medium text-gray-900 dark:text-white capitalize">{key.replace(/_/g, " ")}</h4>
          <div className="space-y-3">
            {Object.entries(value as Record<string, unknown>).map(([k, v]) =>
              renderField(k, v, `${path}.${k}`)
            )}
          </div>
        </div>
      );
    }
    return null;
  };

  return (
    <div className="space-y-4">
      {Object.entries(config).map(([key, value]) => renderField(key, value))}
      {Object.keys(config).length === 0 && (
        <p className="text-center text-gray-500 dark:text-gray-400">
          No fields to edit. Use JSON mode to add content.
        </p>
      )}
    </div>
  );
}
