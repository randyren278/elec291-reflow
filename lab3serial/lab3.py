import time
import sys
import math
import serial
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.colors import hsv_to_rgb  # For generating rainbow colors
import random




ser=serial.Serial(
    port='COM3',
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS,
    timeout=1.0
)

print("Connected to", ser.name)

#strip chart safter serial port definiton 

xsize = 100
time_index = 0
xdata, ydata = [], []
previous_temperature= None

annotations = []

fig = plt.figure()
ax = fig.add_subplot(111)

line, = ax.plot([], [], lw=2)

#boundaries 

ax.set_xlim(0, xsize)
ax.set_ylim(0, 50)
ax.grid(True)
ax.set_xlabel("Sample #")
ax.set_ylabel("Temperature in Degrees (C)")

#get data 

def data_gen():
    global time_index, previous_temperature
    while True:
        line_in = ser.readline().decode("utf-8").strip()
        if line_in:
            try:
                if line_in.endswith('C'):
                    temp_str=line_in[:-1]
                else:
                    temp_str=line_in
                temperature_value=float(temp_str)
            except ValueError:
                temperature_value=0


            if temperature_value<0:
                temperature_value=0

                #no negative tmperatures 

            yield time_index, temperature_value
            previous_temperature=temperature_value
            time_index += 1

        time.sleep(0.05)

#YYAYYA ANIMATION

def run(update_data):
    global previous_temperature
    t,y=update_data

    xdata.append(t)
    ydata.append(y)

    # scroll the axis if temperature is too hot or plot runs for long enoguh 

    if t>xsize:
        ax.set_xlim(t-xsize, t)

    margin=5
    y_min,y_max=ax.get_ylim()
    if y> (y_max-margin):
        ax.set_ylim(y_min,y+margin)

    #update line data 

    line.set_data(xdata,ydata)

    # make the line a rainbow 
# ensures that the t value stays between 0-99 for color stuff 
    hue= (t%100)/100 #secod value is cycle time can speed up animation 
    color=hsv_to_rgb((hue,1,1))
    line.set_color(color)

    # add annotation each time temperature gets warmer in a random spot 

    if previous_temperature is not None and y> previous_temperature:

        x_position=random.uniform(t-10,t)

        y_position=random.uniform(y_min,y_max)

        annotation = ax.text(x_position,y_position,"It's getting hot in here!", fontsize=10,color='red',alpha=1)
        
        annotations.append((annotation,time_index))

    # fade out on annimations 

    fade_time=10

    for ann, ann_time in annotations [:]:
        if t-ann_time>fade_time:
            ann.set_alpha(max(0,ann.get_alpha()-0.1))
            if ann.get_alpha()<=0:
                ann.remove()
                annotations.remove((ann,ann_time))

    return line,

def on_close_figure(event):
    print("Closing figure and serial port...")
    ser.close()
    sys.exit(0)

fig.canvas.mpl_connect('close_event', on_close_figure)

#animation launch 

ani=animation.FuncAnimation(
    fig,
    run,
    data_gen,
    blit=False,
    interval=100,
    repeat=False
)

plt.show()