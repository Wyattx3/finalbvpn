import 'dart:async';

class MockSduiService {
  // Simulate network delay and fetch JSON configuration
  Future<Map<String, dynamic>> getScreenConfig(String screenId) async {
    // Simulate a short network delay
    await Future.delayed(const Duration(milliseconds: 200));

    if (screenId == 'onboarding') {
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
              "description": "Your data is encrypted with bank-grade security protocols.",
              "image": "assets/images/onboarding/Secure & Private.png"
            },
            {
              "title": "Earn Rewards",
              "description": "Watch ads and complete tasks to earn\nreal money rewards.",
              "image": "assets/images/onboarding/earn rewards.jpg"
            }
          ],
          "assets": {
            "dot_prefix": "assets/images/onboarding/dot",
            "next_button": "assets/images/onboarding/next.png",
            "start_button": "assets/images/onboarding/get start.png"
          }
        }
      };
    } else if (screenId == 'home') {
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
    } else if (screenId == 'popup_startup') {
      // ==========================================================
      // DYNAMIC POPUP SDUI - Choose ONE scenario to test
      // display_type options: "popup", "bottom_sheet", "full_screen"
      // 
      // SERVER CONTROL:
      // - Set "enabled": false to HIDE the popup
      // - Set "enabled": true to SHOW the popup
      // - Or return empty {} to hide completely
      // ==========================================================

      // OPTION A: Return empty to completely disable popup
      // return {};

      // OPTION B: Use "enabled" flag to control visibility
      // Set to false to hide, true to show
      
      // SCENARIO 1: CENTER POPUP - Promotion (Dismissible)
      // Uncomment this block to test CENTER POPUP style
      
      return {
        "screen_id": "popup_startup",
        "config": {
          "enabled": true, // <-- SET TO false TO HIDE POPUP FROM SERVER
          "display_type": "popup", // CENTER DIALOG
          "image_url": "assets/images/onboarding/earn rewards.jpg",
          "image_height": 180,
          "title": "Special Offer! 🎉",
          "message": "Get 50% bonus rewards for watching ads today! Limited time only.",
          "is_dismissible": true,
          "style": {
            "background_color": "#FFFFFF",
            "title_color": "#7E57C2",
            "title_size": 22,
            "message_color": "#666666",
            "message_size": 15
          },
          "buttons": [
            {
              "label": "Earn Now",
              "action": "close",
              "color": "#7E57C2"
            },
            {
              "label": "Maybe Later",
              "action": "close",
              "color": "#9E9E9E",
              "outlined": true
            }
          ]
        }
      };
      

      // SCENARIO 2: BOTTOM SHEET - Force Update (Non-dismissible)
      // Uncomment this block to test BOTTOM SHEET style
      /*
      return {
        "screen_id": "popup_startup",
        "config": {
          "display_type": "bottom_sheet", // BOTTOM MODAL SHEET
          "image_url": "assets/images/onboarding/High Speed.png",
          "image_height": 160,
          "title": "Update Available",
          "message": "A new version (v2.0.0) is available with exciting features and bug fixes. Update now for the best experience!",
          "is_dismissible": false,
          "style": {
            "background_color": "#FFFFFF",
            "title_color": "#1976D2",
            "title_size": 22,
            "message_color": "#666666",
            "message_size": 15
          },
          "buttons": [
            {
              "label": "Update Now",
              "action": "link",
              "target": "https://play.google.com/store/apps/details?id=com.vpnapp",
              "color": "#1976D2"
            }
          ]
        }
      };
      */

      // SCENARIO 3: FULL SCREEN - Account Ban (Non-dismissible)
      // Uncomment this block to test FULL SCREEN style
      /*
      return {
        "screen_id": "popup_startup",
        "config": {
          "display_type": "full_screen", // FULL SCREEN PAGE
          "image_url": "assets/images/onboarding/Secure & Private.png",
          "image_height": 200,
          "title": "Account Suspended",
          "message": "Your account has been suspended due to violation of our Terms of Service.\n\nIf you believe this is a mistake, please contact our support team.",
          "is_dismissible": false,
          "style": {
            "background_color": "#D32F2F",
            "title_color": "#FFFFFF",
            "title_size": 28,
            "message_color": "#FFCDD2",
            "message_size": 16
          },
          "buttons": [
            {
              "label": "Contact Support",
              "action": "link",
              "target": "mailto:support@vpnapp.com",
              "color": "#B71C1C"
            },
            {
              "label": "Exit App",
              "action": "exit_app",
              "color": "#424242"
            }
          ]
        }
      };
      */

      // SCENARIO 4: BOTTOM SHEET - Welcome / New Feature
      // Uncomment this block to test BOTTOM SHEET welcome style
      /*
      return {
        "screen_id": "popup_startup",
        "config": {
          "display_type": "bottom_sheet",
          "image_url": "assets/images/onboarding/Global servers.png",
          "image_height": 180,
          "title": "Welcome Back! 👋",
          "message": "We've added 10 new server locations including Japan, Singapore, and more. Try them out now!",
          "is_dismissible": true,
          "style": {
            "background_color": "#FAFAFA",
            "title_color": "#333333",
            "title_size": 24,
            "message_color": "#757575",
            "message_size": 16
          },
          "buttons": [
            {
              "label": "Explore Servers",
              "action": "close",
              "color": "#7E57C2"
            },
            {
              "label": "Dismiss",
              "action": "close",
              "color": "#9E9E9E",
              "outlined": true
            }
          ]
        }
      };
      */

      // SCENARIO 5: FULL SCREEN - Maintenance Notice
      // Uncomment this block to test FULL SCREEN maintenance style
      /*
      return {
        "screen_id": "popup_startup",
        "config": {
          "display_type": "full_screen",
          "image_url": "assets/images/onboarding/Secure & Private.png",
          "image_height": 180,
          "title": "Scheduled Maintenance",
          "message": "We're performing scheduled maintenance to improve our services.\n\nEstimated completion: 2 hours\n\nThank you for your patience!",
          "is_dismissible": false,
          "style": {
            "background_color": "#FF9800",
            "title_color": "#FFFFFF",
            "title_size": 26,
            "message_color": "#FFF3E0",
            "message_size": 16
          },
          "buttons": [
            {
              "label": "Check Status",
              "action": "link",
              "target": "https://status.vpnapp.com",
              "color": "#E65100"
            }
          ]
        }
      };
      */
      
    } else if (screenId == 'location_selection') {
      return {
        "screen_id": "location_selection",
        "config": {
          "title": "Select Location",
          "tabs": [
             {"id": "universal", "label": "Universal"},
             {"id": "streaming", "label": "Streaming"}
          ],
          "universal_locations": [
            {
              'country': 'United States',
              'flag': '🇺🇸',
              'cities': [
                'US - San Jose',
                'US - Los Angeles',
                'US - New York',
                'US - Ashburn',
                'US - Virginia',
                'US - Miami',
                'US - Oregon',
                'US - Dallas',
              ]
            },
            {
              'country': 'Canada',
              'flag': '🇨🇦',
              'cities': ['CA - Vancouver', 'CA - Toronto', 'CA - Montreal']
            },
            {
              'country': 'United Kingdom',
              'flag': '🇬🇧',
              'cities': ['UK - London', 'UK - Manchester']
            },
            {
              'country': 'Singapore',
              'flag': '🇸🇬',
              'cities': ['SG - Singapore']
            },
            {
              'country': 'Japan',
              'flag': '🇯🇵',
              'cities': ['JP - Tokyo', 'JP - Osaka']
            },
            {
              'country': 'Germany',
              'flag': '🇩🇪',
              'cities': ['DE - Frankfurt', 'DE - Berlin', 'DE - Munich']
            },
            {
              'country': 'France',
              'flag': '🇫🇷',
              'cities': ['FR - Paris', 'FR - Marseille']
            },
            {
              'country': 'Netherlands',
              'flag': '🇳🇱',
              'cities': ['NL - Amsterdam', 'NL - Rotterdam']
            },
            {
              'country': 'Australia',
              'flag': '🇦🇺',
              'cities': ['AU - Sydney', 'AU - Melbourne', 'AU - Perth']
            },
            {
              'country': 'South Korea',
              'flag': '🇰🇷',
              'cities': ['KR - Seoul', 'KR - Busan']
            },
            {
              'country': 'Hong Kong',
              'flag': '🇭🇰',
              'cities': ['HK - Hong Kong']
            },
            {
              'country': 'Taiwan',
              'flag': '🇹🇼',
              'cities': ['TW - Taipei', 'TW - Kaohsiung']
            },
            {
              'country': 'India',
              'flag': '🇮🇳',
              'cities': ['IN - Mumbai', 'IN - Delhi', 'IN - Bangalore']
            },
            {
              'country': 'Brazil',
              'flag': '🇧🇷',
              'cities': ['BR - Sao Paulo', 'BR - Rio de Janeiro']
            },
            {
              'country': 'Sweden',
              'flag': '🇸🇪',
              'cities': ['SE - Stockholm']
            },
          ],
          "streaming_locations": [
            {
              'country': 'Netflix',
              'flag': '🎬',
              'cities': ['US - Netflix', 'UK - Netflix', 'JP - Netflix']
            },
             {
              'country': 'Disney+',
              'flag': '📺',
              'cities': ['US - Disney+']
            },
          ]
        }
      };
    } else if (screenId == 'rewards') {
      return {
        "screen_id": "rewards",
        "config": {
          "title": "My Rewards",
          "payment_methods": ["KBZ Pay", "Wave Pay"],
          "min_withdraw_mmk": 20000,
          "min_withdraw_usd": 20.0,
          "labels": {
            "balance_label": "Total Points",
            "withdraw_button": "Withdraw Now"
          }
        }
      };
    } else if (screenId == 'earn_money') {
      return {
        "screen_id": "earn_money",
        "config": {
           "title": "Earn Money",
           "reward_per_ad": 30,
           "max_ads_per_day": 100,
           "currency": "Points",
           "labels": {
             "balance_label": "Total Points",
             "watch_ad_button": "Watch Ad & Earn",
             "daily_limit_reached": "Daily Limit Reached"
           }
        }
      };
    } else if (screenId == 'settings') {
      return {
        "screen_id": "settings",
        "config": {
          "title": "Settings",
          "account_id": "19a070***04eef7",
          "share_text": "Check out VPN App - Secure, Fast & Private VPN!\n\nDownload now: https://play.google.com/store/apps/details?id=com.vpnapp",
          "version": "V1.0.8 (latest)"
        }
      };
    } else if (screenId == 'contact_us') {
      return {
        "screen_id": "contact_us",
        "config": {
          "title": "Contact Us",
          "email": "support@vpnapp.com",
          "telegram": "@vpnapp_support"
        }
      };
    } else if (screenId == 'about') {
      return {
        "screen_id": "about",
        "config": {
          "title": "About",
          "app_name": "VPN App",
          "version": "1.0.8",
          "description": "The best VPN app for secure and private internet access."
        }
      };
    } else if (screenId == 'privacy_policy') {
      return {
        "screen_id": "privacy_policy",
        "config": {
          "title": "Privacy Policy",
          "content": "Privacy Policy\n\n1. Introduction\nWe respect your privacy and are committed to protecting it.\n\n2. Data Collection\nWe do not collect any personal browsing data. We only collect connection logs for troubleshooting.\n\n3. Usage\nYour data is used solely to provide and improve our VPN service.\n\n4. Security\nWe use industry-standard encryption to protect your data."
        }
      };
    } else if (screenId == 'terms_of_service') {
      return {
        "screen_id": "terms_of_service",
        "config": {
          "title": "Terms of Service",
          "content": "Terms of Service\n\n1. Acceptance\nBy using our app, you agree to these terms.\n\n2. Usage\nYou agree not to use the app for any illegal activities.\n\n3. Termination\nWe reserve the right to terminate your access if you violate these terms.\n\n4. Disclaimer\nThe app is provided 'as is' without warranties of any kind."
        }
      };
    } else if (screenId == 'language') {
      return {
        "screen_id": "language",
        "config": {
          "title": "Language",
          "languages": [
            {'name': 'English', 'native': 'English', 'code': 'en'},
            {'name': 'Myanmar', 'native': 'မြန်မာ', 'code': 'my'},
            {'name': 'Chinese', 'native': '中文', 'code': 'zh'},
            {'name': 'Thai', 'native': 'ไทย', 'code': 'th'},
            {'name': 'Japanese', 'native': '日本語', 'code': 'ja'},
            {'name': 'Korean', 'native': '한국어', 'code': 'ko'},
            {'name': 'Vietnamese', 'native': 'Tiếng Việt', 'code': 'vi'},
            {'name': 'Hindi', 'native': 'हिन्दी', 'code': 'hi'}
          ]
        }
      };
    } else if (screenId == 'splash') {
      return {
        "screen_id": "splash",
        "config": {
          "app_name": "SafeVPN",
          "tagline": "Secure & Fast",
          "gradient_colors": ["#7E57C2", "#B39DDB"],
          "splash_duration_seconds": 3
        }
      };
    } else if (screenId == 'split_tunneling') {
      return {
        "screen_id": "split_tunneling",
        "config": {
          "title": "Split Tunneling",
          "options": [
            {"index": 0, "icon": "call_split", "title": "Disable", "subtitle": "No effect"},
            {"index": 1, "icon": "filter_list", "title": "Uses VPN", "subtitle": "Only allows selected applications to use the VPN"},
            {"index": 2, "icon": "block", "title": "Bypass VPN", "subtitle": "Disallows selected applications to use the VPN"}
          ],
          "labels": {
            "selected_apps": "Selected Applications",
            "select_apps": "Select Applications",
            "clear_all": "Clear All"
          }
        }
      };
    } else if (screenId == 'vpn_protocol') {
      return {
        "screen_id": "vpn_protocol",
        "config": {
          "title": "VPN Protocol",
          "protocols": [
            {"index": 0, "title": "Auto", "description": "Automatically select the best protocol"},
            {"index": 1, "title": "TCP", "description": "Transmission Control Protocol"},
            {"index": 2, "title": "UDP", "description": "User Datagram Protocol"}
          ]
        }
      };
    } else if (screenId == 'withdraw_history') {
      return {
        "screen_id": "withdraw_history",
        "config": {
          "title": "Withdraw History",
          "labels": {
            "pending": "Pending",
            "completed": "Completed",
            "failed": "Failed"
          }
        }
      };
    } else if (screenId == 'withdraw_details') {
      return {
        "screen_id": "withdraw_details",
        "config": {
          "title": "Transaction Details",
          "labels": {
            "transaction_info": "Transaction Information",
            "date": "Date",
            "payment_method": "Payment Method",
            "account_name": "Account Name",
            "account_number": "Account Number",
            "transaction_id": "Transaction ID"
          }
        }
      };
    } else if (screenId == 'withdraw_success') {
      return {
        "screen_id": "withdraw_success",
        "config": {
          "title": "Request Submitted!",
          "description": "Your withdraw request has been received. We will process it within 3 business days.",
          "button_text": "Back to Home"
        }
      };
    } else if (screenId == 'app_selection') {
      return {
        "screen_id": "app_selection",
        "config": {
          "labels": {
            "selected": "Selected",
            "clear_all": "Clear All",
            "select_applications": "Select Applications"
          }
        }
      };
    }
    
    // Default empty config
    return {};
  }
}
