import 'package:flutter/material.dart';
import '../user_manager.dart';

/// Simple localization service for the app
class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  final UserManager _userManager = UserManager();

  /// Get current language
  String get currentLanguage => _userManager.currentLanguage.value;

  /// Get translated string by key
  String tr(String key) {
    final lang = currentLanguage;
    final translations = _translations[lang] ?? _translations['English']!;
    return translations[key] ?? _translations['English']![key] ?? key;
  }

  /// Translation maps for each language
  static final Map<String, Map<String, String>> _translations = {
    'English': _english,
    'Myanmar (Zawgyi)': _myanmarZawgyi,
    'Myanmar (Unicode)': _myanmarUnicode,
    'Japanese': _japanese,
    'Chinese': _chinese,
    'Thai': _thai,
  };

  static const Map<String, String> _english = {
    // Navigation & Common
    'home': 'Home',
    'settings': 'Settings',
    'back': 'Back',
    'next': 'Next',
    'done': 'Done',
    'ok': 'OK',
    'cancel': 'Cancel',
    'save': 'Save',
    'close': 'Close',
    'retry': 'Retry',
    'loading': 'Loading...',
    'please_wait': 'Please wait...',
    'error': 'Error',
    'success': 'Success',
    'warning': 'Warning',
    'copy': 'Copy',
    'copied': 'Copied',
    'share': 'Share',

    // Home Screen
    'connect': 'Connect',
    'disconnect': 'Disconnect',
    'connecting': 'Connecting...',
    'connected': 'Connected',
    'disconnected': 'Disconnected',
    'tap_to_connect': 'Tap to Connect',
    'tap_to_disconnect': 'Tap to Disconnect',
    'select_location': 'Select Location',
    'current_location': 'Current Location',
    'time_remaining': 'Time Remaining',
    'watch_ad': 'Watch Ad',
    'watch_ad_for_time': 'Watch Ad for Time',
    'no_time_left': 'No time left. Watch an ad to continue.',
    'vpn_time': 'VPN Time',
    'download': 'Download',
    'upload': 'Upload',

    // Location Selection
    'all_locations': 'All Locations',
    'universal': 'Universal',
    'streaming': 'Streaming',
    'search_location': 'Search location...',
    'select_server': 'Select Server',
    'servers': 'Servers',
    'server': 'Server',
    'best_location': 'Best Location',
    'auto_select': 'Auto Select',

    // Earn Money Screen
    'earn_money': 'Earn Money',
    'earn_points': 'Earn Points',
    'total_points': 'Total Points',
    'your_balance': 'Your Balance',
    'today_earned': 'Today Earned',
    'today': 'Today',
    'watch_ad_earn': 'Watch Ad & Earn',
    'watch_ad_to_earn': 'Watch ad to earn points',
    'cooldown': 'Cooldown',
    'cooldown_active': 'Cooldown Active',
    'wait_before_next_ad': 'Wait before next ad',
    'ads_watched_today': 'Ads watched today',
    'max_daily_limit': 'Max daily limit reached',
    'reward_per_ad': 'Reward per ad',
    'points': 'Points',
    'point': 'Point',

    // Withdraw Screen
    'withdraw': 'Withdraw',
    'withdraw_history': 'Withdraw History',
    'withdraw_points': 'Withdraw Points',
    'minimum_withdraw': 'Minimum withdraw',
    'enter_amount': 'Enter amount',
    'payment_method': 'Payment Method',
    'account_number': 'Account Number',
    'account_name': 'Account Name',
    'submit_request': 'Submit Request',
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
    'processing': 'Processing',
    'no_history': 'No history yet',

    // Rewards Screen  
    'rewards': 'Rewards',
    'daily_reward': 'Daily Reward',
    'claim': 'Claim',
    'claimed': 'Claimed',
    'bonus': 'Bonus',
    'streak': 'Streak',
    'day': 'Day',
    'days': 'Days',

    // Settings
    'language': 'Language',
    'theme': 'Theme',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'system': 'System',
    'split_tunneling': 'Split Tunneling',
    'vpn_protocol': 'VPN Protocol',
    'protocol': 'Protocol',
    'auto': 'Auto',
    'display_latency': 'Display Latency',
    'enable_debug_log': 'Enable Debug Log',
    'push_setting': 'Push Notifications',
    'theme_mode': 'Theme Mode',
    'privacy_policy': 'Privacy Policy',
    'terms_of_service': 'Terms of Service',
    'contact_us': 'Contact Us',
    'about': 'About',
    'version': 'Version',
    'device_id': 'Device ID',
    'account': 'Account',
    'vpn_settings': 'VPN Settings',
    'app_settings': 'App Settings',
    'support': 'Support',

    // Split Tunneling
    'disable_split_tunneling': 'Disable Split Tunneling',
    'all_apps_use_vpn': 'All apps will use VPN connection',
    'only_selected_use_vpn': 'Only Selected Apps Use VPN',
    'only_chosen_apps_use_vpn': 'Only chosen apps will use VPN, others bypass',
    'bypass_vpn_selected': 'Bypass VPN for Selected Apps',
    'chosen_apps_bypass': 'Chosen apps will bypass VPN, others use VPN',
    'select_apps': 'Select Apps',
    'selected_apps': 'Selected Apps',
    'no_apps_selected': 'No apps selected',
    'search_apps': 'Search apps...',

    // VPN Protocol
    'auto_websocket': 'Auto (WebSocket)',
    'tcp': 'TCP',
    'udp_quic': 'UDP (QUIC)',
    'recommended': 'Recommended',
    'best_compatibility': 'Best compatibility',
    'fast_reliable': 'Fast and reliable',
    'best_for_gaming': 'Best for gaming',

    // Server Status
    'online': 'Online',
    'offline': 'Offline',
    'maintenance': 'Maintenance',
    'load': 'Load',
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',

    // Banned/Maintenance
    'account_suspended': 'Account Suspended',
    'contact_support': 'Contact Support',
    'quit_app': 'Quit App',
    'under_maintenance': 'Under Maintenance',
    'maintenance_message': 'We\'re currently performing scheduled maintenance.\nPlease check back soon.',
    'working_on_it': 'Working on it...',

    // About
    'app_version': 'App Version',
    'developer': 'Developer',
    'rate_app': 'Rate App',
    'send_feedback': 'Send Feedback',

    // Contact
    'telegram': 'Telegram',
    'email': 'Email',
    'facebook': 'Facebook',

    // Onboarding
    'welcome': 'Welcome',
    'get_started': 'Get Started',
    'skip': 'Skip',

    // Errors
    'connection_failed': 'Connection failed',
    'network_error': 'Network error',
    'try_again': 'Try again',
    'something_went_wrong': 'Something went wrong',
    'no_internet': 'No internet connection',

    // Time
    'hours': 'Hours',
    'minutes': 'Minutes',
    'seconds': 'Seconds',
    'hour': 'Hour',
    'minute': 'Minute',
    'second': 'Second',
  };

  static const Map<String, String> _myanmarZawgyi = {
    // Navigation & Common
    'home': 'ပင္မ',
    'settings': 'ဆက္တင္',
    'back': 'ေနာက္သို႔',
    'next': 'ေရွ႕သို႔',
    'done': 'ၿပီးပါၿပီ',
    'ok': 'အိုေက',
    'cancel': 'မလုပ္ေတာ့ပါ',
    'save': 'သိမ္းမည္',
    'close': 'ပိတ္မည္',
    'retry': 'ျပန္ႀကိဳးစားပါ',
    'loading': 'ေခၚေနသည္...',
    'please_wait': 'ေခတၱေစာင့္ပါ...',
    'error': 'အမွား',
    'success': 'ေအာင္ျမင္',
    'warning': 'သတိေပးခ်က္',
    'copy': 'ကူးမည္',
    'copied': 'ကူးၿပီး',
    'share': 'မွ်ေဝမည္',

    // Home Screen
    'connect': 'ခ်ိတ္ဆက္မည္',
    'disconnect': 'ျဖဳတ္မည္',
    'connecting': 'ခ်ိတ္ဆက္ေနသည္...',
    'connected': 'ခ်ိတ္ဆက္ၿပီး',
    'disconnected': 'ျဖဳတ္ၿပီး',
    'tap_to_connect': 'ခ်ိတ္ဆက္ရန္ႏွိပ္ပါ',
    'tap_to_disconnect': 'ျဖဳတ္ရန္ႏွိပ္ပါ',
    'select_location': 'တည္ေနရာေရြးပါ',
    'current_location': 'လက္ရွိတည္ေနရာ',
    'time_remaining': 'က်န္ရွိခ်ိန္',
    'watch_ad': 'ေၾကာ္ျငာၾကည့္ပါ',
    'watch_ad_for_time': 'အခ်ိန္ရဖို႔ ေၾကာ္ျငာၾကည့္ပါ',
    'no_time_left': 'အခ်ိန္ကုန္သြားပါၿပီ။ ေၾကာ္ျငာၾကည့္ပါ။',
    'vpn_time': 'VPN အခ်ိန္',
    'download': 'ေဒါင္းလုဒ္',
    'upload': 'အပ္လုဒ္',

    // Location Selection
    'all_locations': 'တည္ေနရာအားလံုး',
    'universal': 'ယူနီဗာဆယ္',
    'streaming': 'စထရီးမင္း',
    'search_location': 'တည္ေနရာရွာပါ...',
    'select_server': 'ဆာဗာေရြးပါ',
    'servers': 'ဆာဗာမ်ား',
    'server': 'ဆာဗာ',
    'best_location': 'အေကာင္းဆံုးတည္ေနရာ',
    'auto_select': 'အလိုအေလ်ာက္ေရြးမည္',

    // Earn Money Screen
    'earn_money': 'ေငြရွာမည္',
    'earn_points': 'အမွတ္ရွာမည္',
    'total_points': 'စုစုေပါင္းအမွတ္',
    'your_balance': 'သင့္လက္က်န္',
    'today_earned': 'ဒီေန႔ရရွိမႈ',
    'today': 'ဒီေန႔',
    'watch_ad_earn': 'ေၾကာ္ျငာၾကည့္ၿပီး ရယူပါ',
    'watch_ad_to_earn': 'အမွတ္ရဖို႔ ေၾကာ္ျငာၾကည့္ပါ',
    'cooldown': 'ေစာင့္ဆိုင္းခ်ိန္',
    'cooldown_active': 'ေစာင့္ဆိုင္းေနဆဲ',
    'wait_before_next_ad': 'ေနာက္တစ္ခုမၾကည့္ခင္ေစာင့္ပါ',
    'ads_watched_today': 'ဒီေန႔ၾကည့္ၿပီးေၾကာ္ျငာ',
    'max_daily_limit': 'ေန႔စဥ္ကန္႔သတ္ခ်က္ျပည့္ၿပီ',
    'reward_per_ad': 'ေၾကာ္ျငာတစ္ခုဆုလာဘ္',
    'points': 'အမွတ္',
    'point': 'အမွတ္',

    // Withdraw Screen
    'withdraw': 'ထုတ္ယူမည္',
    'withdraw_history': 'ထုတ္ယူမႈမွတ္တမ္း',
    'withdraw_points': 'အမွတ္ထုတ္မည္',
    'minimum_withdraw': 'အနည္းဆံုးထုတ္ယူႏိုင္',
    'enter_amount': 'ပမာဏထည့္ပါ',
    'payment_method': 'ေငြေပးနည္း',
    'account_number': 'အေကာင့္နံပါတ္',
    'account_name': 'အေကာင့္အမည္',
    'submit_request': 'ေတာင္းဆိုမည္',
    'pending': 'ေစာင့္ဆိုင္းဆဲ',
    'approved': 'အတည္ျပဳၿပီး',
    'rejected': 'ပယ္ခ်ၿပီး',
    'processing': 'လုပ္ေဆာင္ေနဆဲ',
    'no_history': 'မွတ္တမ္းမရွိေသးပါ',

    // Rewards Screen
    'rewards': 'ဆုလာဘ္',
    'daily_reward': 'ေန႔စဥ္ဆုလာဘ္',
    'claim': 'ရယူမည္',
    'claimed': 'ရယူၿပီး',
    'bonus': 'ဘိုနပ္စ္',
    'streak': 'ဆက္တိုက္',
    'day': 'ရက္',
    'days': 'ရက္',

    // Settings
    'language': 'ဘာသာစကား',
    'theme': 'အေရာင္ေသြး',
    'dark_mode': 'အေမွာင္ေရာင္',
    'light_mode': 'အလင္းေရာင္',
    'system': 'စနစ္',
    'split_tunneling': 'Split Tunneling',
    'vpn_protocol': 'VPN ပ႐ိုတိုေကာ',
    'protocol': 'ပ႐ိုတိုေကာ',
    'auto': 'အလိုအေလ်ာက္',
    'display_latency': 'Latency ျပမည္',
    'enable_debug_log': 'Debug Log ဖြင့္မည္',
    'push_setting': 'Push အသိေပးခ်က္',
    'theme_mode': 'အေရာင္ပံုစံ',
    'privacy_policy': 'ကိုယ္ေရးလံုၿခံဳမႈ',
    'terms_of_service': 'ဝန္ေဆာင္မႈစည္းကမ္း',
    'contact_us': 'ဆက္သြယ္ရန္',
    'about': 'အေၾကာင္း',
    'version': 'ဗားရွင္း',
    'device_id': 'စက္ ID',
    'account': 'အေကာင့္',
    'vpn_settings': 'VPN ဆက္တင္',
    'app_settings': 'App ဆက္တင္',
    'support': 'အကူအညီ',

    // Split Tunneling
    'disable_split_tunneling': 'Split Tunneling ပိတ္မည္',
    'all_apps_use_vpn': 'App အားလံုး VPN သံုးမည္',
    'only_selected_use_vpn': 'ေရြးထားတဲ့ App ေတြပဲ VPN သံုးမည္',
    'only_chosen_apps_use_vpn': 'ေရြးထားတဲ့ App ေတြပဲ VPN သံုးမယ္',
    'bypass_vpn_selected': 'ေရြးထားတဲ့ App ေတြ VPN မသံုးေစမည္',
    'chosen_apps_bypass': 'ေရြးထားတဲ့ App ေတြ VPN ေက်ာ္မယ္',
    'select_apps': 'App ေရြးပါ',
    'selected_apps': 'ေရြးထားေသာ App',
    'no_apps_selected': 'App မေရြးရေသးပါ',
    'search_apps': 'App ရွာပါ...',

    // VPN Protocol
    'auto_websocket': 'အလိုအေလ်ာက္ (WebSocket)',
    'tcp': 'TCP',
    'udp_quic': 'UDP (QUIC)',
    'recommended': 'အႀကံျပဳ',
    'best_compatibility': 'အသံုးျပဳရလြယ္ဆံုး',
    'fast_reliable': 'ျမန္ၿပီး ယံုၾကည္ရ',
    'best_for_gaming': 'ဂိမ္းအတြက္ အေကာင္းဆံုး',

    // Server Status
    'online': 'အြန္လိုင္း',
    'offline': 'ေအာ့ဖ္လိုင္း',
    'maintenance': 'ျပဳျပင္ေနသည္',
    'load': 'ဝန္',
    'low': 'နည္း',
    'medium': 'အလယ္အလတ္',
    'high': 'မ်ား',

    // Banned/Maintenance
    'account_suspended': 'အေကာင့္ပိတ္ထားသည္',
    'contact_support': 'Support ဆက္သြယ္ပါ',
    'quit_app': 'ထြက္မည္',
    'under_maintenance': 'ျပဳျပင္ထိန္းသိမ္းေနသည္',
    'maintenance_message': 'ျပဳျပင္ထိန္းသိမ္းေနပါသည္။\nေနာက္မွျပန္လာပါ။',
    'working_on_it': 'လုပ္ေဆာင္ေနသည္...',

    // About
    'app_version': 'App ဗားရွင္း',
    'developer': 'Developer',
    'rate_app': 'App အဆင့္သတ္မွတ္ပါ',
    'send_feedback': 'အႀကံျပဳခ်က္ပို႔ပါ',

    // Contact
    'telegram': 'တယ္လီဂရမ္',
    'email': 'အီးေမးလ္',
    'facebook': 'ေဖ့စ္ဘုတ္',

    // Onboarding
    'welcome': 'ႀကိဳဆိုပါသည္',
    'get_started': 'စတင္မည္',
    'skip': 'ေက်ာ္မည္',

    // Errors
    'connection_failed': 'ခ်ိတ္ဆက္မႈမေအာင္ျမင္ပါ',
    'network_error': 'ကြန္ရက္အမွား',
    'try_again': 'ျပန္ႀကိဳးစားပါ',
    'something_went_wrong': 'တစ္စံုတစ္ခုမွားယြင္းသြားပါသည္',
    'no_internet': 'အင္တာနက္မရွိပါ',

    // Time
    'hours': 'နာရီ',
    'minutes': 'မိနစ္',
    'seconds': 'စကၠန္႔',
    'hour': 'နာရီ',
    'minute': 'မိနစ္',
    'second': 'စကၠန္႔',
  };

  static const Map<String, String> _myanmarUnicode = {
    // Navigation & Common
    'home': 'ပင်မ',
    'settings': 'ဆက်တင်',
    'back': 'နောက်သို့',
    'next': 'ရှေ့သို့',
    'done': 'ပြီးပါပြီ',
    'ok': 'အိုကေ',
    'cancel': 'မလုပ်တော့ပါ',
    'save': 'သိမ်းမည်',
    'close': 'ပိတ်မည်',
    'retry': 'ပြန်ကြိုးစားပါ',
    'loading': 'ခေါ်နေသည်...',
    'please_wait': 'ခေတ္တစောင့်ပါ...',
    'error': 'အမှား',
    'success': 'အောင်မြင်',
    'warning': 'သတိပေးချက်',
    'copy': 'ကူးမည်',
    'copied': 'ကူးပြီး',
    'share': 'မျှဝေမည်',

    // Home Screen
    'connect': 'ချိတ်ဆက်မည်',
    'disconnect': 'ဖြုတ်မည်',
    'connecting': 'ချိတ်ဆက်နေသည်...',
    'connected': 'ချိတ်ဆက်ပြီး',
    'disconnected': 'ဖြုတ်ပြီး',
    'tap_to_connect': 'ချိတ်ဆက်ရန်နှိပ်ပါ',
    'tap_to_disconnect': 'ဖြုတ်ရန်နှိပ်ပါ',
    'select_location': 'တည်နေရာရွေးပါ',
    'current_location': 'လက်ရှိတည်နေရာ',
    'time_remaining': 'ကျန်ရှိချိန်',
    'watch_ad': 'ကြော်ငြာကြည့်ပါ',
    'watch_ad_for_time': 'အချိန်ရဖို့ ကြော်ငြာကြည့်ပါ',
    'no_time_left': 'အချိန်ကုန်သွားပါပြီ။ ကြော်ငြာကြည့်ပါ။',
    'vpn_time': 'VPN အချိန်',
    'download': 'ဒေါင်းလုဒ်',
    'upload': 'အပ်လုဒ်',

    // Location Selection
    'all_locations': 'တည်နေရာအားလုံး',
    'universal': 'ယူနီဗာဆယ်',
    'streaming': 'စထရီးမင်း',
    'search_location': 'တည်နေရာရှာပါ...',
    'select_server': 'ဆာဗာရွေးပါ',
    'servers': 'ဆာဗာများ',
    'server': 'ဆာဗာ',
    'best_location': 'အကောင်းဆုံးတည်နေရာ',
    'auto_select': 'အလိုအလျောက်ရွေးမည်',

    // Earn Money Screen
    'earn_money': 'ငွေရှာမည်',
    'earn_points': 'အမှတ်ရှာမည်',
    'total_points': 'စုစုပေါင်းအမှတ်',
    'your_balance': 'သင့်လက်ကျန်',
    'today_earned': 'ဒီနေ့ရရှိမှု',
    'today': 'ဒီနေ့',
    'watch_ad_earn': 'ကြော်ငြာကြည့်ပြီး ရယူပါ',
    'watch_ad_to_earn': 'အမှတ်ရဖို့ ကြော်ငြာကြည့်ပါ',
    'cooldown': 'စောင့်ဆိုင်းချိန်',
    'cooldown_active': 'စောင့်ဆိုင်းနေဆဲ',
    'wait_before_next_ad': 'နောက်တစ်ခုမကြည့်ခင်စောင့်ပါ',
    'ads_watched_today': 'ဒီနေ့ကြည့်ပြီးကြော်ငြာ',
    'max_daily_limit': 'နေ့စဥ်ကန့်သတ်ချက်ပြည့်ပြီ',
    'reward_per_ad': 'ကြော်ငြာတစ်ခုဆုလာဘ်',
    'points': 'အမှတ်',
    'point': 'အမှတ်',

    // Withdraw Screen
    'withdraw': 'ထုတ်ယူမည်',
    'withdraw_history': 'ထုတ်ယူမှုမှတ်တမ်း',
    'withdraw_points': 'အမှတ်ထုတ်မည်',
    'minimum_withdraw': 'အနည်းဆုံးထုတ်ယူနိုင်',
    'enter_amount': 'ပမာဏထည့်ပါ',
    'payment_method': 'ငွေပေးနည်း',
    'account_number': 'အကောင့်နံပါတ်',
    'account_name': 'အကောင့်အမည်',
    'submit_request': 'တောင်းဆိုမည်',
    'pending': 'စောင့်ဆိုင်းဆဲ',
    'approved': 'အတည်ပြုပြီး',
    'rejected': 'ပယ်ချပြီး',
    'processing': 'လုပ်ဆောင်နေဆဲ',
    'no_history': 'မှတ်တမ်းမရှိသေးပါ',

    // Rewards Screen
    'rewards': 'ဆုလာဘ်',
    'daily_reward': 'နေ့စဥ်ဆုလာဘ်',
    'claim': 'ရယူမည်',
    'claimed': 'ရယူပြီး',
    'bonus': 'ဘိုနပ်စ်',
    'streak': 'ဆက်တိုက်',
    'day': 'ရက်',
    'days': 'ရက်',

    // Settings
    'language': 'ဘာသာစကား',
    'theme': 'အရောင်သွေး',
    'dark_mode': 'အမှောင်ရောင်',
    'light_mode': 'အလင်းရောင်',
    'system': 'စနစ်',
    'split_tunneling': 'Split Tunneling',
    'vpn_protocol': 'VPN ပရိုတိုကော',
    'protocol': 'ပရိုတိုကော',
    'auto': 'အလိုအလျောက်',
    'display_latency': 'Latency ပြမည်',
    'enable_debug_log': 'Debug Log ဖွင့်မည်',
    'push_setting': 'Push အသိပေးချက်',
    'theme_mode': 'အရောင်ပုံစံ',
    'privacy_policy': 'ကိုယ်ရေးလုံခြုံမှု',
    'terms_of_service': 'ဝန်ဆောင်မှုစည်းကမ်း',
    'contact_us': 'ဆက်သွယ်ရန်',
    'about': 'အကြောင်း',
    'version': 'ဗားရှင်း',
    'device_id': 'စက် ID',
    'account': 'အကောင့်',
    'vpn_settings': 'VPN ဆက်တင်',
    'app_settings': 'App ဆက်တင်',
    'support': 'အကူအညီ',

    // Split Tunneling
    'disable_split_tunneling': 'Split Tunneling ပိတ်မည်',
    'all_apps_use_vpn': 'App အားလုံး VPN သုံးမည်',
    'only_selected_use_vpn': 'ရွေးထားတဲ့ App တွေပဲ VPN သုံးမည်',
    'only_chosen_apps_use_vpn': 'ရွေးထားတဲ့ App တွေပဲ VPN သုံးမယ်',
    'bypass_vpn_selected': 'ရွေးထားတဲ့ App တွေ VPN မသုံးစေမည်',
    'chosen_apps_bypass': 'ရွေးထားတဲ့ App တွေ VPN ကျော်မယ်',
    'select_apps': 'App ရွေးပါ',
    'selected_apps': 'ရွေးထားသော App',
    'no_apps_selected': 'App မရွေးရသေးပါ',
    'search_apps': 'App ရှာပါ...',

    // VPN Protocol
    'auto_websocket': 'အလိုအလျောက် (WebSocket)',
    'tcp': 'TCP',
    'udp_quic': 'UDP (QUIC)',
    'recommended': 'အကြံပြု',
    'best_compatibility': 'အသုံးပြုရလွယ်ဆုံး',
    'fast_reliable': 'မြန်ပြီး ယုံကြည်ရ',
    'best_for_gaming': 'ဂိမ်းအတွက် အကောင်းဆုံး',

    // Server Status
    'online': 'အွန်လိုင်း',
    'offline': 'အော့ဖ်လိုင်း',
    'maintenance': 'ပြုပြင်နေသည်',
    'load': 'ဝန်',
    'low': 'နည်း',
    'medium': 'အလယ်အလတ်',
    'high': 'များ',

    // Banned/Maintenance
    'account_suspended': 'အကောင့်ပိတ်ထားသည်',
    'contact_support': 'Support ဆက်သွယ်ပါ',
    'quit_app': 'ထွက်မည်',
    'under_maintenance': 'ပြုပြင်ထိန်းသိမ်းနေသည်',
    'maintenance_message': 'ပြုပြင်ထိန်းသိမ်းနေပါသည်။\nနောက်မှပြန်လာပါ။',
    'working_on_it': 'လုပ်ဆောင်နေသည်...',

    // About
    'app_version': 'App ဗားရှင်း',
    'developer': 'Developer',
    'rate_app': 'App အဆင့်သတ်မှတ်ပါ',
    'send_feedback': 'အကြံပြုချက်ပို့ပါ',

    // Contact
    'telegram': 'တယ်လီဂရမ်',
    'email': 'အီးမေးလ်',
    'facebook': 'ဖေ့စ်ဘုတ်',

    // Onboarding
    'welcome': 'ကြိုဆိုပါသည်',
    'get_started': 'စတင်မည်',
    'skip': 'ကျော်မည်',

    // Errors
    'connection_failed': 'ချိတ်ဆက်မှုမအောင်မြင်ပါ',
    'network_error': 'ကွန်ရက်အမှား',
    'try_again': 'ပြန်ကြိုးစားပါ',
    'something_went_wrong': 'တစ်စုံတစ်ခုမှားယွင်းသွားပါသည်',
    'no_internet': 'အင်တာနက်မရှိပါ',

    // Time
    'hours': 'နာရီ',
    'minutes': 'မိနစ်',
    'seconds': 'စက္ကန့်',
    'hour': 'နာရီ',
    'minute': 'မိနစ်',
    'second': 'စက္ကန့်',
  };

  static const Map<String, String> _japanese = {
    // Navigation & Common
    'home': 'ホーム',
    'settings': '設定',
    'back': '戻る',
    'next': '次へ',
    'done': '完了',
    'ok': 'OK',
    'cancel': 'キャンセル',
    'save': '保存',
    'close': '閉じる',
    'retry': '再試行',
    'loading': '読み込み中...',
    'please_wait': 'お待ちください...',
    'error': 'エラー',
    'success': '成功',
    'warning': '警告',
    'copy': 'コピー',
    'copied': 'コピーしました',
    'share': '共有',

    // Home Screen
    'connect': '接続',
    'disconnect': '切断',
    'connecting': '接続中...',
    'connected': '接続済み',
    'disconnected': '切断済み',
    'tap_to_connect': 'タップして接続',
    'tap_to_disconnect': 'タップして切断',
    'select_location': '場所を選択',
    'current_location': '現在地',
    'time_remaining': '残り時間',
    'watch_ad': '広告を見る',
    'watch_ad_for_time': '時間を獲得するため広告を見る',
    'no_time_left': '時間切れです。広告を見てください。',
    'vpn_time': 'VPN時間',
    'download': 'ダウンロード',
    'upload': 'アップロード',

    // Location Selection
    'all_locations': 'すべての場所',
    'universal': 'ユニバーサル',
    'streaming': 'ストリーミング',
    'search_location': '場所を検索...',
    'select_server': 'サーバーを選択',
    'servers': 'サーバー',
    'server': 'サーバー',
    'best_location': '最適な場所',
    'auto_select': '自動選択',

    // Earn Money Screen
    'earn_money': '稼ぐ',
    'earn_points': 'ポイントを獲得',
    'total_points': '合計ポイント',
    'your_balance': '残高',
    'today_earned': '今日の獲得',
    'today': '今日',
    'watch_ad_earn': '広告を見て稼ぐ',
    'watch_ad_to_earn': 'ポイントを獲得するため広告を見る',
    'cooldown': 'クールダウン',
    'cooldown_active': 'クールダウン中',
    'wait_before_next_ad': '次の広告まで待機',
    'ads_watched_today': '今日見た広告',
    'max_daily_limit': '一日の上限に達しました',
    'reward_per_ad': '広告あたりの報酬',
    'points': 'ポイント',
    'point': 'ポイント',

    // Withdraw Screen
    'withdraw': '引き出す',
    'withdraw_history': '引き出し履歴',
    'withdraw_points': 'ポイントを引き出す',
    'minimum_withdraw': '最小引き出し額',
    'enter_amount': '金額を入力',
    'payment_method': '支払い方法',
    'account_number': '口座番号',
    'account_name': '口座名義',
    'submit_request': 'リクエストを送信',
    'pending': '保留中',
    'approved': '承認済み',
    'rejected': '却下',
    'processing': '処理中',
    'no_history': '履歴がありません',

    // Rewards Screen
    'rewards': '報酬',
    'daily_reward': 'デイリー報酬',
    'claim': '受け取る',
    'claimed': '受取済み',
    'bonus': 'ボーナス',
    'streak': '連続',
    'day': '日',
    'days': '日',

    // Settings
    'language': '言語',
    'theme': 'テーマ',
    'dark_mode': 'ダークモード',
    'light_mode': 'ライトモード',
    'system': 'システム',
    'split_tunneling': 'スプリットトンネル',
    'vpn_protocol': 'VPNプロトコル',
    'protocol': 'プロトコル',
    'auto': '自動',
    'display_latency': 'レイテンシを表示',
    'enable_debug_log': 'デバッグログを有効',
    'push_setting': 'プッシュ通知',
    'theme_mode': 'テーマモード',
    'privacy_policy': 'プライバシーポリシー',
    'terms_of_service': '利用規約',
    'contact_us': 'お問い合わせ',
    'about': '情報',
    'version': 'バージョン',
    'device_id': 'デバイスID',
    'account': 'アカウント',
    'vpn_settings': 'VPN設定',
    'app_settings': 'アプリ設定',
    'support': 'サポート',

    // Split Tunneling
    'disable_split_tunneling': 'スプリットトンネルを無効',
    'all_apps_use_vpn': 'すべてのアプリがVPNを使用',
    'only_selected_use_vpn': '選択したアプリのみVPNを使用',
    'only_chosen_apps_use_vpn': '選択したアプリのみがVPNを使用します',
    'bypass_vpn_selected': '選択したアプリはVPNをバイパス',
    'chosen_apps_bypass': '選択したアプリはVPNをバイパスします',
    'select_apps': 'アプリを選択',
    'selected_apps': '選択したアプリ',
    'no_apps_selected': 'アプリが選択されていません',
    'search_apps': 'アプリを検索...',

    // VPN Protocol
    'auto_websocket': '自動 (WebSocket)',
    'tcp': 'TCP',
    'udp_quic': 'UDP (QUIC)',
    'recommended': 'おすすめ',
    'best_compatibility': '最高の互換性',
    'fast_reliable': '高速で信頼性が高い',
    'best_for_gaming': 'ゲームに最適',

    // Server Status
    'online': 'オンライン',
    'offline': 'オフライン',
    'maintenance': 'メンテナンス',
    'load': '負荷',
    'low': '低',
    'medium': '中',
    'high': '高',

    // Banned/Maintenance
    'account_suspended': 'アカウント停止',
    'contact_support': 'サポートに連絡',
    'quit_app': 'アプリを終了',
    'under_maintenance': 'メンテナンス中',
    'maintenance_message': '現在メンテナンス中です。\nしばらくお待ちください。',
    'working_on_it': '作業中...',

    // About
    'app_version': 'アプリバージョン',
    'developer': '開発者',
    'rate_app': 'アプリを評価',
    'send_feedback': 'フィードバックを送信',

    // Contact
    'telegram': 'Telegram',
    'email': 'メール',
    'facebook': 'Facebook',

    // Onboarding
    'welcome': 'ようこそ',
    'get_started': '始める',
    'skip': 'スキップ',

    // Errors
    'connection_failed': '接続に失敗しました',
    'network_error': 'ネットワークエラー',
    'try_again': '再試行してください',
    'something_went_wrong': '問題が発生しました',
    'no_internet': 'インターネット接続がありません',

    // Time
    'hours': '時間',
    'minutes': '分',
    'seconds': '秒',
    'hour': '時間',
    'minute': '分',
    'second': '秒',
  };

  static const Map<String, String> _chinese = {
    // Navigation & Common
    'home': '主页',
    'settings': '设置',
    'back': '返回',
    'next': '下一步',
    'done': '完成',
    'ok': '确定',
    'cancel': '取消',
    'save': '保存',
    'close': '关闭',
    'retry': '重试',
    'loading': '加载中...',
    'please_wait': '请稍候...',
    'error': '错误',
    'success': '成功',
    'warning': '警告',
    'copy': '复制',
    'copied': '已复制',
    'share': '分享',

    // Home Screen
    'connect': '连接',
    'disconnect': '断开',
    'connecting': '连接中...',
    'connected': '已连接',
    'disconnected': '已断开',
    'tap_to_connect': '点击连接',
    'tap_to_disconnect': '点击断开',
    'select_location': '选择位置',
    'current_location': '当前位置',
    'time_remaining': '剩余时间',
    'watch_ad': '观看广告',
    'watch_ad_for_time': '观看广告获取时间',
    'no_time_left': '时间已用完。请观看广告。',
    'vpn_time': 'VPN时间',
    'download': '下载',
    'upload': '上传',

    // Location Selection
    'all_locations': '所有位置',
    'universal': '通用',
    'streaming': '流媒体',
    'search_location': '搜索位置...',
    'select_server': '选择服务器',
    'servers': '服务器',
    'server': '服务器',
    'best_location': '最佳位置',
    'auto_select': '自动选择',

    // Earn Money Screen
    'earn_money': '赚钱',
    'earn_points': '赚取积分',
    'total_points': '总积分',
    'your_balance': '您的余额',
    'today_earned': '今日收入',
    'today': '今天',
    'watch_ad_earn': '看广告赚钱',
    'watch_ad_to_earn': '观看广告赚取积分',
    'cooldown': '冷却时间',
    'cooldown_active': '冷却中',
    'wait_before_next_ad': '等待下一个广告',
    'ads_watched_today': '今日已看广告',
    'max_daily_limit': '已达到每日上限',
    'reward_per_ad': '每个广告奖励',
    'points': '积分',
    'point': '积分',

    // Withdraw Screen
    'withdraw': '提现',
    'withdraw_history': '提现记录',
    'withdraw_points': '提现积分',
    'minimum_withdraw': '最低提现额',
    'enter_amount': '输入金额',
    'payment_method': '支付方式',
    'account_number': '账号',
    'account_name': '账户名',
    'submit_request': '提交请求',
    'pending': '待处理',
    'approved': '已批准',
    'rejected': '已拒绝',
    'processing': '处理中',
    'no_history': '暂无记录',

    // Rewards Screen
    'rewards': '奖励',
    'daily_reward': '每日奖励',
    'claim': '领取',
    'claimed': '已领取',
    'bonus': '奖金',
    'streak': '连续',
    'day': '天',
    'days': '天',

    // Settings
    'language': '语言',
    'theme': '主题',
    'dark_mode': '深色模式',
    'light_mode': '浅色模式',
    'system': '系统',
    'split_tunneling': '分流',
    'vpn_protocol': 'VPN协议',
    'protocol': '协议',
    'auto': '自动',
    'display_latency': '显示延迟',
    'enable_debug_log': '启用调试日志',
    'push_setting': '推送通知',
    'theme_mode': '主题模式',
    'privacy_policy': '隐私政策',
    'terms_of_service': '服务条款',
    'contact_us': '联系我们',
    'about': '关于',
    'version': '版本',
    'device_id': '设备ID',
    'account': '账户',
    'vpn_settings': 'VPN设置',
    'app_settings': '应用设置',
    'support': '支持',

    // Split Tunneling
    'disable_split_tunneling': '禁用分流',
    'all_apps_use_vpn': '所有应用使用VPN',
    'only_selected_use_vpn': '仅选定应用使用VPN',
    'only_chosen_apps_use_vpn': '仅选定的应用使用VPN',
    'bypass_vpn_selected': '选定应用绕过VPN',
    'chosen_apps_bypass': '选定的应用将绕过VPN',
    'select_apps': '选择应用',
    'selected_apps': '已选应用',
    'no_apps_selected': '未选择应用',
    'search_apps': '搜索应用...',

    // VPN Protocol
    'auto_websocket': '自动 (WebSocket)',
    'tcp': 'TCP',
    'udp_quic': 'UDP (QUIC)',
    'recommended': '推荐',
    'best_compatibility': '最佳兼容性',
    'fast_reliable': '快速可靠',
    'best_for_gaming': '最适合游戏',

    // Server Status
    'online': '在线',
    'offline': '离线',
    'maintenance': '维护中',
    'load': '负载',
    'low': '低',
    'medium': '中',
    'high': '高',

    // Banned/Maintenance
    'account_suspended': '账户已暂停',
    'contact_support': '联系客服',
    'quit_app': '退出应用',
    'under_maintenance': '维护中',
    'maintenance_message': '我们正在进行维护。\n请稍后再来。',
    'working_on_it': '处理中...',

    // About
    'app_version': '应用版本',
    'developer': '开发者',
    'rate_app': '评价应用',
    'send_feedback': '发送反馈',

    // Contact
    'telegram': 'Telegram',
    'email': '邮箱',
    'facebook': 'Facebook',

    // Onboarding
    'welcome': '欢迎',
    'get_started': '开始',
    'skip': '跳过',

    // Errors
    'connection_failed': '连接失败',
    'network_error': '网络错误',
    'try_again': '请重试',
    'something_went_wrong': '出错了',
    'no_internet': '无网络连接',

    // Time
    'hours': '小时',
    'minutes': '分钟',
    'seconds': '秒',
    'hour': '小时',
    'minute': '分钟',
    'second': '秒',
  };

  static const Map<String, String> _thai = {
    // Navigation & Common
    'home': 'หน้าแรก',
    'settings': 'ตั้งค่า',
    'back': 'กลับ',
    'next': 'ถัดไป',
    'done': 'เสร็จสิ้น',
    'ok': 'ตกลง',
    'cancel': 'ยกเลิก',
    'save': 'บันทึก',
    'close': 'ปิด',
    'retry': 'ลองอีกครั้ง',
    'loading': 'กำลังโหลด...',
    'please_wait': 'กรุณารอสักครู่...',
    'error': 'ข้อผิดพลาด',
    'success': 'สำเร็จ',
    'warning': 'คำเตือน',
    'copy': 'คัดลอก',
    'copied': 'คัดลอกแล้ว',
    'share': 'แชร์',

    // Home Screen
    'connect': 'เชื่อมต่อ',
    'disconnect': 'ตัดการเชื่อมต่อ',
    'connecting': 'กำลังเชื่อมต่อ...',
    'connected': 'เชื่อมต่อแล้ว',
    'disconnected': 'ตัดการเชื่อมต่อแล้ว',
    'tap_to_connect': 'แตะเพื่อเชื่อมต่อ',
    'tap_to_disconnect': 'แตะเพื่อตัดการเชื่อมต่อ',
    'select_location': 'เลือกตำแหน่ง',
    'current_location': 'ตำแหน่งปัจจุบัน',
    'time_remaining': 'เวลาที่เหลือ',
    'watch_ad': 'ดูโฆษณา',
    'watch_ad_for_time': 'ดูโฆษณาเพื่อรับเวลา',
    'no_time_left': 'หมดเวลาแล้ว กรุณาดูโฆษณา',
    'vpn_time': 'เวลา VPN',
    'download': 'ดาวน์โหลด',
    'upload': 'อัปโหลด',

    // Location Selection
    'all_locations': 'ทุกตำแหน่ง',
    'universal': 'ทั่วไป',
    'streaming': 'สตรีมมิ่ง',
    'search_location': 'ค้นหาตำแหน่ง...',
    'select_server': 'เลือกเซิร์ฟเวอร์',
    'servers': 'เซิร์ฟเวอร์',
    'server': 'เซิร์ฟเวอร์',
    'best_location': 'ตำแหน่งที่ดีที่สุด',
    'auto_select': 'เลือกอัตโนมัติ',

    // Earn Money Screen
    'earn_money': 'หาเงิน',
    'earn_points': 'รับคะแนน',
    'total_points': 'คะแนนรวม',
    'your_balance': 'ยอดคงเหลือ',
    'today_earned': 'รายได้วันนี้',
    'today': 'วันนี้',
    'watch_ad_earn': 'ดูโฆษณาและรับ',
    'watch_ad_to_earn': 'ดูโฆษณาเพื่อรับคะแนน',
    'cooldown': 'รอเวลา',
    'cooldown_active': 'กำลังรอ',
    'wait_before_next_ad': 'รอก่อนดูโฆษณาถัดไป',
    'ads_watched_today': 'โฆษณาที่ดูวันนี้',
    'max_daily_limit': 'ถึงขีดจำกัดรายวันแล้ว',
    'reward_per_ad': 'รางวัลต่อโฆษณา',
    'points': 'คะแนน',
    'point': 'คะแนน',

    // Withdraw Screen
    'withdraw': 'ถอนเงิน',
    'withdraw_history': 'ประวัติการถอน',
    'withdraw_points': 'ถอนคะแนน',
    'minimum_withdraw': 'ถอนขั้นต่ำ',
    'enter_amount': 'ใส่จำนวน',
    'payment_method': 'วิธีชำระเงิน',
    'account_number': 'เลขบัญชี',
    'account_name': 'ชื่อบัญชี',
    'submit_request': 'ส่งคำขอ',
    'pending': 'รอดำเนินการ',
    'approved': 'อนุมัติแล้ว',
    'rejected': 'ถูกปฏิเสธ',
    'processing': 'กำลังดำเนินการ',
    'no_history': 'ยังไม่มีประวัติ',

    // Rewards Screen
    'rewards': 'รางวัล',
    'daily_reward': 'รางวัลประจำวัน',
    'claim': 'รับ',
    'claimed': 'รับแล้ว',
    'bonus': 'โบนัส',
    'streak': 'ต่อเนื่อง',
    'day': 'วัน',
    'days': 'วัน',

    // Settings
    'language': 'ภาษา',
    'theme': 'ธีม',
    'dark_mode': 'โหมดมืด',
    'light_mode': 'โหมดสว่าง',
    'system': 'ระบบ',
    'split_tunneling': 'Split Tunneling',
    'vpn_protocol': 'โปรโตคอล VPN',
    'protocol': 'โปรโตคอล',
    'auto': 'อัตโนมัติ',
    'display_latency': 'แสดงความหน่วง',
    'enable_debug_log': 'เปิดใช้ Debug Log',
    'push_setting': 'การแจ้งเตือน',
    'theme_mode': 'โหมดธีม',
    'privacy_policy': 'นโยบายความเป็นส่วนตัว',
    'terms_of_service': 'ข้อกำหนดการใช้งาน',
    'contact_us': 'ติดต่อเรา',
    'about': 'เกี่ยวกับ',
    'version': 'เวอร์ชัน',
    'device_id': 'รหัสอุปกรณ์',
    'account': 'บัญชี',
    'vpn_settings': 'ตั้งค่า VPN',
    'app_settings': 'ตั้งค่าแอป',
    'support': 'ฝ่ายสนับสนุน',

    // Split Tunneling
    'disable_split_tunneling': 'ปิด Split Tunneling',
    'all_apps_use_vpn': 'แอปทั้งหมดใช้ VPN',
    'only_selected_use_vpn': 'เฉพาะแอปที่เลือกใช้ VPN',
    'only_chosen_apps_use_vpn': 'เฉพาะแอปที่เลือกจะใช้ VPN',
    'bypass_vpn_selected': 'แอปที่เลือกจะไม่ใช้ VPN',
    'chosen_apps_bypass': 'แอปที่เลือกจะข้าม VPN',
    'select_apps': 'เลือกแอป',
    'selected_apps': 'แอปที่เลือก',
    'no_apps_selected': 'ยังไม่ได้เลือกแอป',
    'search_apps': 'ค้นหาแอป...',

    // VPN Protocol
    'auto_websocket': 'อัตโนมัติ (WebSocket)',
    'tcp': 'TCP',
    'udp_quic': 'UDP (QUIC)',
    'recommended': 'แนะนำ',
    'best_compatibility': 'ความเข้ากันได้ดีที่สุด',
    'fast_reliable': 'เร็วและเชื่อถือได้',
    'best_for_gaming': 'ดีที่สุดสำหรับเกม',

    // Server Status
    'online': 'ออนไลน์',
    'offline': 'ออฟไลน์',
    'maintenance': 'บำรุงรักษา',
    'load': 'โหลด',
    'low': 'ต่ำ',
    'medium': 'ปานกลาง',
    'high': 'สูง',

    // Banned/Maintenance
    'account_suspended': 'บัญชีถูกระงับ',
    'contact_support': 'ติดต่อฝ่ายสนับสนุน',
    'quit_app': 'ออกจากแอป',
    'under_maintenance': 'อยู่ระหว่างการบำรุงรักษา',
    'maintenance_message': 'เรากำลังทำการบำรุงรักษา\nกรุณากลับมาใหม่ภายหลัง',
    'working_on_it': 'กำลังดำเนินการ...',

    // About
    'app_version': 'เวอร์ชันแอป',
    'developer': 'ผู้พัฒนา',
    'rate_app': 'ให้คะแนนแอป',
    'send_feedback': 'ส่งความคิดเห็น',

    // Contact
    'telegram': 'Telegram',
    'email': 'อีเมล',
    'facebook': 'Facebook',

    // Onboarding
    'welcome': 'ยินดีต้อนรับ',
    'get_started': 'เริ่มต้น',
    'skip': 'ข้าม',

    // Errors
    'connection_failed': 'การเชื่อมต่อล้มเหลว',
    'network_error': 'ข้อผิดพลาดของเครือข่าย',
    'try_again': 'ลองอีกครั้ง',
    'something_went_wrong': 'เกิดข้อผิดพลาด',
    'no_internet': 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต',

    // Time
    'hours': 'ชั่วโมง',
    'minutes': 'นาที',
    'seconds': 'วินาที',
    'hour': 'ชั่วโมง',
    'minute': 'นาที',
    'second': 'วินาที',
  };
}

/// Extension to make translation easier
extension TranslationExtension on String {
  String get tr => LocalizationService().tr(this);
}
