import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import '../user_manager.dart';

/// SDUI Service - Fetches UI configurations from Firebase with REAL-TIME updates
class SduiService {
  static final SduiService _instance = SduiService._internal();
  factory SduiService() => _instance;
  SduiService._internal();

  final FirebaseService _firebase = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserManager _userManager = UserManager();
  
  /// Get language code for current language
  String get _currentLangCode {
    final lang = _userManager.currentLanguage.value;
    switch (lang) {
      case 'Myanmar (Zawgyi)':
        return 'my_zawgyi';
      case 'Myanmar (Unicode)':
        return 'my_unicode';
      case 'Japanese':
        return 'ja';
      case 'Chinese':
        return 'zh';
      case 'Thai':
        return 'th';
      default:
        return 'en';
    }
  }
  
  /// Get translated text from SDUI config value
  /// Supports both old format (String) and new format (Map with language codes)
  /// Example new format: {"en": "Settings", "my_zawgyi": "ဆက္တင္", "ja": "設定"}
  String getText(dynamic value, [String? fallback]) {
    if (value == null) return fallback ?? '';
    
    // Old format: just a string
    if (value is String) return value;
    
    // New format: map with language codes
    if (value is Map) {
      final langCode = _currentLangCode;
      // Try exact match first
      if (value.containsKey(langCode)) {
        return value[langCode]?.toString() ?? fallback ?? '';
      }
      // Fallback to English
      if (value.containsKey('en')) {
        return value['en']?.toString() ?? fallback ?? '';
      }
      // Return first available value
      if (value.isNotEmpty) {
        return value.values.first?.toString() ?? fallback ?? '';
      }
    }
    
    return fallback ?? '';
  }
  
  // Cache for screen configs
  final Map<String, Map<String, dynamic>> _cache = {};
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  
  // Active listeners
  final Map<String, StreamSubscription> _subscriptions = {};

  /// Get screen configuration (one-time fetch)
  Future<Map<String, dynamic>> getScreenConfig(String screenId) async {
    // Check cache first
    if (_cache.containsKey(screenId)) {
      debugPrint('📦 SDUI cache hit: $screenId');
      return _cache[screenId]!;
    }

    // Try Firebase
    try {
      debugPrint('🔄 Fetching SDUI config from Firebase: $screenId');
      final config = await _firebase.getScreenConfig(screenId);
      
      if (config.isNotEmpty) {
        _cache[screenId] = config;
        debugPrint('✅ SDUI config loaded from Firebase: $screenId');
        return config;
      }
    } catch (e) {
      debugPrint('❌ Firebase SDUI error: $e');
    }

    // Fallback to default configs
    debugPrint('⚠️ Using default SDUI config: $screenId');
    final defaultConfig = _getDefaultConfig(screenId);
    _cache[screenId] = defaultConfig;
    return defaultConfig;
  }

  /// Listen to real-time config changes
  Stream<Map<String, dynamic>> watchScreenConfig(String screenId) {
    debugPrint('👀 Starting real-time watch for SDUI: $screenId');
    
    // Return existing stream if available - but emit cached data immediately
    if (_controllers.containsKey(screenId) && !_controllers[screenId]!.isClosed) {
      debugPrint('♻️ Reusing existing stream for: $screenId');
      
      // Emit cached data immediately for new listeners
      if (_cache.containsKey(screenId)) {
        debugPrint('📦 Emitting cached data immediately for: $screenId');
        Future.microtask(() {
          if (!_controllers[screenId]!.isClosed) {
            _controllers[screenId]!.add(_cache[screenId]!);
          }
        });
      }
      
      return _controllers[screenId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _controllers[screenId] = controller;

    // Start listening to Firestore - snapshots() auto-emits current value + changes
    final subscription = _firestore
        .collection('sdui_configs')
        .doc(screenId)
        .snapshots()
        .listen((snapshot) {
      debugPrint('📡 Firestore snapshot received for: $screenId (exists: ${snapshot.exists})');
      
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final configData = data['config'] ?? data;
        final config = {
          'screen_id': screenId,
          'config': configData,
        };
        
        // Log detailed config for popup
        if (screenId == 'popup_startup') {
          debugPrint('📡 ====== POPUP FIREBASE UPDATE ======');
          debugPrint('📡 title_color: ${configData['title_color']}');
          debugPrint('📡 message_color: ${configData['message_color']}');
          debugPrint('📡 button_color: ${configData['button_color']}');
          debugPrint('📡 button_text_color: ${configData['button_text_color']}');
          debugPrint('📡 is_dismissible: ${configData['is_dismissible']}');
          debugPrint('📡 _lastModified: ${data['_lastModified']}');
          debugPrint('📡 =====================================');
        }
        
        // Update cache
        _cache[screenId] = config;
        
        // Emit new config
        if (!controller.isClosed) {
          controller.add(config);
          debugPrint('🔄 SDUI REAL-TIME UPDATE: $screenId');
        }
      } else {
        // Use default config
        final defaultConfig = _getDefaultConfig(screenId);
        _cache[screenId] = defaultConfig;
        if (!controller.isClosed) {
          controller.add(defaultConfig);
          debugPrint('⚠️ Using default config (no Firestore data): $screenId');
        }
      }
    }, onError: (error) {
      debugPrint('❌ SDUI real-time error for $screenId: $error');
      // Emit cached or default config on error
      final config = _cache[screenId] ?? _getDefaultConfig(screenId);
      if (!controller.isClosed) {
        controller.add(config);
      }
    });

    _subscriptions[screenId] = subscription;

    return controller.stream;
  }

  /// Stop watching a specific config
  void stopWatching(String screenId) {
    _subscriptions[screenId]?.cancel();
    _subscriptions.remove(screenId);
    _controllers[screenId]?.close();
    _controllers.remove(screenId);
    debugPrint('🛑 Stopped watching SDUI: $screenId');
  }

  /// Stop all watchers
  void stopAllWatchers() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    debugPrint('🛑 Stopped all SDUI watchers');
  }

