from bluetooth import discover_devices, lookup_name

def discover_devices_func():
    # 扫描附近的设备
    nearby_devices = discover_devices()
    for addr in nearby_devices:
        try:
            name = lookup_name(addr)  # 获取设备的名称
            print(f"设备地址: {addr}, 设备名称: {name}")
        except Exception as e:
            print(f"无法获取设备名称，地址: {addr}, 错误: {e}")

# 执行设备扫描
discover_devices_func()
