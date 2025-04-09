import socket

class CommonUtil:
    
    # 解析 raspberrypi.local 的 IP 地址
    def get_ip_from_hostname(hostname):
        try:
            ip = socket.gethostbyname(hostname)
            return ip
        except socket.gaierror:
            return None