  /// Clear cache (useful when config changes)
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️ SDUI cache cleared');
  }

  /// Dispose service
  void dispose() {
    stopAllWatchers();
    _cache.clear();
  }

  /// Default configurations (fallback)
  Map<String, dynamic> _getDefaultConfig(String screenId) {
    switch (screenId) {
      case 'onboarding':
        return {
          "screen_id": "onboarding",
          "config": {
            "type": "onboarding_flow",
            "pages": [
              {
                "title": "Global Servers",
                "description": "Access content from around the world\nwith our extensive server network.",
                "image": "assets/images/onboarding/Global servers.png"
              },
              {
                "title": "High Speed",
                "description": "Experience blazing fast connection\nspeeds for streaming and gaming.",
                "image": "assets/images/onboarding/High Speed.png"
              },
              {
                "title": "Secure & Private",
                "description": "Your data is protected with\nmilitary-grade encryption.",
                "image": "assets/images/onboarding/Secure & Private.png"
              },
              {
                "title": "Earn Rewards",
                "description": "Watch ads and earn rewards\nthat you can withdraw.",
                "image": "assets/images/onboarding/earn rewards.jpg"
              }
            ],
            "buttons": {
              "skip": "Skip",
              "next": "Next",
              "get_started": "Get Started"
            }
          }
        };

      case 'home':
        return {
          "screen_id": "home",
          "config": {
            "type": "dashboard",
            "app_bar": {
              "title_disconnected": "Not Connected",
              "title_connecting": "Connecting...",
              "title_connected": "Connected"
            },
            "timer_section": {
              "show_timer": true
            },
            "main_button": {
              "status_text_disconnected": "Tap to Connect",
              "status_text_connecting": "Establishing Connection...",
              "status_text_connected": "VPN is On"
            },
            "location_card": {
              "label": "Selected Location",
              "recent_label": "Recent Location",
              "show_latency_toggle": true
            }
          }
        };

      case 'rewards':
        return {
          "screen_id": "rewards",
          "config": {
            "title": "My Rewards",
            "payment_methods": ["KBZ Pay", "Wave Pay"],
            "min_withdraw_mmk": 20000,
            "labels": {
              "balance_label": "Total Points",
              "withdraw_button": "Withdraw Now",
            }
          }
        };

      case 'splash':
        return {
          "screen_id": "splash",
          "config": {
            "app_name": "Suk Fhyoke VPN",
            "tagline": "Secure & Fast",
            "gradient_colors": ["#7E57C2", "#B39DDB"],
            "splash_duration_seconds": 3
          }
        };

      case 'popup_startup':
        return {
          "screen_id": "popup_startup",
          "config": {
            "enabled": false,
            "display_type": "popup",
            "title": "Welcome!",
            "message": "Welcome to Suk Fhyoke VPN",
            "is_dismissible": true
          }
        };

      case 'settings':
        return {
          "screen_id": "settings",
          "config": {
            "title": "Settings",
            "sections": [
              {"title": "General", "items": ["Theme", "Language"]},
              {"title": "VPN", "items": ["Protocol", "Split Tunneling"]},
              {"title": "About", "items": ["About", "Privacy Policy", "Terms of Service"]}
            ]
          }
        };

      case 'earn_money':
        return {
          "screen_id": "earn_money",
          "config": {
            "title": "Earn Money",
            "reward_per_ad": 30,
            "max_ads_per_day": 100
          }
        };

      case 'location_selection':
        return {
          "screen_id": "location_selection",
          "config": {
            "title": "Select Location",
            "show_premium_badge": true
          }
        };

      case 'server_maintenance':
        return {
          "screen_id": "server_maintenance",
          "config": {
            "enabled": false,
            "title": "Under Maintenance",
            "message": "We're currently performing scheduled maintenance.\nPlease check back soon.",
            "estimated_time": "",
            "show_progress": true,
            "background_color": "#1a1a2e",
            "title_color": "#ffffff",
            "message_color": "#b0b0b0",
            "image": ""
          }
        };

      case 'terms_of_service':
        return {
          "screen_id": "terms_of_service",
          "config": {
            "title": {
              "en": "Terms of Service",
              "my_zawgyi": "ဝန္ေဆာင္မႈ စည္းမ်ဥ္းမ်ား",
              "my_unicode": "ဝန်ဆောင်မှု စည်းမျဉ်းများ",
              "ja": "利用規約",
              "zh": "服务条款",
              "th": "ข้อกำหนดการให้บริการ"
            },
            "content": {
              "en": """1. ACCEPTANCE OF TERMS

By accessing and using Suk Fhyoke VPN, you accept and agree to be bound by the terms and provision of this agreement.

2. USE OF SERVICE

You agree to use the VPN service only for lawful purposes and in accordance with these Terms of Service. You are responsible for all activities that occur under your account.

3. PROHIBITED ACTIVITIES

You may not use the service to:
- Engage in any illegal activities
- Transmit malicious software or viruses
- Violate any applicable laws or regulations
- Infringe upon intellectual property rights

4. ACCOUNT SECURITY

You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.

5. SERVICE AVAILABILITY

We strive to provide reliable service but do not guarantee uninterrupted or error-free service. We reserve the right to modify or discontinue the service at any time.

6. LIMITATION OF LIABILITY

Suk Fhyoke VPN shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the service.

7. TERMINATION

We reserve the right to terminate or suspend your account and access to the service at our sole discretion, without prior notice, for conduct that we believe violates these Terms of Service.

8. CHANGES TO TERMS

We reserve the right to modify these terms at any time. Your continued use of the service after any changes constitutes acceptance of the new terms.

9. CONTACT INFORMATION

If you have any questions about these Terms of Service, please contact us through the app's support features.

Effective Date: November 2025""",
              "my_zawgyi": """၁။ စည္းမ်ဥ္းမ်ားကို လက္ခံျခင္း

Suk Fhyoke VPN ကို အသုံးျပဳျခင္းျဖင့္ သင္သည္ ဤစည္းမ်ဥ္းမ်ားကို လက္ခံသေဘာတူပါသည္။

၂။ ဝန္ေဆာင္မႈ အသုံးျပဳျခင္း

သင္သည္ VPN ဝန္ေဆာင္မႈကို ဥပေဒအရ ခြင့္ျပဳထားေသာ ရည္ရြယ္ခ်က္မ်ားအတြက္ သာ အသုံးျပဳရမည္။

၃။ တားျမစ္ထားေသာ လုပ္ေဆာင္ခ်က္မ်ား

ဤဝန္ေဆာင္မႈကို ေအာက္ပါအတြက္ အသုံးမျပဳရပါ:
- ဥပေဒခ်ဳိးေဖာက္ေသာ လုပ္ေဆာင္ခ်က္မ်ား
- အႏၲရာယ္ရွိေသာ software မ်ား ပို႔ေဆာင္ျခင္း
- ဥပေဒမ်ားကို ခ်ဳိးေဖာက္ျခင္း

၄။ အေကာင့္ လုံၿခဳံေရး

သင္၏ အေကာင့္အခ်က္အလက္ကို လုံၿခဳံစြာ ထိန္းသိမ္းရန္ တာဝန္ရွိပါသည္။

၅။ ဝန္ေဆာင္မႈ ရရိွမႈ

ဝန္ေဆာင္မႈကို မည္သည့္အခ်ိန္တြင္မဆို ျပင္ဆင္ေျပာင္းလဲျခင္း သို႔မဟုတ္ ရပ္နားျခင္းကို လုပ္ေဆာင္ႏိုင္ပါသည္။

၆။ တာဝန္၏ ကန႔္သတ္ခ်က္မ်ား

Suk Fhyoke VPN သည္ သင္၏ ဝန္ေဆာင္မႈ အသုံးျပဳမႈမွ ျဖစ္ေပၚလာေသာ အၾကြင္းမဲ့ သို႔မဟုတ္ အေၾကာင္းရင္းမဲ့ ထိခိုက္မႈမ်ားအတြက္ တာဝန္မယူပါ။

၇။ အဆုံးသတ္ျခင္း

ဤစည္းမ်ဥ္းမ်ားကို ခ်ဳိးေဖာက္ေသာ လုပ္ေဆာင္ခ်က္မ်ားအတြက္ အေကာင့္ကို ရပ္နားျခင္း သို႔မဟုတ္ အဆုံးသတ္ျခင္းကို လုပ္ေဆာင္ႏိုင္ပါသည္။

၈။ စည္းမ်ဥ္းမ်ား ေျပာင္းလဲျခင္း

ဤစည္းမ်ဥ္းမ်ားကို မည္သည့္အခ်ိန္တြင္မဆို ျပင္ဆင္ေျပာင္းလဲႏိုင္ပါသည္။

၉။ ဆက္သြယ္ရန္

ဤစည္းမ်ဥ္းမ်ားအေၾကာင္း ေမးျမန္းလိုပါက app ၏ ေထာက္ပံ့မႈ လမ္းေၾကာင္းမ်ားမွတဆင့္ ဆက္သြယ္ႏိုင္ပါသည္။

အာဏာသက္ေရာက္ေသာ ရက္စြဲ: နိုဝင်ဘာ ၂၀၂၅""",
              "my_unicode": """၁။ စည်းမ်ဉ်းများကို လက်ခံခြင်း

Suk Fhyoke VPN ကို အသုံးပြုခြင်းဖြင့် သင်သည် ဤစည်းမ်ဉ်းများကို လက်ခံသဘောတူပါသည်။

၂။ ဝန်ဆောင်မှု အသုံးပြုခြင်း

သင်သည် VPN ဝန်ဆောင်မှုကို ဥပဒေအရ ခွင့်ပြုထားသော ရည်ရွယ်ချက်များအတွက် သာ အသုံးပြုရမည်။

၃။ တားမြစ်ထားသော လုပ်ဆောင်ချက်များ

ဤဝန်ဆောင်မှုကို အောက်ပါအတွက် အသုံးမပြုရပါ:
- ဥပဒေချိုးဖောက်သော လုပ်ဆောင်ချက်များ
- အန္တရာယ်ရှိသော software များ ပို့ဆောင်ခြင်း
- ဥပဒေများကို ချိုးဖောက်ခြင်း

၄။ အကောင့် လုံခြုံရေး

သင့်၏ အကောင့်အချက်အလက်ကို လုံခြုံစွာ ထိန်းသိမ်းရန် တာဝန်ရှိပါသည်။

၅။ ဝန်ဆောင်မှု ရရှိမှု

ဝန်ဆောင်မှုကို မည်သည့်အချိန်တွင်မဆို ပြင်ဆင်ပြောင်းလဲခြင်း သို့မဟုတ် ရပ်နားခြင်းကို လုပ်ဆောင်နိုင်ပါသည်။

၆။ တာဝန်၏ ကန့်သတ်ချက်များ

Suk Fhyoke VPN သည် သင့်၏ ဝန်ဆောင်မှု အသုံးပြုမှုမှ ဖြစ်ပေါ်လာသော အကြွင်းမဲ့ သို့မဟုတ် အကြောင်းရင်းမဲ့ ထိခိုက်မှုများအတွက် တာဝန်မယူပါ။

၇။ အဆုံးသတ်ခြင်း

ဤစည်းမ်ဉ်းများကို ချိုးဖောက်သော လုပ်ဆောင်ချက်များအတွက် အကောင့်ကို ရပ်နားခြင်း သို့မဟုတ် အဆုံးသတ်ခြင်းကို လုပ်ဆောင်နိုင်ပါသည်။

၈။ စည်းမ်ဉ်းများ ပြောင်းလဲခြင်း

ဤစည်းမ်ဉ်းများကို မည်သည့်အချိန်တွင်မဆို ပြင်ဆင်ပြောင်းလဲနိုင်ပါသည်။

၉။ ဆက်သွယ်ရန်

ဤစည်းမ်ဉ်းများအကြောင်း မေးမြန်းလိုပါက app ၏ ထောက်ပံ့မှု လမ်းကြောင်းများမှတဆင့် ဆက်သွယ်နိုင်ပါသည်။

အာဏာသက်ရောက်သော ရက်စွဲ: နိုဝင်ဘာ ၂၀၂၅""",
              "ja": """1. 利用規約の承認

Suk Fhyoke VPNにアクセスし、使用することで、本規約の条項に同意し、これに拘束されることに同意したものとみなされます。

2. サービスの使用

本サービスは、合法的な目的でのみ、本利用規約に従って使用するものとします。お客様のアカウントで発生するすべての活動について責任を負います。

3. 禁止行為

以下の目的で本サービスを使用することはできません：
- 違法行為への関与
- 悪意のあるソフトウェアやウイルスの送信
- 適用される法律や規制の違反
- 知的財産権の侵害

4. アカウントのセキュリティ

アカウント情報の機密性を維持し、アカウントで発生するすべての活動について責任を負います。

5. サービスの可用性

信頼性の高いサービスを提供するよう努めますが、中断のない、またはエラーのないサービスを保証するものではありません。いつでもサービスを変更または中止する権利を留保します。

6. 責任の制限

Suk Fhyoke VPNは、本サービスの使用に起因する間接的、偶発的、特別、または結果的な損害について責任を負いません。

7. 解約

本利用規約に違反すると当社が判断した行為について、事前の通知なしに、当社の単独の裁量により、お客様のアカウントおよびサービスへのアクセスを終了または停止する権利を留保します。

8. 規約の変更

本規約をいつでも変更する権利を留保します。変更後もサービスを継続して使用することは、新しい規約の承認を意味します。

9. 連絡先情報

本利用規約に関するご質問がある場合は、アプリのサポート機能を通じてお問い合わせください。

発効日: 2025年11月""",
              "zh": """1. 接受条款

通过访问和使用Suk Fhyoke VPN，您接受并同意受本协议条款的约束。

2. 服务使用

您同意仅将VPN服务用于合法目的，并遵守本服务条款。您对账户下发生的所有活动负责。

3. 禁止活动

您不得将服务用于：
- 从事任何非法活动
- 传输恶意软件或病毒
- 违反任何适用的法律法规
- 侵犯知识产权

4. 账户安全

您有责任维护账户信息的机密性，并对账户下发生的所有活动负责。

5. 服务可用性

我们努力提供可靠的服务，但不保证不间断或无错误的服务。我们保留随时修改或终止服务的权利。

6. 责任限制

Suk Fhyoke VPN不对因您使用服务而产生的任何间接、偶然、特殊或后果性损害承担责任。

7. 终止

我们保留自行决定终止或暂停您的账户和服务访问的权利，无需事先通知，对于我们认为违反本服务条款的行为。

8. 条款变更

我们保留随时修改这些条款的权利。任何变更后继续使用服务即表示接受新条款。

9. 联系信息

如果您对这些服务条款有任何疑问，请通过应用程序的支持功能与我们联系。

生效日期: 2025年11月""",
              "th": """1. การยอมรับข้อกำหนด

โดยการเข้าถึงและใช้ Suk Fhyoke VPN คุณยอมรับและยินยอมที่จะผูกพันตามข้อกำหนดและบทบัญญัติของข้อตกลงนี้

2. การใช้บริการ

คุณยินยอมที่จะใช้บริการ VPN เฉพาะเพื่อวัตถุประสงค์ที่ถูกกฎหมายและตามข้อกำหนดการให้บริการนี้ คุณรับผิดชอบต่อกิจกรรมทั้งหมดที่เกิดขึ้นภายใต้บัญชีของคุณ

3. กิจกรรมที่ห้าม

คุณไม่สามารถใช้บริการเพื่อ:
- มีส่วนร่วมในกิจกรรมที่ผิดกฎหมาย
- ส่งมัลแวร์หรือไวรัส
- ละเมิดกฎหมายหรือข้อบังคับที่ใช้บังคับ
- ละเมิดสิทธิ์ในทรัพย์สินทางปัญญา

4. ความปลอดภัยของบัญชี

คุณรับผิดชอบในการรักษาความลับของข้อมูลบัญชีของคุณและกิจกรรมทั้งหมดที่เกิดขึ้นภายใต้บัญชีของคุณ

5. ความพร้อมใช้งานของบริการ

เราพยายามให้บริการที่เชื่อถือได้ แต่ไม่รับประกันว่าบริการจะไม่ขาดตอนหรือปราศจากข้อผิดพลาด เราขอสงวนสิทธิ์ในการแก้ไขหรือยกเลิกบริการได้ตลอดเวลา

6. ข้อจำกัดความรับผิดชอบ

Suk Fhyoke VPN จะไม่รับผิดชอบต่อความเสียหายทางอ้อม เกิดขึ้นโดยบังเอิญ พิเศษ หรือตามมาที่เกิดจากการใช้บริการของคุณ

7. การยกเลิก

เราขอสงวนสิทธิ์ในการยกเลิกหรือระงับบัญชีของคุณและการเข้าถึงบริการตามดุลยพินิจของเรา โดยไม่ต้องแจ้งล่วงหน้า สำหรับพฤติกรรมที่เราเชื่อว่าละเมิดข้อกำหนดการให้บริการเหล่านี้

8. การเปลี่ยนแปลงข้อกำหนด

เราขอสงวนสิทธิ์ในการแก้ไขข้อกำหนดเหล่านี้ได้ตลอดเวลา การใช้บริการต่อไปหลังจากมีการเปลี่ยนแปลงใดๆ ถือเป็นการยอมรับข้อกำหนดใหม่

9. ข้อมูลติดต่อ

หากคุณมีคำถามเกี่ยวกับข้อกำหนดการให้บริการเหล่านี้ โปรดติดต่อเราผ่านคุณสมบัติการสนับสนุนของแอป

วันที่มีผลบังคับใช้: พฤศจิกายน 2025"""
            }
          }
        };

      case 'privacy_policy':
        return {
          "screen_id": "privacy_policy",
          "config": {
            "title": {
              "en": "Privacy Policy",
              "my_zawgyi": "ကိုယ္ေရးလုံၿခဳံေရး မူဝါဒ",
              "my_unicode": "ကိုယ်ရေးလုံခြုံရေး မူဝါဒ",
              "ja": "プライバシーポリシー",
              "zh": "隐私政策",
              "th": "นโยบายความเป็นส่วนตัว"
            },
            "content": {
              "en": """PRIVACY POLICY

Last updated: November 2025

1. INFORMATION WE COLLECT

We collect information that you provide directly to us, including:
- Device information (device ID, model, platform)
- Usage data (VPN connection logs, data usage statistics)
- Account information (balance, rewards, withdrawal requests)
- Location data (IP address, country, city)

2. HOW WE USE YOUR INFORMATION

We use the information we collect to:
- Provide and maintain the VPN service
- Process rewards and withdrawals
- Improve our services and user experience
- Communicate with you about your account
- Ensure security and prevent fraud

3. DATA STORAGE AND SECURITY

We use industry-standard security measures to protect your information. Your data is stored securely on Firebase servers with encryption in transit and at rest.

4. VPN CONNECTION LOGS

We maintain minimal connection logs necessary for:
- Service operation and troubleshooting
- Bandwidth management
- Security monitoring

We do not log:
- Websites you visit
- Content you access
- DNS queries
- Your browsing history

5. DATA RETENTION

We retain your data only as long as necessary to provide our services and comply with legal obligations. You can request deletion of your data at any time.

6. SHARING YOUR INFORMATION

We do not sell, trade, or rent your personal information to third parties. We may share information only:
- With your consent
- To comply with legal obligations
- To protect our rights and safety

7. YOUR RIGHTS

You have the right to:
- Access your personal data
- Request correction of inaccurate data
- Request deletion of your data
- Withdraw consent for data processing

8. COOKIES AND TRACKING

We use minimal tracking technologies necessary for app functionality. We do not use cookies for advertising purposes.

9. CHILDREN'S PRIVACY

Our service is not intended for children under 13. We do not knowingly collect information from children.

10. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. We will notify you of any changes by updating the "Last updated" date.

11. CONTACT US

If you have questions about this Privacy Policy, please contact us through the app's support features.

By using Suk Fhyoke VPN, you acknowledge that you have read and understood this Privacy Policy.""",
              "my_zawgyi": """ကိုယ္ေရးလုံၿခဳံေရး မူဝါဒ

နောက်ဆုံး အပ်ဒိတ်: နိုဝင်ဘာ ၂၀၂၅

၁။ ကၽြႏ္ုပ္တို႔ စုေဆာင္းေသာ အခ်က္အလက္မ်ား

သင္ကိုယ္တိုင္ ေပးအပ္ေသာ အခ်က္အလက္မ်ားကို စုေဆာင္းပါသည္:
- စက္ကိရိယာ အခ်က္အလက္ (device ID, model, platform)
- အသုံးျပဳမႈ အခ်က္အလက္ (VPN ခ်ိတ္ဆက္မႈ log မ်ား၊ data usage statistics)
- အေကာင့္ အခ်က္အလက္ (balance, rewards, withdrawal requests)
- တည္ေနရာ အခ်က္အလက္ (IP address, country, city)

၂။ အခ်က္အလက္မ်ားကို အသုံးျပဳပုံ

စုေဆာင္းထားေသာ အခ်က္အလက္မ်ားကို ေအာက္ပါအတြက္ အသုံးျပဳပါသည္:
- VPN ဝန္ေဆာင္မႈကို ေပးအပ္ျခင္း နွင့္ ထိန္းသိမ္းျခင္း
- Rewards နွင့္ withdrawal မ်ားကို လုပ္ေဆာင္ျခင္း
- ဝန္ေဆာင္မႈမ်ား နွင့္ user experience ကို ေကာင္းမြန္ေစျခင္း
- အေကာင့္အေၾကာင္း ဆက္သြယ္ျခင္း
- လုံၿခဳံေရး နွင့္ fraud ကို ကာကြယ္ျခင္း

၃။ အခ်က္အလက္ သိုေလွာင္ျခင္း နွင့္ လုံၿခဳံေရး

သင့္အခ်က္အလက္မ်ားကို ကာကြယ္ရန္ industry-standard security measures မ်ားကို အသုံးျပဳပါသည္။

၄။ VPN ခ်ိတ္ဆက္မႈ Log မ်ား

ဝန္ေဆာင္မႈ လည္ပတ္မႈ နွင့္ troubleshooting အတြက္ လိုအပ္ေသာ minimal connection logs မ်ားကို ထိန္းသိမ္းပါသည္။

ကၽြႏ္ုပ္တို႔ log မလုပ္ေသာ အရာမ်ား:
- သင္ ဝင္ေရာက္ေသာ websites မ်ား
- သင္ ဝင္ေရာက္ေသာ content မ်ား
- DNS queries
- သင့္ browsing history

၅။ အခ်က္အလက္ ထိန္းသိမ္းျခင္း

ဝန္ေဆာင္မႈမ်ားကို ေပးအပ္ရန္ နွင့္ ဥပေဒအရ တာဝန္မ်ားကို လိုက္နာရန္ လိုအပ္ေသာ အခ်ိန္အထိ အခ်က္အလက္မ်ားကို ထိန္းသိမ္းပါသည္။

၆။ အခ်က္အလက္မ်ား မွ်ေဝျခင္း

သင့္ personal information ကို third parties မ်ားထံ ေရာင္းခ်၊ ေရႊ႕ေျပာင္း၊ ငွားရမ္းျခင္း မလုပ္ပါ။

၇။ သင့္ အခြင့္အေရးမ်ား

သင့္တြင္ ေအာက္ပါ အခြင့္အေရးမ်ား ရွိပါသည္:
- Personal data ကို ဝင္ေရာက္ၾကည့္ရႈျခင္း
- မွားယြင္းေသာ data ကို ျပင္ဆင္ေတာင္းဆိုျခင္း
- Data ကို ဖ်က္ဆီးေတာင္းဆိုျခင္း
- Data processing အတြက္ consent ကို ရုတ္သိမ္းျခင္း

၈။ Cookies နွင့္ Tracking

App functionality အတြက္ လိုအပ္ေသာ minimal tracking technologies မ်ားကို အသုံးျပဳပါသည္။

၉။ ကေလးမ်ား၏ Privacy

ဤဝန္ေဆာင္မႈသည္ အသက္ ၁၃ ႏွစ္ေအာက္ ကေလးမ်ားအတြက္ မရည္ရြယ္ပါ။

၁၀။ ဤမူဝါဒ ေျပာင္းလဲျခင္း

ဤ Privacy Policy ကို အခ်ိန္ကာလအလိုက္ update လုပ္ႏိုင္ပါသည္။

၁၁။ ဆက္သြယ္ရန္

ဤ Privacy Policy အေၾကာင္း ေမးျမန္းလိုပါက app ၏ ေထာက္ပံ့မႈ လမ္းေၾကာင္းမ်ားမွတဆင့္ ဆက္သြယ္ႏိုင္ပါသည္။

Suk Fhyoke VPN ကို အသုံးျပဳျခင္းျဖင့္ ဤ Privacy Policy ကို ဖတ္ၿပီး နားလည္ၿပီးျဖစ္ေၾကာင္း အသိအမွတ္ျပဳပါသည္။""",
              "my_unicode": """ကိုယ်ရေးလုံခြုံရေး မူဝါဒ

နောက်ဆုံး အပ်ဒိတ်: နိုဝင်ဘာ ၂၀၂၅

၁။ ကျွန်ုပ်တို့ စုဆောင်းသော အချက်အလက်များ

သင်ကိုယ်တိုင် ပေးအပ်သော အချက်အလက်များကို စုဆောင်းပါသည်:
- စက်ကိရိယာ အချက်အလက် (device ID, model, platform)
- အသုံးပြုမှု အချက်အလက် (VPN ချိတ်ဆက်မှု log များ၊ data usage statistics)
- အကောင့် အချက်အလက် (balance, rewards, withdrawal requests)
- တည်နေရာ အချက်အလက် (IP address, country, city)

၂။ အချက်အလက်များကို အသုံးပြုပုံ

စုဆောင်းထားသော အချက်အလက်များကို အောက်ပါအတွက် အသုံးပြုပါသည်:
- VPN ဝန်ဆောင်မှုကို ပေးအပ်ခြင်း နှင့် ထိန်းသိမ်းခြင်း
- Rewards နှင့် withdrawal များကို လုပ်ဆောင်ခြင်း
- ဝန်ဆောင်မှုများ နှင့် user experience ကို ကောင်းမွန်စေခြင်း
- အကောင့်အကြောင်း ဆက်သွယ်ခြင်း
- လုံခြုံရေး နှင့် fraud ကို ကာကွယ်ခြင်း

၃။ အချက်အလက် သိုလှောင်ခြင်း နှင့် လုံခြုံရေး

သင့်အချက်အလက်များကို ကာကွယ်ရန် industry-standard security measures များကို အသုံးပြုပါသည်။

၄။ VPN ချိတ်ဆက်မှု Log များ

ဝန်ဆောင်မှု လည်ပတ်မှု နှင့် troubleshooting အတွက် လိုအပ်သော minimal connection logs များကို ထိန်းသိမ်းပါသည်။

ကျွန်ုပ်တို့ log မလုပ်သော အရာများ:
- သင်ဝင်ရောက်သော websites များ
- သင်ဝင်ရောက်သော content များ
- DNS queries
- သင့် browsing history

၅။ အချက်အလက် ထိန်းသိမ်းခြင်း

ဝန်ဆောင်မှုများကို ပေးအပ်ရန် နှင့် ဥပဒေအရ တာဝန်များကို လိုက်နာရန် လိုအပ်သော အချိန်အထိ အချက်အလက်များကို ထိန်းသိမ်းပါသည်။

၆။ အချက်အလက်များ မျှဝေခြင်း

သင့် personal information ကို third parties များထံ ရောင်းချ၊ ရွေ့ပြောင်း၊ ငှားရမ်းခြင်း မလုပ်ပါ။

၇။ သင့် အခွင့်အရေးများ

သင့်တွင် အောက်ပါ အခွင့်အရေးများ ရှိပါသည်:
- Personal data ကို ဝင်ရောက်ကြည့်ရှုခြင်း
- မှားယွင်းသော data ကို ပြင်ဆင်တောင်းဆိုခြင်း
- Data ကို ဖျက်ဆီးတောင်းဆိုခြင်း
- Data processing အတွက် consent ကို ရုတ်သိမ်းခြင်း

၈။ Cookies နှင့် Tracking

App functionality အတွက် လိုအပ်သော minimal tracking technologies များကို အသုံးပြုပါသည်။

၉။ ကလေးများ၏ Privacy

ဤဝန်ဆောင်မှုသည် အသက် ၁၃ နှစ်အောက် ကလေးများအတွက် မရည်ရွယ်ပါ။

၁၀။ ဤမူဝါဒ ပြောင်းလဲခြင်း

ဤ Privacy Policy ကို အချိန်ကာလအလိုက် update လုပ်နိုင်ပါသည်။

၁၁။ ဆက်သွယ်ရန်

ဤ Privacy Policy အကြောင်း မေးမြန်းလိုပါက app ၏ ထောက်ပံ့မှု လမ်းကြောင်းများမှတဆင့် ဆက်သွယ်နိုင်ပါသည်။

Suk Fhyoke VPN ကို အသုံးပြုခြင်းဖြင့် ဤ Privacy Policy ကို ဖတ်ပြီး နားလည်ပြီးဖြစ်ကြောင်း အသိအမှတ်ပြုပါသည်။""",
              "ja": """プライバシーポリシー

最終更新: 2025年11月

1. 収集する情報

当社は、お客様から直接提供される情報を収集します：
- デバイス情報（デバイスID、モデル、プラットフォーム）
- 使用データ（VPN接続ログ、データ使用統計）
- アカウント情報（残高、報酬、出金リクエスト）
- 位置情報（IPアドレス、国、都市）

2. 情報の使用方法

収集した情報は以下の目的で使用します：
- VPNサービスの提供と維持
- 報酬と出金の処理
- サービスとユーザー体験の改善
- アカウントに関する連絡
- セキュリティの確保と不正行為の防止

3. データの保存とセキュリティ

業界標準のセキュリティ対策を使用して情報を保護します。データは転送中および保存時に暗号化されてFirebaseサーバーに安全に保存されます。

4. VPN接続ログ

以下のために必要な最小限の接続ログを保持します：
- サービスの運用とトラブルシューティング
- 帯域幅の管理
- セキュリティ監視

以下の情報は記録しません：
- 訪問したウェブサイト
- アクセスしたコンテンツ
- DNSクエリ
- 閲覧履歴

5. データの保持

サービスを提供し、法的義務を遵守するために必要な期間のみデータを保持します。いつでもデータの削除をリクエストできます。

6. 情報の共有

個人情報を第三者に販売、取引、または貸与することはありません。以下の場合にのみ情報を共有する場合があります：
- お客様の同意がある場合
- 法的義務を遵守するため
- 当社の権利と安全を保護するため

7. お客様の権利

お客様には以下の権利があります：
- 個人データへのアクセス
- 不正確なデータの訂正をリクエスト
- データの削除をリクエスト
- データ処理への同意の撤回

8. クッキーとトラッキング

アプリの機能に必要な最小限のトラッキング技術を使用します。広告目的でクッキーを使用することはありません。

9. 児童のプライバシー

本サービスは13歳未満の児童を対象としていません。児童から意図的に情報を収集することはありません。

10. 本ポリシーの変更

本プライバシーポリシーを随時更新する場合があります。「最終更新」日を更新してお知らせします。

11. お問い合わせ

本プライバシーポリシーに関するご質問がある場合は、アプリのサポート機能を通じてお問い合わせください。

Suk Fhyoke VPNを使用することで、本プライバシーポリシーを読み、理解したことを承認したものとみなされます。""",
              "zh": """隐私政策

最后更新: 2025年11月

1. 我们收集的信息

我们收集您直接提供给我们的信息，包括：
- 设备信息（设备ID、型号、平台）
- 使用数据（VPN连接日志、数据使用统计）
- 账户信息（余额、奖励、提现请求）
- 位置数据（IP地址、国家、城市）

2. 我们如何使用您的信息

我们使用收集的信息来：
- 提供和维护VPN服务
- 处理奖励和提现
- 改进我们的服务和用户体验
- 就您的账户与您沟通
- 确保安全并防止欺诈

3. 数据存储和安全

我们使用行业标准的安全措施来保护您的信息。您的数据在传输和静止时都经过加密，安全地存储在Firebase服务器上。

4. VPN连接日志

我们维护服务运行和故障排除所需的最少连接日志：
- 服务运行和故障排除
- 带宽管理
- 安全监控

我们不记录：
- 您访问的网站
- 您访问的内容
- DNS查询
- 您的浏览历史

5. 数据保留

我们仅在提供服务和遵守法律义务所需的时间内保留您的数据。您可以随时请求删除您的数据。

6. 共享您的信息

我们不出售、交易或出租您的个人信息给第三方。我们仅在以下情况下共享信息：
- 经您同意
- 遵守法律义务
- 保护我们的权利和安全

7. 您的权利

您有权：
- 访问您的个人数据
- 请求更正不准确的数据
- 请求删除您的数据
- 撤回数据处理同意

8. Cookie和跟踪

我们使用应用程序功能所需的最少跟踪技术。我们不将Cookie用于广告目的。

9. 儿童隐私

我们的服务不适用于13岁以下的儿童。我们不会故意收集儿童的信息。

10. 本政策的变更

我们可能会不时更新本隐私政策。我们将通过更新"最后更新"日期来通知您任何变更。

11. 联系我们

如果您对本隐私政策有任何疑问，请通过应用程序的支持功能与我们联系。

使用Suk Fhyoke VPN即表示您已阅读并理解本隐私政策。""",
              "th": """นโยบายความเป็นส่วนตัว

อัปเดตล่าสุด: พฤศจิกายน 2025

1. ข้อมูลที่เรารวบรวม

เรารวบรวมข้อมูลที่คุณให้มาโดยตรง รวมถึง:
- ข้อมูลอุปกรณ์ (รหัสอุปกรณ์ รุ่น แพลตฟอร์ม)
- ข้อมูลการใช้งาน (บันทึกการเชื่อมต่อ VPN สถิติการใช้งานข้อมูล)
- ข้อมูลบัญชี (ยอดคงเหลือ รางวัล คำขอถอนเงิน)
- ข้อมูลตำแหน่ง (ที่อยู่ IP ประเทศ เมือง)

2. วิธีที่เราใช้ข้อมูลของคุณ

เราใช้ข้อมูลที่เรารวบรวมเพื่อ:
- ให้บริการและบำรุงรักษาบริการ VPN
- ประมวลผลรางวัลและการถอนเงิน
- ปรับปรุงบริการและประสบการณ์ผู้ใช้
- ติดต่อกับคุณเกี่ยวกับบัญชีของคุณ
- รับประกันความปลอดภัยและป้องกันการฉ้อโกง

3. การจัดเก็บข้อมูลและความปลอดภัย

เราใช้มาตรการรักษาความปลอดภัยตามมาตรฐานอุตสาหกรรมเพื่อปกป้องข้อมูลของคุณ ข้อมูลของคุณถูกจัดเก็บอย่างปลอดภัยบนเซิร์ฟเวอร์ Firebase ด้วยการเข้ารหัสระหว่างการส่งและเมื่ออยู่เฉยๆ

4. บันทึกการเชื่อมต่อ VPN

เราบำรุงรักษาบันทึกการเชื่อมต่อขั้นต่ำที่จำเป็นสำหรับ:
- การดำเนินงานและการแก้ไขปัญหา
- การจัดการแบนด์วิดท์
- การตรวจสอบความปลอดภัย

เราไม่บันทึก:
- เว็บไซต์ที่คุณเยี่ยมชม
- เนื้อหาที่คุณเข้าถึง
- คำขอ DNS
- ประวัติการเรียกดูของคุณ

5. การเก็บรักษาข้อมูล

เราเก็บรักษาข้อมูลของคุณเฉพาะเท่าที่จำเป็นในการให้บริการและปฏิบัติตามภาระผูกพันทางกฎหมาย คุณสามารถขอให้ลบข้อมูลของคุณได้ตลอดเวลา

6. การแบ่งปันข้อมูลของคุณ

เราไม่ขาย แลกเปลี่ยน หรือให้เช่าข้อมูลส่วนบุคคลของคุณให้กับบุคคลที่สาม เราอาจแบ่งปันข้อมูลเฉพาะ:
- ด้วยความยินยอมของคุณ
- เพื่อปฏิบัติตามภาระผูกพันทางกฎหมาย
- เพื่อปกป้องสิทธิ์และความปลอดภัยของเรา

7. สิทธิ์ของคุณ

คุณมีสิทธิ์:
- เข้าถึงข้อมูลส่วนบุคคลของคุณ
- ขอให้แก้ไขข้อมูลที่ไม่ถูกต้อง
- ขอให้ลบข้อมูลของคุณ
- ถอนความยินยอมสำหรับการประมวลผลข้อมูล

8. คุกกี้และการติดตาม

เราใช้เทคโนโลยีการติดตามขั้นต่ำที่จำเป็นสำหรับฟังก์ชันการทำงานของแอป เราไม่ใช้คุกกี้เพื่อวัตถุประสงค์ในการโฆษณา

9. ความเป็นส่วนตัวของเด็ก

บริการของเราไม่ได้มีไว้สำหรับเด็กอายุต่ำกว่า 13 ปี เราไม่ทราบว่ากำลังรวบรวมข้อมูลจากเด็ก

10. การเปลี่ยนแปลงนโยบายนี้

เราอาจอัปเดตนโยบายความเป็นส่วนตัวนี้เป็นครั้งคราว เราจะแจ้งให้คุณทราบถึงการเปลี่ยนแปลงใดๆ โดยการอัปเดตวันที่ "อัปเดตล่าสุด"

11. ติดต่อเรา

หากคุณมีคำถามเกี่ยวกับนโยบายความเป็นส่วนตัวนี้ โปรดติดต่อเราผ่านคุณสมบัติการสนับสนุนของแอป

โดยการใช้ Suk Fhyoke VPN คุณยอมรับว่าคุณได้อ่านและเข้าใจนโยบายความเป็นส่วนตัวนี้แล้ว"""
            }
          }
        };

      default:
        return {
          "screen_id": screenId,
          "config": {}
        };
    }
  }
}
