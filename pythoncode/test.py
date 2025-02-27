import time
import sys
import math
import serial
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.colors import hsv_to_rgb
from matplotlib.widgets import Button
from matplotlib.cbook import get_sample_data
from matplotlib.offsetbox import OffsetImage, AnnotationBbox

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

# -----------------------------------------------------
# 2) Language Dictionaries for Labels and Title
#    (Now includes Pig Latin and French)
# -----------------------------------------------------
labels_dict = {
    'english': {
        'title': "Reflow Oven Temperature (°F)",
        'xlabel': "Sample #",
        'ylabel': "Temperature (°F)"
    },
    'german': {
        'title': "Reflow-Ofen Temperatur (°F)",
        'xlabel': "Probe #",
        'ylabel': "Temperatur (°F)"
    },
    'pig_latin': {
        'title': "eflowRay ovenWay emperatureTay (°F)",
        'xlabel': "ampleSay #",
        'ylabel': "emperatureTay (°F)"
    },
    'french': {
        'title': "Température du four à refusion (°F)",
        'xlabel': "Échantillon #",
        'ylabel': "Température (°F)"
    },
}

current_language = 'english'  # Default language is English

# -----------------------------------------------------
# 3) Global Plot Settings & Variables
# -----------------------------------------------------
xsize = 100       # Number of samples to show on the x-axis
time_index = 0
xdata, ydata = [], []

dark_mode = False  # Global toggle for Dark Mode

# Create figure and axis
fig = plt.figure()
ax = fig.add_subplot(111)

# Set up the line object
line, = ax.plot([], [], lw=2)

# Initial boundaries
ax.set_xlim(0, xsize)
ax.set_ylim(32, 100)  # Since we’re in °F, start from 32 °F to ~100 °F

# Apply default language labels
ax.set_xlabel(labels_dict[current_language]['xlabel'])
ax.set_ylabel(labels_dict[current_language]['ylabel'])
ax.set_title(labels_dict[current_language]['title'])

ax.grid(True)

# -------------------------
# 4) Live Temperature Text
#    - top-right corner
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
# 5) Replace person.jpeg with a built-in sample image
#    from Matplotlib (Grace Hopper).
# -----------------------------------------------------
# Attempt to load a sample image as a "person figure"
with get_sample_data("grace_hopper.png") as gh_file:
    person_img = plt.imread(gh_file)

# If loaded from an 8-bit image, scale to [0..1].
if person_img.dtype == np.uint8:
    person_img = person_img.astype(float) / 255.0

# Precompute the inverted version for dark mode
person_img_inverted = 1.0 - person_img

imagebox_light = OffsetImage(person_img, zoom=0.1)
imagebox_dark  = OffsetImage(person_img_inverted, zoom=0.1)

# Create an AnnotationBbox to place the image at the last data point
person_ab = AnnotationBbox(
    imagebox_light,           # start with "light" version
    (0, 0),                   # dummy coords, will update in animation
    xycoords='data',
    frameon=False
)
ax.add_artist(person_ab)

# -----------------------------------------------------
# 6) Data Generator
#    Reads from serial, parses °C, converts to °F
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
                temp_celsius = float(temp_str)
            except ValueError:
                # If conversion fails, assume 0 °C
                temp_celsius = 0

            # Enforce no negative temperatures
            if temp_celsius < 0:
                temp_celsius = 0

            # Convert to Fahrenheit
            temp_f = temp_celsius * 9.0/5.0 + 32.0

            yield time_index, temp_f
            time_index += 1

        time.sleep(0.05)  # Slight delay

# -----------------------------------------------------
# 7) Color Mapping Function for Fahrenheit
#    0 °C -> 32 °F, 280 °C -> 536 °F
#    So we map 32..536 => hue from 2/3..0
# -----------------------------------------------------
def temperature_to_color_f(temp_f):
    """
    Maps temp in [32..536] °F to a hue in [2/3..0].
    32 °F => pure blue, 536 °F => pure red.
    """
    t_min, t_max = 32.0, 536.0
    t_clamped = max(t_min, min(t_max, temp_f))

    fraction = (t_clamped - t_min) / (t_max - t_min)  # in [0..1]
    # Hue goes from 0.6667 (blue) down to 0 (red)
    hue = 0.6667 * (1.0 - fraction)

    r, g, b = hsv_to_rgb((hue, 1.0, 1.0))
    return (r, g, b)

