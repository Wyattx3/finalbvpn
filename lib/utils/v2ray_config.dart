import 'dart:convert';

class V2RayConfig {
  static String generateConfig({
    required String serverAddress,
    required int serverPort,
    required String uuid,
    required int alterId,
    required String security,
    required String network, // ws, tcp, quic, grpc
    required String path,
    required bool tls,
    required String remark,
  }) {
    final Map<String, dynamic> outbound = {
      "tag": "proxy",
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": serverAddress,
            "port": serverPort,
            "users": [
              {
                "id": uuid,
                "alterId": alterId,
                "email": "t@t.tt",
                "security": security
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": network,
        "security": tls ? "tls" : "none",
        "tlsSettings": tls ? {"allowInsecure": true, "serverName": serverAddress} : null,
      }
    };

    // Protocol specific settings
    if (network == "ws") {
      outbound["streamSettings"]["wsSettings"] = {
        "path": path,
        "headers": {"Host": serverAddress}
      };
    } else if (network == "tcp") {
      // No specific settings needed for basic TCP
    } else if (network == "quic") {
      outbound["streamSettings"]["quicSettings"] = {
        "security": "none",
        "header": {"type": "none"}
      };
    } else if (network == "grpc") {
      outbound["streamSettings"]["grpcSettings"] = {
        "serviceName": path,
        "multiMode": true
      };
    }

    final Map<String, dynamic> config = {
      "log": {
        "access": "",
        "error": "",
        "loglevel": "warning"
      },
      "inbounds": [
        {
          "tag": "socks",
          "port": 10808,
          "listen": "127.0.0.1",
          "protocol": "socks",
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls"]
          },
          "settings": {
            "auth": "noauth",
            "udp": true,
            "allowTransparent": false
          }
        },
        {
          "tag": "http",
          "port": 10809,
          "listen": "127.0.0.1",
          "protocol": "http",
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls"]
          },
          "settings": {
            "auth": "noauth",
            "udp": true,
            "allowTransparent": false
          }
        }
      ],
      "outbounds": [
        outbound,
        {
          "tag": "direct",
          "protocol": "freedom",
          "settings": {}
        },
        {
          "tag": "block",
          "protocol": "blackhole",
          "settings": {
            "response": {"type": "http"}
          }
        }
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          {
            "type": "field",
            "ip": ["geoip:private"],
            "outboundTag": "direct"
          }
        ]
      }
    };

    return jsonEncode(config);
  }
}

