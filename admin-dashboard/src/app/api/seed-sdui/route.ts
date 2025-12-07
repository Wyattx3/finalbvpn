import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

// All SDUI configs from the Flutter app
const ALL_SDUI_CONFIGS = {
  onboarding: {
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
        description: "Your data is protected with\nmilitary-grade encryption.",
        image: "assets/images/onboarding/Secure & Private.png"
      },
      {
        title: "Earn Rewards",
        description: "Watch ads and earn rewards\nthat you can withdraw.",
        image: "assets/images/onboarding/earn rewards.jpg"
      }
    ],
    buttons: {
      skip: "Skip",
      next: "Next",
      get_started: "Get Started"
    }
  },

  home: {
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
  },

  rewards: {
    title: "My Rewards",
    payment_methods: ["KBZ Pay", "Wave Pay", "AYA Pay"],
    min_withdraw_mmk: 20000,
    min_withdraw_usd: 5,
    labels: {
      balance_label: "Total Points",
      withdraw_button: "Withdraw Now",
      history_button: "View History"
    }
  },

  splash: {
    app_name: "BVPN",
    tagline: "Secure & Fast",
    gradient_colors: ["#7E57C2", "#B39DDB"],
    splash_duration_seconds: 3,
    show_loading: true
  },

  popup_startup: {
    enabled: false,
    display_type: "popup",
    title: "Welcome!",
    message: "Welcome to BVPN - Your secure VPN solution",
    image: "",
    buttons: [
      { text: "Get Started", action: "dismiss" }
    ],
    is_dismissible: true,
    background_color: "#1A1625"
  },

  popup_update: {
    enabled: false,
    display_type: "fullscreen",
    title: "Update Available",
    message: "A new version of BVPN is available. Please update to continue using the app.",
    image: "",
    buttons: [
      { text: "Update Now", action: "update" },
      { text: "Later", action: "dismiss" }
    ],
    is_dismissible: false,
    force_update: false,
    min_version: "1.0.0",
    store_url: {
      android: "https://play.google.com/store/apps/details?id=com.example.vpn_app",
      ios: "https://apps.apple.com/app/bvpn"
    }
  },

  popup_promo: {
    enabled: false,
    display_type: "popup",
    title: "Special Offer!",
    message: "Watch 10 ads today and get bonus 100 points!",
    image: "",
    buttons: [
      { text: "Claim Now", action: "navigate", target: "earn_money" },
      { text: "Maybe Later", action: "dismiss" }
    ],
    is_dismissible: true,
    show_once_per_day: true
  },

  settings: {
    title: "Settings",
    sections: [
      {
        title: "General",
        items: [
          { id: "theme", label: "Theme", type: "toggle", default: "system" },
          { id: "language", label: "Language", type: "select", default: "en" }
        ]
      },
      {
        title: "VPN",
        items: [
          { id: "protocol", label: "Protocol", type: "select", default: "auto" },
          { id: "split_tunneling", label: "Split Tunneling", type: "toggle", default: false },
          { id: "auto_connect", label: "Auto Connect", type: "toggle", default: false }
        ]
      },
      {
        title: "Notifications",
        items: [
          { id: "vpn_status", label: "VPN Status", type: "toggle", default: true },
          { id: "rewards", label: "Rewards", type: "toggle", default: true }
        ]
      },
      {
        title: "About",
        items: [
          { id: "about", label: "About BVPN", type: "link" },
          { id: "privacy", label: "Privacy Policy", type: "link", url: "https://bvpn.app/privacy" },
          { id: "terms", label: "Terms of Service", type: "link", url: "https://bvpn.app/terms" },
          { id: "support", label: "Contact Support", type: "link", url: "https://t.me/bvpn_support" }
        ]
      }
    ]
  },

  earn_money: {
    title: "Earn Money",
    subtitle: "Watch ads and earn points",
    reward_per_ad: 30,
    time_bonus_seconds: 7200,
    max_ads_per_day: 100,
    cooldown_ads_count: 10,
    cooldown_minutes: 10,
    labels: {
      watch_ad_button: "Watch Ad",
      daily_progress: "Daily Progress",
      today_earned: "Today's Earnings",
      cooldown_message: "Please wait before watching more ads"
    }
  },


  banned_screen: {
    title: "Account Suspended",
    message: "Your account has been suspended due to violation of our terms of service. If you believe this is a mistake, please contact our support team.",
    image: "assets/images/banned.png",
    support_button: {
      text: "Contact Support",
      url: "https://t.me/bvpn_support"
    },
    quit_button: {
      text: "Quit App"
    },
    background_gradient: ["#1A1625", "#2D2640"]
  },

  withdraw_screen: {
    title: "Withdraw",
    min_amount_mmk: 20000,
    min_amount_usd: 5,
    exchange_rate: 1,
    processing_time: "24-48 hours",
    labels: {
      amount_label: "Amount",
      payment_method_label: "Payment Method",
      account_name_label: "Account Name",
      account_number_label: "Account Number",
      submit_button: "Submit Request",
      note: "Minimum withdrawal: 20,000 MMK"
    }
  },

  notification_settings: {
    title: "Notification Settings",
    categories: [
      { id: "vpn_status", label: "VPN Connection Status", enabled: true },
      { id: "rewards", label: "Reward Notifications", enabled: true },
      { id: "promotions", label: "Promotions & Offers", enabled: false },
      { id: "updates", label: "App Updates", enabled: true }
    ]
  }
};

export async function POST() {
  try {
    const batch = adminDb.batch();
    
    for (const [screenId, config] of Object.entries(ALL_SDUI_CONFIGS)) {
      const docRef = adminDb.collection('sdui_configs').doc(screenId);
      batch.set(docRef, {
        config,
        updatedAt: new Date(),
        createdAt: new Date(),
      }, { merge: true });
    }

    await batch.commit();

    return NextResponse.json({
      success: true,
      message: `Seeded ${Object.keys(ALL_SDUI_CONFIGS).length} SDUI configs`,
      configs: Object.keys(ALL_SDUI_CONFIGS),
    });
  } catch (error) {
    console.error('Error seeding SDUI configs:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to seed SDUI configs' },
      { status: 500 }
    );
  }
}

export async function GET() {
  return NextResponse.json({
    message: 'POST to this endpoint to seed all SDUI configs',
    configs: Object.keys(ALL_SDUI_CONFIGS),
  });
}

