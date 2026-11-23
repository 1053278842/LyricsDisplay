import RPi.GPIO as GPIO
import time

# 设定引脚编号模式
GPIO.setmode(GPIO.BCM)

# 使用 GPIO13
BACKLIGHT_PIN = 13

# 设置引脚为输出并启用 PWM
GPIO.setup(BACKLIGHT_PIN, GPIO.OUT)
pwm = GPIO.PWM(BACKLIGHT_PIN, 1000)  # 频率 1kHz
pwm.start(100)  # 初始亮度为 100%

try:
    while True:
        # 从亮到暗
        for dc in range(100, 0, -10):
            pwm.ChangeDutyCycle(dc)
            time.sleep(0.1)

        # 从暗到亮
        for dc in range(0, 101, 10):
            pwm.ChangeDutyCycle(dc)
            time.sleep(0.1)

except KeyboardInterrupt:
    pass

pwm.stop()
GPIO.cleanup()
