#!/usr/bin/env python3

import os, sys
import time

	#Input image folder name:
imagefolder = sys.argv[1].replace('"','').replace("'","").rstrip('/')  + "/"
    #Output folder name:
outfolder = "'" + sys.argv[2].replace('"','').replace("'","").rstrip('/') + "/'"
filelist = [files for root, dirs, files in os.walk(imagefolder)][0]

start = time.time()
            
if not os.path.exists(outfolder):
    os.makedirs(outfolder)            


for f in filelist:
    if f[0] != '.':
    	command = "convert '" + imagefolder + f + "' " + outfolder.rstrip("'") + f.replace('.jpeg', '.tif') + "'"
    	print("Converting page", f)
    	os.system(command) 

end = time.time()
    
print("Time elapsed = ",(end-start)/60, "minutes.")