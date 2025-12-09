import { NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

const SDUI_CONFIGS = [
  {
    id: 'splash',
    config: {
      app_name: 'Suk Fhyoke VPN',
      tagline: 'Secure & Fast',
      gradient_colors: ['#7E57C2', '#B39DDB'],
      splash_duration_seconds: 3,
      logo_path: 'assets/images/logo.png'
    }
  },
  {
    id: 'onboarding',
    config: {
      pages: [
        { title: 'Global Servers', description: 'Access content from around the world with our extensive server network.', image: 'assets/images/onboarding/Global servers.png' },
        { title: 'High Speed', description: 'Experience blazing fast connection speeds for streaming and gaming.', image: 'assets/images/onboarding/High Speed.png' },
        { title: 'Secure & Private', description: 'Your data is protected with military-grade encryption.', image: 'assets/images/onboarding/Secure & Private.png' },
        { title: 'Earn Rewards', description: 'Watch ads and earn rewards that you can withdraw.', image: 'assets/images/onboarding/earn rewards.jpg' }
      ],
      buttons: { next: 'Next', get_started: 'Get Started' }
    }
  },
  {
    id: 'settings',
    config: {
      title: 'Settings',
      sections: [
        { title: 'General', items: ['Theme', 'Language'] },
        { title: 'VPN', items: ['Protocol', 'Split Tunneling'] },
        { title: 'About', items: ['About', 'Privacy Policy', 'Terms of Service'] }
      ],
      theme_options: ['System', 'Light', 'Dark'],
      language_options: ['English', 'Myanmar']
    }
  },
  {
    id: 'rewards',
    config: {
      title: 'My Rewards',
      payment_methods: ['KBZ Pay', 'Wave Pay'],
      min_withdraw_mmk: 20000,
      labels: { balance_label: 'Total Points', withdraw_button: 'Withdraw Now' }
    }
  },
  {
    id: 'banned_screen',
    config: {
      title: 'Account Suspended',
      message: 'Your account has been suspended due to violation of our terms of service.',
      image: 'assets/images/banned.png',
      support_button: { text: 'Contact Support', url: 'https://t.me/bvpn_support' },
      quit_button: { text: 'Quit App' },
      background_gradient: ['#1A1625', '#2D2640']
    }
  },
  {
    id: 'popup_startup',
    config: {
      enabled: false,
      popup_type: 'announcement',
      display_type: 'popup',
      title: 'Welcome!',
      message: 'Welcome to Suk Fhyoke VPN - Secure & Fast VPN',
      image: '',
      buttons: [{ text: 'OK', action: 'dismiss' }],
      is_dismissible: true,
      background_color: '#1A1625',
      required_app_version: ''
    }
  }
];

export async function POST() {
  try {
    const results = [];
    
    for (const c of SDUI_CONFIGS) {
      await adminDb.collection('sdui_configs').doc(c.id).set({
        config: c.config,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      results.push({ id: c.id, status: 'added' });
    }
    
    return NextResponse.json({ 
      success: true, 
      message: `Added ${results.length} SDUI configs`,
      configs: results 
    });
  } catch (error) {
    console.error('Error seeding SDUI configs:', error);
    return NextResponse.json({ 
      success: false, 
      error: error instanceof Error ? error.message : 'Unknown error' 
    }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({ 
    message: 'POST to this endpoint to seed SDUI configs',
    configs: SDUI_CONFIGS.map(c => c.id)
  });
}

