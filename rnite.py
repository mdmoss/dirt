# rnite.py
#
# Matthew Moss
# mdm@cse.unsw.edu.au
# 31/3/2011
#
# Simplifies use of the nite program by automatically launching with the
# directory of this script as the home directpry

#
# Update this with the location of nite.exe and the COM port in use
#
nite = r"C:\Users\Matt\Dropbox\2121\nite.exe"
com_port = "COM4"
#

import os

filepath = os.getcwd()
launch_args = "-l " + com_port + " -f 4 -t 1 -h " + filepath

launch_string = nite + " " + launch_args
os.system(launch_string)
