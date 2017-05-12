#!/usr/bin/env python3

import os, sys
import time

imagefolder = sys.argv[1].replace('"','').replace("'","").rstrip('/') + '/'
    #Parent folder for output folder:
outparent = sys.argv[2].replace('"','').replace("'","").rstrip('/') + '/'
    #Output folder name:
outfolder = sys.argv[3].replace('"','').replace("'","").rstrip('/') + '/'
filelist = [files for root, dirs, files in os.walk(imagefolder)][0]

start = time.time()

def runTess(file, out):
    try:
        command = ' '.join(["tesseract", "'"+imagefolder + file+"'", "'"+out + file.replace('.tif', ''), "-l", "eng+eng7", "hocr", "whitelist"])
        os.system(command)
    except:
        print('Processing failed on ', file)
            
if not os.path.exists(outparent + outfolder):
    os.makedirs(outparent + outfolder)            

for tif in filelist[1:]:
    if tif[0] != '.':
        runTess(tif, outparent + outfolder)

end = time.time()
    
print("Time elapsed = ",(end-start)/60, "minutes.")