# FOREGROUND_SERVICE_SPECIAL_USE Permission Description

## Video Link (Optional)
ဤ field ကို ထားခဲ့နိုင်ပါတယ် (optional)။ သို့မဟုတ် app ကို run လုပ်ပြီး VPN connect လုပ်တဲ့ video screen recording တစ်ခု upload လုပ်နိုင်ပါတယ်။

## Describe Permission Use (Required)

```
Our app uses the FOREGROUND_SERVICE_SPECIAL_USE permission to maintain a continuous VPN (Virtual Private Network) connection service that routes all device network traffic through an encrypted tunnel.

Why this task must start immediately:
- VPN connections require immediate establishment to prevent any data leakage before the secure tunnel is active
- Users expect instant connection when they tap the connect button, as any delay exposes their network traffic to potential interception
- The VPN service must bind to the system VPN interface immediately to intercept network packets before they leave the device

Why this task cannot be paused or restarted:
- VPN connections maintain active network sockets and routing tables that cannot be paused without breaking the connection
- Pausing the service would disconnect the VPN, exposing user's real IP address and unencrypted traffic
- Restarting would require re-establishing the VPN interface, re-authenticating with the server, and re-routing all active connections, causing service interruption
- Active VPN sessions maintain stateful connections (TCP sessions, UDP streams) that cannot be preserved across pause/resume cycles
- The service manages a native VPN process (sing-box) that handles real-time packet forwarding - interrupting this process would cause all active network sessions to fail

The foreground service displays a persistent notification showing VPN connection status, allowing users to monitor their connection and quickly disconnect when needed. This is essential for user awareness and control over their privacy and security.
```

## Alternative Shorter Version (if character limit)

```
Our app uses FOREGROUND_SERVICE_SPECIAL_USE to maintain a continuous VPN connection service that encrypts and routes all device network traffic.

The service must start immediately to prevent data leakage before the secure tunnel is active. It cannot be paused or restarted because:
1. VPN connections maintain active network sockets and routing tables that break if paused
2. Pausing would disconnect the VPN, exposing user's real IP and unencrypted traffic  
3. Restarting requires re-establishing VPN interface and re-authenticating, causing service interruption
4. Active VPN sessions maintain stateful connections that cannot be preserved across pause/resume

The foreground service displays a notification showing VPN status, essential for user awareness of their privacy and security.
```








