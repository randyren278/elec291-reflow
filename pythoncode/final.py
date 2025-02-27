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
    port='COM3',            # Change to your actual COM port
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1.0
)
print("Connected to", ser.name)

# -----------------------------------------------------
# 2) Language Dictionaries for Labels and Title
#    (English, German, Pig Latin, French)
# -----------------------------------------------------
labels_dict = {
    'english': {
        'title': "Reflow Oven Temperature",
        'xlabel': "Sample #",
        'ylabel': "Temperature"
    },
    'german': {
        'title': "Reflow-Ofen Temperatur",
        'xlabel': "Probe #",
        'ylabel': "Temperatur"
    },
    'piglatin': {
        'title': "eflow-Ray ven-Oay emperature-Tay",
        'xlabel': "ample-Say #",
        'ylabel': "emperature-Tay"
    },
    'french': {
        'title': "Température du four à refusion",
        'xlabel': "Échantillon #",
        'ylabel': "Température"
    }
}

# Current settings
current_language = 'english'  # Default language
current_unit = 'C'            # 'C' or 'F'
dark_mode_active = False      # True = dark mode on, False = off

# -----------------------------------------------------
# 3) Global Plot Settings
# -----------------------------------------------------
xsize = 100       # Number of samples to show on the x-axis
time_index = 0
xdata = []
ydata_c = []      # We'll store raw Celsius data, then convert on the fly if needed

# Create the main figure and axis
fig = plt.figure()
ax = fig.add_subplot(111)

# Create the line object for temperature data
line, = ax.plot([], [], lw=2)

# Initial boundaries
ax.set_xlim(0, xsize)
ax.set_ylim(0, 50)

# -------------------------
# 4) Live Temperature Text
#    (must be defined before apply_theme!)
# -------------------------
temp_text = ax.text(
    0.95,
    0.95,
    "",           # will be updated in animation
    transform=ax.transAxes,
    ha='right',
    va='top',
    fontsize=12,
    color='blue'  # default in light mode
)

# -----------------------------------------------------
# 5) Functions to Apply Labels & Themes
# -----------------------------------------------------
def apply_labels():
    """
    Updates the title, x-label, and y-label 
    based on the current language and the chosen unit.
    """
    title_text = labels_dict[current_language]['title']
    xlabel_text = labels_dict[current_language]['xlabel']
    ylabel_text = labels_dict[current_language]['ylabel']
    
    ax.set_xlabel(xlabel_text)
    # Append the current unit to the Y label, e.g. "Temperature (°C)" or "(°F)"
    ax.set_ylabel(f"{ylabel_text} (°{current_unit})")
    ax.set_title(title_text)
    fig.canvas.draw_idle()


def apply_theme():
    """
    Switches between light mode and dark mode 
    by inverting background, text, and grid colors.
    """
    global dark_mode_active
    if dark_mode_active:
        # DARK MODE
        fig.patch.set_facecolor("black")
        ax.set_facecolor("black")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")
        ax.title.set_color("white")
        ax.tick_params(axis='x', colors='white')
        ax.tick_params(axis='y', colors='white')
        ax.grid(color="white", linestyle=":", linewidth=0.5)
        temp_text.set_color("white")  # top-right text color in dark mode
    else:
        # LIGHT MODE
        fig.patch.set_facecolor("white")
        ax.set_facecolor("white")
        ax.xaxis.label.set_color("black")
        ax.yaxis.label.set_color("black")
        ax.title.set_color("black")
        ax.tick_params(axis='x', colors='black')
        ax.tick_params(axis='y', colors='black')
        ax.grid(color="black", linestyle=":", linewidth=0.5)
        temp_text.set_color("blue")   # top-right text color in light mode

    fig.canvas.draw_idle()

# Apply initial labels
apply_labels()
ax.grid(True)
# Apply initial theme
apply_theme()

# -----------------------------------------------------
# 6) Data Generator
# -----------------------------------------------------
def data_gen():
    """
    Continuously reads lines from the serial port. 
    Each line is expected to be a numeric value in Celsius (optionally ending with 'C'). 
    Negative temps are clamped to 0.
    """
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
                temperature_value_c = float(temp_str)  # raw reading in Celsius
            except ValueError:
                temperature_value_c = 0

            # Enforce no negative temperatures
            if temperature_value_c < 0:
                temperature_value_c = 0

            yield time_index, temperature_value_c
            time_index += 1

        # Slight delay to avoid busy-wait
        time.sleep(0.05)

# -----------------------------------------------------
# 7) Color Mapping Functions
# -----------------------------------------------------
def temperature_to_color(temp_c):
    """
    Maps temp in [0..280] °C to a hue in [2/3..0].
    0 => pure blue, 280 => pure red.
    """
    # Clamp temperature to [0, 280]
    t_clamped = max(0, min(280, temp_c))

    fraction = t_clamped / 280.0
    hue = 0.6667 * (1.0 - fraction)  # 0.6667 (blue) down to 0 (red)

    r, g, b = hsv_to_rgb((hue, 1.0, 1.0))
    return (r, g, b)

