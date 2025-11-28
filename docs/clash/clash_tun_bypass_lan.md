# 配置 Clash Tun 模式下的 Bypass 策略

## 放到全局扩展覆写配置中：
```yaml
tun:
  enable: true
  stack: system
  auto-route: true
  auto-detect-interface: true
  bypass-ip-cidr:
    - 192.168.0.0/16
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 127.0.0.0/8
    - ::1/128
