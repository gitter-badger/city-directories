#!/usr/bin/env python3

import os, sys
import re

folder = sys.argv[1].replace('"','').replace("'","").rstrip('/') + '/'
if len(sys.argv[2:]):
	args = sys.argv[2:]
else:
	args = False
fullfilelist = [files for root, dirs, files in os.walk(folder)][0]
filelist = [i for i in fullfilelist if not i.startswith('.')]
filelist = [l for l in filelist if not re.search(r'font_properties|traineddata|shapetable|unicharset \
                                                 |pffmtable|normproto|inttemp|\.tr$', l)]
dawglist = [j for j in filelist if re.search('\.txt', j)]
filelist = sorted([k for k in filelist if not k in dawglist])

    #Builder for the .tr files        
def buildtr(pair):
    for p in pair:
        try:
            command = "tesseract " + p[1] + " " + p[1].replace('.tif', '') + " nobatch box.train"
            #print(command + '\n')
            os.system(command)
        except:
            print("Processing failed on building a set of .tr files for ", p[1])
            
    #Builder for unicharset and performs shapetable, mftraining, cntraining
def buildfiles(flist):
    flist = [i.replace('.tif', '').replace('.box', '') for i in flist]
    flist = list(set(flist))
    commands = []
    commands.append("unicharset_extractor " + ' '.join([l+'.box' for l in flist]))
    commands.append("shapeclustering -F font_properties -U unicharset " + ' '.join([l+'.tr' for l in flist]))
    commands.append("mftraining -F font_properties -U unicharset -O " + flist[0].split('.')[0] + ".unicharset " +  
                 ' '.join([l+'.tr' for l in flist]))
    commands.append("cntraining " + ' '.join([l+'.tr' for l in flist]))
    for cmd in commands:
        try:
            #print(cmd + '\n')
            os.system(cmd)
        except:
            print("Processing failed on ", cmd.split()[0])

    #Dawg file builder; -kind- can be "word-dawg" or "freq-dawg"
def builddawg(dfile, kind, prepend):
    command = "wordlist2dawg " + dfile + " " + prepend + "." + kind + " " + prepend + ".unicharset"
    #print(command)
    os.system(command)

    #Builder for fontproperties file
def fontproperties(flist):
    flist = [i.replace('.tif', '').replace('.box', '').split('.')[1] for i in flist]
    flist = list(set(flist))
    fprop = ""
    for font in flist:
        fprop = fprop + font.split('.')[0]
        if font[-1] == "i":
            fprop = fprop + " 1 0 0 1 0\n"
        else:
            fprop = fprop + " 0 0 0 1 0\n"
    with open(folder + "font_properties", 'w', encoding='utf-8') as outfile:
        outfile.write(fprop)
        outfile.close()
        print("font_properties files created)")
    
def main():    
    if len(filelist) % 2 != 0:
        print("File group error. Incomplete box/tif pair")
    else:
    	os.chdir(os.path.dirname(folder))
    	langprepend = filelist[0].split('.')[0]
    	pairlist = [tuple(filelist[i:i+2]) for i in range(0, len(filelist), 2)]
    	buildtr(pairlist)
    	fontproperties(filelist)
    	buildfiles(filelist)
    	if args:
    		for arg in args:
    			builddawg(arg, "word-dawg", langprepend)
    	if langprepend + ".inttemp" not in fullfilelist:
    		list(map(os.system, [n + langprepend + "." + n.split()[1]  for n in ["mv inttemp ", "mv normproto ", "mv pffmtable ", "mv shapetable "]]))
    	else:
    		list(map(os.system, [n + langprepend + "." + n.split()[1] + " -f"  for n in ["mv inttemp ", "mv normproto ", "mv pffmtable ", "mv shapetable "]]))
    	os.system("combine_tessdata " + langprepend + ".")
    	#print("combine_tessdata " + langprepend + ".")
    	print("Training data packed!")

main()