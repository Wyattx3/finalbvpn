const admin = require('firebase-admin');

// Initialize with default credentials
admin.initializeApp({
  projectId: 'strategic-volt-341100'
});

const db = admin.firestore();

// Multi-language translations for SDUI configs
const sduiTranslations = {
  // Settings Screen
  settings: {
    config: {
      title: {
        en: "Settings",
        my_zawgyi: "ဆက္တင္",
        my_unicode: "ဆက်တင်",
        ja: "設定",
        zh: "设置",
        th: "ตั้งค่า"
      },
      sections: [
        { title: "General", items: ["Theme", "Language"] },
        { title: "VPN", items: ["Protocol", "Split Tunneling"] },
        { title: "About", items: ["About", "Privacy Policy", "Terms of Service"] }
      ]
    }
  },

  // Home Screen
  home: {
    config: {
      type: "dashboard",
      app_bar: {
        title_disconnected: {
          en: "Not Connected",
          my_zawgyi: "မခ်ိတ္ဆက္ရေသးပါ",
          my_unicode: "မချိတ်ဆက်ရသေးပါ",
          ja: "未接続",
          zh: "未连接",
          th: "ไม่ได้เชื่อมต่อ"
        },
        title_connecting: {
          en: "Connecting...",
          my_zawgyi: "ခ်ိတ္ဆက္ေနသည္...",
          my_unicode: "ချိတ်ဆက်နေသည်...",
          ja: "接続中...",
          zh: "连接中...",
          th: "กำลังเชื่อมต่อ..."
        },
        title_connected: {
          en: "Connected",
          my_zawgyi: "ခ်ိတ္ဆက္ၿပီး",
          my_unicode: "ချိတ်ဆက်ပြီး",
          ja: "接続済み",
          zh: "已连接",
          th: "เชื่อมต่อแล้ว"
        }
      },
      timer_section: {
        show_timer: true
      },
      main_button: {
        status_text_disconnected: {
          en: "Tap to Connect",
          my_zawgyi: "ခ်ိတ္ဆက္ရန္ႏွိပ္ပါ",
          my_unicode: "ချိတ်ဆက်ရန်နှိပ်ပါ",
          ja: "タップして接続",
          zh: "点击连接",
          th: "แตะเพื่อเชื่อมต่อ"
        },
        status_text_connecting: {
          en: "Establishing Connection...",
          my_zawgyi: "ခ်ိတ္ဆက္မႈတည္ေဆာက္ေနသည္...",
          my_unicode: "ချိတ်ဆက်မှုတည်ဆောက်နေသည်...",
          ja: "接続を確立中...",
          zh: "正在建立连接...",
          th: "กำลังสร้างการเชื่อมต่อ..."
        },
        status_text_connected: {
          en: "VPN is On",
          my_zawgyi: "VPN ဖြင့္ထားသည္",
          my_unicode: "VPN ဖွင့်ထားသည်",
          ja: "VPN オン",
          zh: "VPN 已开启",
          th: "VPN เปิดอยู่"
        }
      },
      location_card: {
        label: {
          en: "Selected Location",
          my_zawgyi: "ေရြးထားေသာတည္ေနရာ",
          my_unicode: "ရွေးထားသောတည်နေရာ",
          ja: "選択した場所",
          zh: "已选位置",
          th: "ตำแหน่งที่เลือก"
        },
        recent_label: {
          en: "Recent Location",
          my_zawgyi: "မၾကာေသးမီတည္ေနရာ",
          my_unicode: "မကြာသေးမီတည်နေရာ",
          ja: "最近の場所",
          zh: "最近位置",
          th: "ตำแหน่งล่าสุด"
        },
        show_latency_toggle: true
      }
    }
  },

  // Earn Money Screen
  earn_money: {
    config: {
      title: {
        en: "Earn Points",
        my_zawgyi: "အမွတ္ရွာမည္",
        my_unicode: "အမှတ်ရှာမည်",
        ja: "ポイントを稼ぐ",
        zh: "赚取积分",
        th: "รับคะแนน"
      },
      reward_per_ad: 30,
      max_ads_per_day: 100,
      cooldown_ads_count: 10,
      cooldown_minutes: 10,
      labels: {
        balance_label: {
          en: "Total Points",
          my_zawgyi: "စုစုေပါင္းအမွတ္",
          my_unicode: "စုစုပေါင်းအမှတ်",
          ja: "合計ポイント",
          zh: "总积分",
          th: "คะแนนรวม"
        },
        watch_button: {
          en: "Watch Ad & Earn",
          my_zawgyi: "ေၾကာ္ျငာၾကည့္ၿပီး ရယူပါ",
          my_unicode: "ကြော်ငြာကြည့်ပြီး ရယူပါ",
          ja: "広告を見て稼ぐ",
          zh: "看广告赚钱",
          th: "ดูโฆษณาและรับ"
        },
        cooldown_text: {
          en: "Cooldown Active",
          my_zawgyi: "ေစာင့္ဆိုင္းေနဆဲ",
          my_unicode: "စောင့်ဆိုင်းနေဆဲ",
          ja: "クールダウン中",
          zh: "冷却中",
          th: "กำลังรอ"
        }
      }
    }
  },

  // Rewards/Withdraw Screen
  rewards: {
    config: {
      title: {
        en: "My Rewards",
        my_zawgyi: "ကၽြႏ္ုပ္၏ဆုလာဘ္",
        my_unicode: "ကျွန်ုပ်၏ဆုလာဘ်",
        ja: "マイ報酬",
        zh: "我的奖励",
        th: "รางวัลของฉัน"
      },
      payment_methods: ["KBZ Pay", "Wave Pay"],
      min_withdraw_mmk: 20000,
      min_withdraw_usd: 20.0,
      labels: {
        balance_label: {
          en: "Total Points",
          my_zawgyi: "စုစုေပါင္းအမွတ္",
          my_unicode: "စုစုပေါင်းအမှတ်",
          ja: "合計ポイント",
          zh: "总积分",
          th: "คะแนนรวม"
        },
        withdraw_button: {
          en: "Withdraw Now",
          my_zawgyi: "ယခုထုတ္ယူမည္",
          my_unicode: "ယခုထုတ်ယူမည်",
          ja: "今すぐ引き出す",
          zh: "立即提现",
          th: "ถอนเงินตอนนี้"
        }
      }
    }
  },

  // Splash Screen
  splash: {
    config: {
      app_name: "Suf Fhoke VPN",
      tagline: {
        en: "Secure & Fast",
        my_zawgyi: "လံုျခံဳၿပီး ျမန္ဆန္",
        my_unicode: "လုံခြုံပြီး မြန်ဆန်",
        ja: "安全で高速",
        zh: "安全快速",
        th: "ปลอดภัยและเร็ว"
      },
      gradient_colors: ["#7E57C2", "#B39DDB"],
      splash_duration_seconds: 3
    }
  },

  // Onboarding Screen
  onboarding: {
    config: {
      type: "onboarding_flow",
      pages: [
        {
          title: {
            en: "Global Servers",
            my_zawgyi: "ကမၻာလံုးဆိုင္ရာဆာဗာမ်ား",
            my_unicode: "ကမ္ဘာလုံးဆိုင်ရာဆာဗာများ",
            ja: "グローバルサーバー",
            zh: "全球服务器",
            th: "เซิร์ฟเวอร์ทั่วโลก"
          },
          description: {
            en: "Access content from around the world\nwith our extensive server network.",
            my_zawgyi: "ကၽြႏ္ုပ္တို႔၏က်ယ္ျပန္႔ေသာဆာဗာကြန္ယက္ျဖင့္\nကမၻာတစ္ဝွမ္းမွအေၾကာင္းအရာမ်ားကိုရယူပါ။",
            my_unicode: "ကျွန်ုပ်တို့၏ကျယ်ပြန့်သောဆာဗာကွန်ယက်ဖြင့်\nကမ္ဘာတစ်ဝှမ်းမှအကြောင်းအရာများကိုရယူပါ။",
            ja: "広範なサーバーネットワークで\n世界中のコンテンツにアクセス",
            zh: "通过我们广泛的服务器网络\n访问全球内容",
            th: "เข้าถึงเนื้อหาจากทั่วโลก\nด้วยเครือข่ายเซิร์ฟเวอร์ที่กว้างขวาง"
          },
          image: "assets/images/onboarding/Global servers.png"
        },
        {
          title: {
            en: "High Speed",
            my_zawgyi: "အျမင့္ဆံုးအျမန္ႏႈန္း",
            my_unicode: "အမြင့်ဆုံးအမြန်နှုန်း",
            ja: "高速",
            zh: "高速",
            th: "ความเร็วสูง"
          },
          description: {
            en: "Experience blazing fast connection\nspeeds for streaming and gaming.",
            my_zawgyi: "စထရီးမင္းႏွင့္ဂိမ္းကစားျခင္းအတြက္\nအလြန္ျမန္ဆန္ေသာခ်ိတ္ဆက္မႈကိုခံစားပါ။",
            my_unicode: "စထရီးမင်းနှင့်ဂိမ်းကစားခြင်းအတွက်\nအလွန်မြန်ဆန်သောချိတ်ဆက်မှုကိုခံစားပါ။",
            ja: "ストリーミングやゲームに\n超高速接続を体験",
            zh: "体验超快连接速度\n适用于流媒体和游戏",
            th: "สัมผัสการเชื่อมต่อที่รวดเร็ว\nสำหรับสตรีมมิ่งและเกม"
          },
          image: "assets/images/onboarding/High Speed.png"
        },
        {
          title: {
            en: "Secure & Private",
            my_zawgyi: "လံုျခံဳၿပီးပုဂၢလိက",
            my_unicode: "လုံခြုံပြီးပုဂ္ဂလိက",
            ja: "安全でプライベート",
            zh: "安全私密",
            th: "ปลอดภัยและเป็นส่วนตัว"
          },
          description: {
            en: "Your data is protected with\nmilitary-grade encryption.",
            my_zawgyi: "သင့္ေဒတာကိုစစ္တပ္အဆင့္\nစာဝွက္ျပဳလုပ္ျခင္းျဖင့္ကာကြယ္ထားသည္။",
            my_unicode: "သင့်ဒေတာကိုစစ်တပ်အဆင့်\nစာဝှက်ပြုလုပ်ခြင်းဖြင့်ကာကွယ်ထားသည်။",
            ja: "軍事レベルの暗号化で\nデータを保護",
            zh: "您的数据受到\n军事级加密保护",
            th: "ข้อมูลของคุณได้รับการปกป้อง\nด้วยการเข้ารหัสระดับทหาร"
          },
          image: "assets/images/onboarding/Secure & Private.png"
        },
        {
          title: {
            en: "Earn Rewards",
            my_zawgyi: "ဆုလာဘ္ရယူပါ",
            my_unicode: "ဆုလာဘ်ရယူပါ",
            ja: "報酬を獲得",
            zh: "赚取奖励",
            th: "รับรางวัล"
          },
          description: {
            en: "Watch ads and earn rewards\nthat you can withdraw.",
            my_zawgyi: "ေၾကာ္ျငာၾကည့္ၿပီးထုတ္ယူႏိုင္ေသာ\nဆုလာဘ္မ်ားရယူပါ။",
            my_unicode: "ကြော်ငြာကြည့်ပြီးထုတ်ယူနိုင်သော\nဆုလာဘ်များရယူပါ။",
            ja: "広告を見て引き出し可能な\n報酬を獲得",
            zh: "观看广告并获得\n可提现的奖励",
            th: "ดูโฆษณาและรับรางวัล\nที่สามารถถอนได้"
          },
          image: "assets/images/onboarding/earn rewards.jpg"
        }
      ],
      buttons: {
        skip: {
          en: "Skip",
          my_zawgyi: "ေက်ာ္မည္",
          my_unicode: "ကျော်မည်",
          ja: "スキップ",
          zh: "跳过",
          th: "ข้าม"
        },
        next: {
          en: "Next",
          my_zawgyi: "ေရွ႕သို႔",
          my_unicode: "ရှေ့သို့",
          ja: "次へ",
          zh: "下一步",
          th: "ถัดไป"
        },
        get_started: {
          en: "Get Started",
          my_zawgyi: "စတင္မည္",
          my_unicode: "စတင်မည်",
          ja: "始める",
          zh: "开始",
          th: "เริ่มต้น"
        }
      }
    }
  },

  // Banned Screen
  banned_screen: {
    config: {
      title: {
        en: "Account Suspended",
        my_zawgyi: "အေကာင့္ပိတ္ထားသည္",
        my_unicode: "အကောင့်ပိတ်ထားသည်",
        ja: "アカウント停止",
        zh: "账户已暂停",
        th: "บัญชีถูกระงับ"
      },
      message: {
        en: "Your account has been suspended due to violation of our terms of service.",
        my_zawgyi: "ကၽြႏ္ုပ္တို႔၏ဝန္ေဆာင္မႈစည္းမ်ဥ္းမ်ားကိုေဖာက္ဖ်က္ေသာေၾကာင့္\nသင့္အေကာင့္ကိုပိတ္ထားသည္။",
        my_unicode: "ကျွန်ုပ်တို့၏ဝန်ဆောင်မှုစည်းမျဥ်းများကိုဖောက်ဖျက်သောကြောင့်\nသင့်အကောင့်ကိုပိတ်ထားသည်။",
        ja: "利用規約違反のため\nアカウントが停止されました。",
        zh: "由于违反服务条款\n您的账户已被暂停。",
        th: "บัญชีของคุณถูกระงับ\nเนื่องจากละเมิดข้อกำหนดการใช้งาน"
      },
      support_button: {
        text: {
          en: "Contact Support",
          my_zawgyi: "Support ဆက္သြယ္ပါ",
          my_unicode: "Support ဆက်သွယ်ပါ",
          ja: "サポートに連絡",
          zh: "联系客服",
          th: "ติดต่อฝ่ายสนับสนุน"
        },
        url: "https://t.me/bvpn_support"
      },
      quit_button: {
        text: {
          en: "Quit App",
          my_zawgyi: "ထြက္မည္",
          my_unicode: "ထွက်မည်",
          ja: "アプリを終了",
          zh: "退出应用",
          th: "ออกจากแอป"
        }
      },
      show_quit_button: true
    }
  },

  // Server Maintenance Screen
  server_maintenance: {
    config: {
      enabled: false,
      title: {
        en: "Under Maintenance",
        my_zawgyi: "ျပဳျပင္ထိန္းသိမ္းေနသည္",
        my_unicode: "ပြုပြင်ထိန်းသိမ်းနေသည်",
        ja: "メンテナンス中",
        zh: "维护中",
        th: "อยู่ระหว่างการบำรุงรักษา"
      },
      message: {
        en: "We're currently performing scheduled maintenance.\nPlease check back soon.",
        my_zawgyi: "ျပဳျပင္ထိန္းသိမ္းမႈလုပ္ေဆာင္ေနပါသည္။\nေနာက္မွျပန္လာပါ။",
        my_unicode: "ပြုပြင်ထိန်းသိမ်းမှုလုပ်ဆောင်နေပါသည်။\nနောက်မှပြန်လာပါ။",
        ja: "現在メンテナンス中です。\nしばらくお待ちください。",
        zh: "我们正在进行维护。\n请稍后再来。",
        th: "เรากำลังทำการบำรุงรักษา\nกรุณากลับมาใหม่ภายหลัง"
      },
      show_progress: true,
      progress_text: {
        en: "Working on it...",
        my_zawgyi: "လုပ္ေဆာင္ေနသည္...",
        my_unicode: "လုပ်ဆောင်နေသည်...",
        ja: "作業中...",
        zh: "处理中...",
        th: "กำลังดำเนินการ..."
      }
    }
  }
};

async function updateSduiTranslations() {
  console.log('🌐 Starting SDUI Multi-Language Update...\n');

  for (const [screenId, data] of Object.entries(sduiTranslations)) {
    try {
      console.log(`📝 Updating ${screenId}...`);
      
      await db.collection('sdui_configs').doc(screenId).set({
        config: data.config,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        _lastModified: new Date().toISOString()
      }, { merge: true });
      
      console.log(`✅ ${screenId} updated successfully!`);
    } catch (error) {
      console.error(`❌ Error updating ${screenId}:`, error);
    }
  }

  console.log('\n🎉 All SDUI configs updated with multi-language support!');
  process.exit(0);
}

updateSduiTranslations();

