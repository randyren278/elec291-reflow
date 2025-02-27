import time
import sys
import math
import serial
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.colors import hsv_to_rgb
from matplotlib.widgets import Button

# -------------------------
# 1) Initialize the Serial
# -------------------------
ser = serial.Serial(
    port='COM4',
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1.0
)
print("Connected to", ser.name)

# -----------------------------------------------------
# 2) Language Dictionaries for Labels and Title
# -----------------------------------------------------
labels_dict = {
    'english': {
        'title': "Reflow Oven Temperature",
        'xlabel': "Sample #",
        'ylabel': "Temperature (°C)"
    },
    'german': {
        'title': "Reflow-Ofen Temperatur",
        'xlabel': "Probe #",
        'ylabel': "Temperatur (°C)"
    }
}

current_language = 'english'  # Default language

# -----------------------------------------------------
# 3) Global Plot Settings
# -----------------------------------------------------
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

# Apply default language labels
ax.set_xlabel(labels_dict[current_language]['xlabel'])
ax.set_ylabel(labels_dict[current_language]['ylabel'])
ax.set_title(labels_dict[current_language]['title'])

ax.grid(True)

# -------------------------
# 4) Live Temperature Text
#     - top-right corner
# -------------------------
temp_text = ax.text(
    0.95,         # x-position in axes fraction
    0.95,         # y-position in axes fraction
    "",           # initial text
    transform=ax.transAxes,
    ha='right',   # align to right
    va='top',     # align to top
    fontsize=12,
    color='blue'
)

# -----------------------------------------------------
# 5) Data Generator
# -----------------------------------------------------
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

# -----------------------------------------------------
# 6) Color Mapping Function
#     (0°C -> Blue, 280°C -> Red)
# -----------------------------------------------------
def temperature_to_color(temp):
    """
    Maps temp in [0..280] °C to a hue in [2/3..0].
    0 => pure blue (hue=2/3),
    280 => pure red (hue=0).
    """
    # Clamp temperature to [0, 280]
    t_clamped = max(0, min(280, temp))

    # Fraction of the way to 280
    fraction = t_clamped / 280.0

    # Hue goes from 0.6667 (blue) down to 0 (red)
    hue = 0.6667 * (1.0 - fraction)

    # Full saturation=1, value=1 => hsv_to_rgb
    r, g, b = hsv_to_rgb((hue, 1.0, 1.0))
    return (r, g, b)

# -----------------------------------------------------
# 7) Animation Update
# -----------------------------------------------------
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

    # Update color based on temperature (0 -> blue, 280 -> red)
    line_color = temperature_to_color(temp)
    line.set_color(line_color)

    # Update the live temperature reading in the top-right
    temp_text.set_text(f"{temp:.2f} °C")
    # We can also change color of the text if we want:
    temp_text.set_color(line_color)

    return line, temp_text

# -----------------------------------------------------
# 8) Language Switch Functions
# -----------------------------------------------------
def set_language(lang):
    global current_language
    current_language = lang
    ax.set_xlabel(labels_dict[lang]['xlabel'])
    ax.set_ylabel(labels_dict[lang]['ylabel'])
    ax.set_title(labels_dict[lang]['title'])
    fig.canvas.draw_idle()

def on_english_clicked(event):
    set_language('english')

def on_german_clicked(event):
    set_language('german')

# -----------------------------------------------------
# 9) Add Buttons to the Figure
# -----------------------------------------------------
# We'll create a small area at the bottom-left for each button
button_width = 0.1
button_height = 0.05

ax_button_english = plt.axes([0.05, 0.05, button_width, button_height])
ax_button_german  = plt.axes([0.17, 0.05, button_width, button_height])

button_english = Button(ax_button_english, "English")
button_german  = Button(ax_button_german, "German")

button_english.on_clicked(on_english_clicked)
button_german.on_clicked(on_german_clicked)

# -----------------------------------------------------
# 10) On-Close Handler
# -----------------------------------------------------
def on_close_figure(event):
    print("Closing figure and serial port...")
    ser.close()
    sys.exit(0)

fig.canvas.mpl_connect('close_event', on_close_figure)

# -----------------------------------------------------
# 11) Launch Animation
# -----------------------------------------------------
ani = animation.FuncAnimation(
    fig,
    run,
    data_gen,
    blit=False,
    interval=100,
    repeat=False
)

plt.show()