# -----------------------------------------------------
# 8) Animation Update
# -----------------------------------------------------
def run(update_data):
    t, temp_f = update_data
    xdata.append(t)
    ydata.append(temp_f)

    # Scroll the x-axis if needed
    if t > xsize:
        ax.set_xlim(t - xsize, t)

    # Adjust y-axis if the temperature goes outside current range
    margin = 5
    y_min, y_max = ax.get_ylim()
    if temp_f > (y_max - margin):
        ax.set_ylim(y_min, temp_f + margin)
    elif temp_f < y_min + margin and temp_f < y_max:
        # If we want to shrink dynamically, do so carefully:
        new_min = max(0, temp_f - margin)
        ax.set_ylim(new_min, y_max)

    # Update the line data
    line.set_data(xdata, ydata)

    # Set color based on temperature
    line_color = temperature_to_color_f(temp_f)

    # If in dark mode, invert the color for the line
    if dark_mode:
        inv_line_color = (1.0 - line_color[0],
                          1.0 - line_color[1],
                          1.0 - line_color[2])
        line.set_color(inv_line_color)
    else:
        line.set_color(line_color)

    # Update the live temperature reading in the top-right
    temp_text.set_text(f"{temp_f:.2f} °F")

    # Also set text color
    if dark_mode:
        # Invert again
        text_color = (1.0 - line_color[0],
                      1.0 - line_color[1],
                      1.0 - line_color[2])
    else:
        text_color = line_color
    temp_text.set_color(text_color)

    # Update the person image position to the last point
    person_ab.xy = (t, temp_f)

    # Use inverted image in dark mode, normal image otherwise
    if dark_mode:
        person_ab.image = imagebox_dark
    else:
        person_ab.image = imagebox_light

    return line, temp_text, person_ab

# -----------------------------------------------------
# 9) Language Switch Functions
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

def on_piglatin_clicked(event):
    set_language('pig_latin')

def on_french_clicked(event):
    set_language('french')

# -----------------------------------------------------
# 10) Dark Mode Toggle
# -----------------------------------------------------
def toggle_dark_mode(event):
    global dark_mode
    dark_mode = not dark_mode

    if dark_mode:
        # Invert figure & axes background
        fig.patch.set_facecolor("black")
        ax.set_facecolor("black")

        # Invert grid lines (white)
        ax.grid(color="white")

        # Invert tick labels
        ax.tick_params(axis='x', colors='white')
        ax.tick_params(axis='y', colors='white')

        # Invert title and axis label colors
        ax.title.set_color("white")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")

    else:
        # Revert to a light background
        fig.patch.set_facecolor("white")
        ax.set_facecolor("white")

        # Dark grid lines
        ax.grid(color="black")

        # Dark tick labels
        ax.tick_params(axis='x', colors='black')
        ax.tick_params(axis='y', colors='black')

        # Dark text for title and labels
        ax.title.set_color("black")
        ax.xaxis.label.set_color("black")
        ax.yaxis.label.set_color("black")

    fig.canvas.draw_idle()

# -----------------------------------------------------
# 11) Add Buttons to the Figure
# -----------------------------------------------------
button_width = 0.12
button_height = 0.05

# English
ax_button_english = plt.axes([0.05, 0.05, button_width, button_height])
button_english = Button(ax_button_english, "English")
button_english.on_clicked(on_english_clicked)

# German
ax_button_german  = plt.axes([0.18, 0.05, button_width, button_height])
button_german  = Button(ax_button_german, "German")
button_german.on_clicked(on_german_clicked)

# Pig Latin
ax_button_piglatin = plt.axes([0.31, 0.05, button_width, button_height])
button_piglatin = Button(ax_button_piglatin, "PigLatin")
button_piglatin.on_clicked(on_piglatin_clicked)

# French
ax_button_french = plt.axes([0.44, 0.05, button_width, button_height])
button_french  = Button(ax_button_french, "French")
button_french.on_clicked(on_french_clicked)

# Dark Mode
ax_button_dark = plt.axes([0.57, 0.05, button_width, button_height])
button_dark = Button(ax_button_dark, "Dark Mode")
button_dark.on_clicked(toggle_dark_mode)

# -----------------------------------------------------
# 12) On-Close Handler
# -----------------------------------------------------
def on_close_figure(event):
    print("Closing figure and serial port...")
    ser.close()
    sys.exit(0)

fig.canvas.mpl_connect('close_event', on_close_figure)

# -----------------------------------------------------
# 13) Launch Animation
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
