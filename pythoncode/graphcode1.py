#!/usr/bin/python
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import serial
import serial.tools.list_ports
import threading
import time, sys, math
import kconvert  # conversion module 


current_temp = None

# from multimeter_temp.pyw
def serial_reader():
    global current_temp, ser
    connected = False
    while True:
        if not connected:
            ports = list(serial.tools.list_ports.comports())
            for item in ports:
                try:
                    ser = serial.Serial(item.device, 9600, timeout=0.5)
                    ser.write(b"\x03")  # multimeter request prompt 
                    prompt = ser.readline().strip().decode()
                    if len(prompt) > 1 and prompt[1] == '>':
                        connected = True
                        ser.timeout = 3 

                        ser.write(b"VDC; RATE S; *IDN?\r\n")
                        idn = ser.readline().strip().decode()
                        ser.readline()  
                        ser.write(b"MEAS1?\r\n") 
                        print("Connected to:", item.device)
                        break
                    else:
                        ser.close()
                except Exception as e:
                    pass
            if not connected:
                print("Multimeter not found, trying again in 5 seconds...")
                time.sleep(5)
                continue
        try:
            line_bytes = ser.readline()
            if not line_bytes:
                continue
            line_str = line_bytes.strip().decode()
            print("Serial line:", line_str)
            if line_str == '':
                continue

            # Remove units from the string (e.g., "+0.234E-3 VDC")
            line_clean = line_str.replace("VDC", "").strip()
            try:
                voltage_mV = float(line_clean) * 1000.0
                cj = 22.0  #cold junction temp can adjust 
                temp = round(kconvert.mV_to_C(voltage_mV, cj), 1)
                current_temp = temp
            except Exception as conv_err:
                current_temp = None

            ser.write(b"MEAS1?\r\n")
        except Exception as read_err:
            print("Communication lost:", read_err)
            connected = False
            current_temp = None
            try:
                ser.close()
            except:
                pass
            time.sleep(5)

#serial thread reader 
thread = threading.Thread(target=serial_reader, daemon=True)
thread.start()

xsize = 100  #display window width 

fig = plt.figure()
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(0, 300)  #y axis temp 
ax.set_xlim(0, xsize)
ax.grid()
xdata, ydata = [], []

def data_gen():
    t = 0
    while True:
        temp = current_temp if current_temp is not None else float('nan')
        yield t, temp
        t += 0.5  
        time.sleep(0.5)  # Match the serial update rate.

def run(data):
    t, y = data
    xdata.append(t)
    ydata.append(y)
    
    # Scroll the x-axis as time increases.
    if t > xsize:
        ax.set_xlim(t - xsize, t)
    line.set_data(xdata, ydata)
    
    # color chnaging line 
    if not np.isnan(y) and y >= 100:
        line.set_color('red')
    else:
        line.set_color('blue')
    return line,

def on_close_figure(event):
    sys.exit(0)

fig.canvas.mpl_connect('close_event', on_close_figure)

ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=500, repeat=False)
plt.title("Oven Temperature Over Time (°C)")
plt.xlabel("Time (s)")
plt.ylabel("Temperature (°C)")
plt.show()