def maybe_invert_color(rgb_tuple):
    """
    If dark mode is active, invert the color 
    to ensure the line is visible against a dark background.
    """
    if dark_mode_active:
        r, g, b = rgb_tuple
        return (1.0 - r, 1.0 - g, 1.0 - b)
    else:
        return rgb_tuple

# -----------------------------------------------------
# 8) Animation Update
# -----------------------------------------------------
def run(update_data):
    """
    Called repeatedly by FuncAnimation to update the plot.
    update_data = (time_index, temperature_celsius)
    """
    t, temp_c = update_data

    # Store raw Celsius data
    xdata.append(t)
    ydata_c.append(temp_c)

    # Convert to Fahrenheit if needed
    if current_unit == 'F':
        # Fahrenheit
        yvals = [(yc * 9.0 / 5.0 + 32.0) for yc in ydata_c]
        temp_display = temp_c * 9.0 / 5.0 + 32.0
    else:
        # Celsius
        yvals = ydata_c
        temp_display = temp_c

    line.set_data(xdata, yvals)

    # Scroll the x-axis if needed
    # Force the left side to stay at 0, 
# and expand the right side to the current time (t).
    if t <= 0:
        ax.set_xlim(0, 100)     # Avoids a 0-width axis when t=0
    else:
        ax.set_xlim(0, t + 2) # or just ax.set_xlim(0, t)


    # remove teh scroll 
    # Adjust y-axis if we exceed the current limit
    margin = 10
    y_min, y_max = ax.get_ylim()
    if temp_display > (y_max - margin):
        ax.set_ylim(y_min, temp_display + margin)

    # Determine color from the Celsius value
    color_c = temperature_to_color(temp_c)
    color_c = maybe_invert_color(color_c)
    line.set_color(color_c)

    # Update the live temperature reading (top-right)
    temp_text_str = f"{temp_display:.2f} °{current_unit}"
    temp_text.set_text(temp_text_str)

    return line, temp_text

# -----------------------------------------------------
# 9) Language Switch Functions
# -----------------------------------------------------
def set_language(lang):
    global current_language
    current_language = lang
    apply_labels()

def on_english_clicked(event):
    set_language('english')

def on_german_clicked(event):
    set_language('german')

def on_piglatin_clicked(event):
    set_language('piglatin')

def on_french_clicked(event):
    set_language('french')

# -----------------------------------------------------
# 10) Toggle Units (C <-> F)
# -----------------------------------------------------
def toggle_units(event):
    global current_unit
    current_unit = 'F' if current_unit == 'C' else 'C'
    apply_labels()  # refresh the axis labels

# -----------------------------------------------------
# 11) Toggle Dark Mode
# -----------------------------------------------------
def toggle_dark_mode(event):
    global dark_mode_active
    dark_mode_active = not dark_mode_active
    apply_theme()

# -----------------------------------------------------
# 12) Create Buttons on the Figure
# -----------------------------------------------------
button_width = 0.1
button_height = 0.05

# Language buttons
ax_button_english  = plt.axes([0.05, 0.05, button_width, button_height])
ax_button_german   = plt.axes([0.17, 0.05, button_width, button_height])
ax_button_piglatin = plt.axes([0.29, 0.05, button_width, button_height])
ax_button_french   = plt.axes([0.41, 0.05, button_width, button_height])

button_english  = Button(ax_button_english, "English")
button_german   = Button(ax_button_german,  "German")
button_piglatin = Button(ax_button_piglatin,"Pig Latin")
button_french   = Button(ax_button_french,  "French")

button_english.on_clicked(on_english_clicked)
button_german.on_clicked(on_german_clicked)
button_piglatin.on_clicked(on_piglatin_clicked)
button_french.on_clicked(on_french_clicked)

# Button to toggle °C / °F
ax_button_units = plt.axes([0.60, 0.05, button_width, button_height])
button_units    = Button(ax_button_units, "°C/°F")
button_units.on_clicked(toggle_units)

# Button for Dark Mode
ax_button_dark = plt.axes([0.72, 0.05, button_width, button_height])
button_dark    = Button(ax_button_dark, "Dark Mode")
button_dark.on_clicked(toggle_dark_mode)

# -----------------------------------------------------
# 13) On-Close Handler
# -----------------------------------------------------
def on_close_figure(event):
    print("Closing figure and serial port...")
    ser.close()
    sys.exit(0)

fig.canvas.mpl_connect('close_event', on_close_figure)

# -----------------------------------------------------
# 14) Launch Animation
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
