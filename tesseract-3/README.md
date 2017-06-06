# OCR with Tesseract 3.5

## Required

Install Tesseract v.3.05 and ImageMagick

```brew install tesseract```
```brew install imagemagick```

## Quick Scripts

To pack up and create a traineddata file from a folder containing box/tif training files and a wordlist for training dictionary:

```python training-packer.py path-to-folder word-list-file.txt```

Place the resulting traineddata file (located in same folder as box/tif pairs), in Tesseract's ```/usr/local/share/tessdata/``` folder.

To preprocess the folder of .tif directory pages:

```python im-processor.py path-to-ImageMagick-textcleaner-script path-to-images/ path-to-output-folder/```

If the folder contains .jpeg or .jpg rather than .tif, ```im-processor.py``` will use ImageMagick to convert them to tifs first before preprocessing them.

To run Tesseract 3.5 on the processed images:

```python directory-tess3.py path-to-images/ path-to-output-folder/ trainingdata-iso-filename```

The ```trainingdata-iso-filename``` will be the name of the trainning data language file (e.g. a variation on "eng") that has been placed in the tessdata folder (see below).

## Details: Combining Training + In-Built Patterns

### Building Training Data

The process below utilizes a combination of Tesseract's standard English training data and additional fonts extracted from city directories.

Building the training files can be done by following the tutorial [here](http://www.resolveradiologic.com/blog/2013/01/15/training-tesseract/). Start by making a few box/tif pairs, selecting useful pages from the directories that contain characters that prove problematic (especially H, h, and ½; pages with italics are also helpful). For directories, it is useful to build standard and italic font training files. Create a language name, derived from 'eng' the ISO 639-2 for English, as a prefix. Do not use 'eng' so as to differentiate the training from the in-built Tesseract eng training data.

To make box/tif pairs for a new English-language font for the 1849 directory, non-italic fonts only:

```tesseract eng2.dir1849.exp0.tif eng2.dir1849.exp0 nobatch box.train```

And for a planned italics-only example (add an i to 1849):

```tesseract eng2.dir1849i.exp0.tif eng2.dir1849i.exp0 nobatch box.train```

Run this for every page wanted for training data, changing the exp integer for each separate pair, i.e.:

```tesseract eng2.dir1849.exp1.tif eng2.dir1849i.exp1 nobatch box.train 
tesseract eng2.dir1849.exp2.tif eng2.dir1849.exp2 nobatch box.train 
tesseract eng2.dir1849i.exp1.tif eng2.dir1849i.exp1 nobatch box.train
...
```
Next, correct the generated .box files using this Python utility script. Delete any lines in the italics training file that are not italics.

### Training

Run this line again for every box/tif pair to generate the .tr files:

```tesseract eng2.dir1849.exp0.tif eng2.dir1849.exp0 nobatch box.train  
tesseract eng2.dir1849.exp1.tif eng2.dir1849.exp1 nobatch box.train  
tesseract eng2.dir1849i.exp0.tif eng2.dir1849i.exp0 nobatch box.train
...
```
etc.

Extract unicharset file. In one line:

```unicharset_extractor eng2.dir1849.exp0.box  eng2.dir1849.exp1.box  eng2.dir1849.exp2.box  eng2.dir1849i.exp0.box  eng2.dir1849i.exp1.box```

Create the ```font_properties``` file as per [guidelines here](https://github.com/tesseract-ocr/tesseract/wiki/Training-Tesseract#the-font_properties-file) with, for example, two lines, one for the standard font and one for the italic font. Make sure the font name listed in the file is dir1849, dir1849i, etc. to match the font name in the box/tif files. Enter the appropriate 1/0 for font type.

Perform the shapeclustering, mftraining, and cntraining steps on all files, in one line:

```shapeclustering -F font_properties -U unicharset eng2.dir1849.exp0.tr eng2.dir1849i.exp0.tr```

```mftraining -F font_properties -U unicharset -O eng2.unicharset eng2.dir1849.exp0.tr eng2.dir1849i.exp0.tr```

```cntraining eng2.dir1849.exp0.tr eng2.dir1849i.exp0.tr```


At this stage a ```word-dawg``` list (i.e. a dictionary of useful words can be made). Prep the word list (similarly, for frequent words, a frequent word list) as a .txt file, each word on one line, with \n line ending. Run, as per Tesseract tutorial:

```wordlist2dawg frequent_words_list eng2.freq-dawg eng2.unicharset
wordlist2dawg words_list eng2.word-dawg eng2.unicharset
```
Make sure this dawg file is in same directory with .tr and unicharset files. Prefix inttemp, normproto, pffmtable, and shapetable with language name:

```
mv inttemp eng2.inttemp
mv normproto eng2.normproto
mv pffmtable eng2.pffmtable
mv shapetable eng2.shapetable
```
Lastly, package everything up into a traineddata file:

```combine_tessdata eng2.```

Place this file in Tesseract's ```tessdata``` folder, located at ```/usr/local/share/tessdata/```

In that same ```tessdata``` folder, we want to add a whitelist to the config folder with a list of city-directory-specific characters to restrict the OCR recognition to. Create a textfile called ```whitelist``` and add this line:

```tessedit_char_whitelist abcdefghijklmnopqrstuvwxyzABDCDEFGHIJKLMNOPQRSTUVWXYZ*&'"().,½-0123456789```

### Running the OCR

For each page we preprocess the images with ImageMagick before applying Tesseract. For every file, with the ImageMagick scrip [textcleaner](http://www.fmwconcepts.com/imagemagick/textcleaner/index.php) installed in a directory:

```bash path-to/textcleaner -g -e none -f 25 -o 10 -T input.tif output-processed.tif```

Lastly, Tesseract using both in-built (eng) and new patterns (eng2):

```tesseract input-file.tif output-file.hocr -l eng+eng2 hocr whitelist```

Done.

