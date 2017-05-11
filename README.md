# City Directories

- Which OCR engine?
  - How to train Tesseract 4?
- Field detection: CRF or something similar? Or just regular expressions?
- Create dictionaries of names, professions and street
  - We can use this dataset for list of street names: http://spacetime.nypl.org/#data-nyc-streets

## Samples

I've uploaded some sample pages from city directories to S3, as well as one complete volume:

- [1849](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/samples/1849.zip) (sample, 270MB)
- [1854](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/complete/1854-55.zip) (complete, 11GB)
- [1861](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/samples/1861.zip) (sample, 315MB)
- [1872](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/samples/1872.zip) (sample, 340MB)
- [1890](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/samples/1890.zip) (sample, 150MB)
- [1909](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/samples/1909-1910.zip) (sample, 200MB)
- [1923](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/samples/1923.zip) (sample, 192MB)

## Tools

We are using ocropy as our OCR engine, see https://github.com/tmbdev/ocropy. The documentation is not too good, and installing isn't very easy, I've created a GitHub repo to set up the tools, and to run ocropy on a directory with city directory pages: https://github.com/nypl-spacetime/ocr-scripts

I've written a Python module to detect columns in OCR output: https://github.com/nypl-spacetime/hocr-detect-columns

There are alternatives, Tesseract is one of them, I think the documentation is much better, and they've just released a new version that I have not tried yet: https://github.com/tesseract-ocr/tesseract/wiki/4.0-with-LSTM. I would love to experiment using Tesseract, maybe it's time to stop using ocropy.

I've also uploaded the results of running OCR + processing ocropy's output to S3:

- [1854](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/data/1854-55.zip) (330MB)
- [1874](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/data/1874-75.zip) (500MB)
- [1883](http://spacetime-nypl-org.s3.amazonaws.com/city-directories/data/1883-84.zip) (600MB)

These files contain small bounding box PNGs which we use to correct OCR mistakes and re-train the model. And these files also contain lines.ndjson, with OCR output.

I've experimented with using conditional random fields to extract the data from the OCR results: see https://github.com/nypl-spacetime/run-crf and https://github.com/nypl-spacetime/label-fields. Using this tool, me and my colleagues labeled fields in many OCR output lines, the run-crf tool reads those labels (from API: http://brick-by-brick.herokuapp.com/tasks/label-fields/submissions/all.ndjson), and uses CRF++ to train a CRF model. Works pretty well, but maybe simple regex works better... :)

For information about Space/Time data model, see https://GitHub.com/nypl-spacetime/ontology

### Resources

 - [List of occupations from IPUMS](https://github.com/nmwolf/wilson52-training-lines/blob/master/ipums-occ-list.txt)
 - [List of occupations from Wilson Directory](https://github.com/nmwolf/wilson52-training-lines/blob/master/wilson-occ-list.txt)
 - [List of last names from 1852 Wilson directory](https://github.com/nmwolf/wilson52-training-lines/blob/master/lastnames-lowercase)
 - [List of first names from 1852 Wilson directory](https://github.com/nmwolf/wilson52-training-lines/blob/master/firstnames-lowercase)
 - [List of streetname abbreviation pairs with standard version](https://github.com/nmwolf/wilson52-training-lines/blob/master/streetname-abbr-pairs.txt)

## Tesseract 4

### Installing

https://github.com/tesseract-ocr/tesseract/wiki/Compiling#macos-with-homebrew

### Running on single page

    tesseract --oem 2 /path/to/page1.jpg page1.hocr hocr

### Training

#### Create boxfile

Create boxfile from image:

    tesseract 0412_56753997g.jpg batch.nochop makebox

#### Training from scratch

- [Training data from Wilson directory with box file at word level](https://github.com/nypl-spacetime/city-directories/tree/master/wilson-training-1852)

Wiki: https://github.com/tesseract-ocr/tesseract/wiki/TrainingTesseract-4.00#training-from-scratch

Example command from wiki:

    lstmtraining -U ~/tesstutorial/engtrain/eng.unicharset \
      --script_dir ../langdata --debug_interval 100 \
      --net_spec '[1,36,0,1 Ct5,5,16 Mp3,3 Lfys64 Lfx128 Lrx128 Lfx256 O1c105]' \
      --model_output ~/tesstutorial/engoutput/base \
      --train_listfile ~/tesstutorial/engtrain/eng.training_files.txt \
      --eval_listfile ~/tesstutorial/engeval/eng.training_files.txt \
      --max_iterations 5000 &>~/tesstutorial/engoutput/basetrain.log

Now, try this ourselves:

    cd wilson-training-1852
    lstmtraining -U ../langdata/Latin.unicharset \
--script_dir ????
    --debug_interval 100 \
    --net_spec '[1,36,0,1 Ct5,5,16 Mp3,3 Lfys64 Lfx128 Lrx128 Lfx256 O1c105]' \
    --model_output ../engoutput/base
--train_listfile ???
--eval_listfile  ???
    --max_iterations 5000

