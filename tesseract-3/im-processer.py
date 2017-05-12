#!/usr/bin/env python3

import os, sys
import time

cleanerpath = sys.argv[1].replace('"','').replace("'","")
imagefolder = sys.argv[2].replace('"','').replace("'","").rstrip('/') + '/'
    #Parent folder for output folder:
outparent = sys.argv[3].replace('"','').replace("'","").rstrip('/') + '/'
    #Output folder name:
outfolder = sys.argv[4].replace('"','').replace("'","").rstrip('/') + '/'
filelist = [files for root, dirs, files in os.walk(imagefolder)][0]

start = time.time()

def runIM(file, out):
    try:
        command = ' '.join(["bash", cleanerpath, "-g", "-e none", "-f 25", "-o 10", "-T -b white", 
                   "'"+imagefolder + file+"'", "'"+out + file.replace('.tif','') + "-processed.tif'"])
        os.system(command)
    except:
        print('Preprocessing failed on ', file)
            
if not os.path.exists(outparent + outfolder):
    os.makedirs(outparent + outfolder)            


for tif in filelist:
    if tif[0] != '.':
        runIM(tif, outparent + outfolder)

end = time.time()
    
print("Time elapsed = ",(end-start)/60, "minutes.")