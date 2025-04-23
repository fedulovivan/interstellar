from machine import Pin, Timer, ADC

led = Pin("LED", Pin.OUT)
tim1 = Timer()
tim2 = Timer()
adcpin = 4
sensor = ADC(adcpin)

def ReadTemperature():
    adc_value = sensor.read_u16()
    volt = (3.3/65535) * adc_value
    temperature = 27 - (volt - 0.706)/0.001721
    return round(temperature, 1)

def tick1(timer):
    global led
    led.toggle()
tim1.init(freq=1, mode=Timer.PERIODIC, callback=tick1)
  
def tick2(timer):
    print(ReadTemperature())
tim2.init(freq=1, mode=Timer.PERIODIC, callback=tick2)