import time
import sys
import math
import serial
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.colors import hsv_to_rgb

# -------------------------
# 1) Initialize the Serial
# -------------------------
ser = serial.Serial(
    port='COM3',
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1.0
)
print("Connected to", ser.name)

# -------------------------
# 2) Global Plot Settings
# -------------------------
xsize = 100       # Number of samples to show on the x-axis
time_index = 0
xdata, ydata = [], []

fig = plt.figure()
ax = fig.add_subplot(111)

# Set up the line object
line, = ax.plot([], [], lw=2)

# Initial boundaries
ax.set_xlim(0, xsize)
ax.set_ylim(0, 50)
ax.set_xlabel("Sample #")
ax.set_ylabel("Temperature (°C)")
ax.set_title("Reflow Oven Temperature")
ax.grid(True)

# -------------------------
# 3) Data Generator
# -------------------------
def data_gen():
    global time_index
    while True:
        line_in = ser.readline().decode("utf-8", errors="ignore").strip()
        if line_in:
            # Strip trailing 'C' if present
            if line_in.endswith('C'):
                temp_str = line_in[:-1]
            else:
                temp_str = line_in
            
            try:
                temperature_value = float(temp_str)
            except ValueError:
                # If conversion fails, assume 0 °C
                temperature_value = 0
            
            # Enforce no negative temperatures
            if temperature_value < 0:
                temperature_value = 0

            yield time_index, temperature_value
            time_index += 1
        
        # Slight delay to avoid busy-wait
        time.sleep(0.05)

# -------------------------
# 4) Color Mapping Function
#    (0°C -> Blue, 240°C -> Red)
# -------------------------
def temperature_to_color(temp):
    """
    Maps temp in [0..240] °C to a hue in [2/3..0].
    0 => pure blue (hue=2/3), 
    240 => pure red (hue=0).
    """
    # Clamp temperature to [0, 240]
    t_clamped = max(0, min(240, temp))
    
    # Fraction of the way to 240
    fraction = t_clamped / 240.0
    
    # Hue goes from 0.6667 (blue) down to 0 (red)
    hue = 0.6667 * (1.0 - fraction)
    
    # Full saturation=1, value=1 => hsv_to_rgb
    r, g, b = hsv_to_rgb((hue, 1.0, 1.0))
    return (r, g, b)

# -------------------------
# 5) Animation Update
# -------------------------
def run(update_data):
    t, temp = update_data
    xdata.append(t)
    ydata.append(temp)

    # Scroll the x-axis as time increases
    if t > xsize:
        ax.set_xlim(t - xsize, t)

    # Adjust y-axis if we exceed the current limit
    margin = 5
    y_min, y_max = ax.get_ylim()
    if temp > (y_max - margin):
        ax.set_ylim(y_min, temp + margin)

    # Update the line data
    line.set_data(xdata, ydata)

    # Color based on temperature (0 -> blue, 240 -> red)
    line_color = temperature_to_color(temp)
    line.set_color(line_color)

    return line,

# -------------------------
# 6) On-Close Handler
# -------------------------
def on_close_figure(event):
    print("Closing figure and serial port...")
    ser.close()
    sys.exit(0)

fig.canvas.mpl_connect('close_event', on_close_figure)

# -------------------------
# 7) Launch Animation
# -------------------------
ani = animation.FuncAnimation(
    fig,
    run,
    data_gen,
    blit=False,
    interval=100,
    repeat=False
)

plt.show()
