#!/usr/bin/env python3

import os, sys
import time

imagefolder = sys.argv[1].replace('"','').replace("'","").rstrip('/') + '/'
    #Output folder name:
outfolder = sys.argv[2].replace('"','').replace("'","").rstrip('/') + '/'
	#Training data ISO language name (e.g., eng1):
isolang = sys.argv[3]
filelist = [files for root, dirs, files in os.walk(imagefolder)][0]

start = time.time()

def runTess(file, out):
    try:
        command = ' '.join(["tesseract", "'"+imagefolder + file+"'", "'"+out + file.replace(".tif", "'"), "-l", "eng+" + isolang, " hocr", "whitelist"])
        #print(command)
        os.system(command)
    except:
        print('Processing failed on ', file)
            
if not os.path.exists(outfolder):
    os.makedirs(outfolder)            

for tif in filelist:
    if tif[0] != '.' and tif.split('.')[-1] == "tif":
        runTess(tif, outfolder)

end = time.time()
    
print("Time elapsed = ",(end-start)/60, "minutes.")