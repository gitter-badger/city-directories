## sgb334@nyu.edu

####### README #########
########################

## 1. Load all of the functions into memory
## 2. Populate a list of occupations (i.e. jobs = [])
## 3. Parse NDJSON file, line by line, into a list
## 4. Tokenize each OCR line-record with parse_line_elements(line)
## 5. Perform category_parsing(line, jobs); algorithm votes for most
##      likely class of object
## 6. Time to count up all of the votes –– call classify_decisions()
##      to determine the winning class for each token
## 7. Take your list of labeled tokens and assemble them into an
##      actual record, using consolidate_classes()

## TODO: Add function for merging subsequent address tokens (4/26/17)
## TODO: Actually organize these functions into something coherent... (4/26/17)

#### Useful Procedures ####

require 'JSON'
require 'CSV'
lines = []
File.open('/Users/stephen/Downloads/1854-55/lines.ndjson').each do |line|
  lines << JSON.parse(line)
end

jobs = File.read('/Users/stephen/Documents/nypl-directories/occupations_data/ipums-occ-list.txt').split("\n")
jobs.concat(File.read('/Users/stephen/Documents/nypl-directories/occupations_data/wilson-occ-list.txt').split("\n"))

parsed_lines = lines.map { |line| [line, parse_line_elements(line)] }

lines_and_decisions = []

parsed_lines[20000..20200].each_with_index do |line, index|
  lines_and_decisions << [line[0], category_parsing(line[1], jobs)]
  if index % 100 == 0
    puts "#{index / parsed_lines.count}"
  end
end

lines_and_classes = lines_and_decisions.map { |ent| [ent[0], classify_decisions(ent[1])] }

tester = lines_and_classes.map { |ent| consolidate_classes(ent[0], ent[1]) }

File.open("/Users/stephen/Documents/nypl-directories/sample_decisions_classes.json", "wb") do |f|
  f.write(JSON.pretty_generate(tester))
end

#### End Procedures ####


## Turns list of classes into a merged record
def consolidate_classes(original_line, list_of_classes)
  record = {
      :original_ocr => original_line,
      :attributes_parsed => {
          :subject =>
              [
                  #{:value => "Curran Sarah", :type => "primary", :occupation => "widowed"},
                  #{:value => "Richard", :type => "widower of primary"}
              ],
          :location =>
              [
                  #{:value => "7 Sixth", :position => "rear", :type => "home"}
              ]
      }
  }

  list_of_classes.each_with_index do |classed_token, index|
    parsed_class = classed_token[1][0]
    value = classed_token[0]
    if index == 0 && parsed_class == :name_component
      record[:attributes_parsed][:subject] << {:value => value, :type => 'primary'}
    end
    if index > 0
      case parsed_class
        when :job_component
          unless record[:attributes_parsed][:subject].count < 1
            record[:attributes_parsed][:subject][0][:occupation] = value
          end
        when :predicate
          case value
            when "wid"
              unless record[:attributes_parsed][:subject].count < 1
                record[:attributes_parsed][:subject][0][:occupation] = 'widow'
              end
              attach_to_next(list_of_classes, index, :name_component, [{:type => 'deceased spouse of primary'}])
            when "h"
              attach_to_next(list_of_classes, index, :address_component, [{:type => 'home'}])
            when "r"
              attach_to_next(list_of_classes, index, :address_component, [{:position => 'rear'}])
            else
          end
        ## inner case
        when :address_component
          loc = {:value => value}
          classed_token[2..-1].each do |xtra_attr| ## add in any additional attributes from predicates
            xtra_attr.each do |k, v|
              loc[k] = v
            end
          end
          record[:attributes_parsed][:location] << loc
        else
      end
    end ## indices after 0
  end ## loop of classes
  return record
end

## Usage: attach_to_next(:address_component, [{:position => 'rear'}])
def attach_to_next(class_list, current_index, match_class, attributes)
  if current_index + 1 < class_list.count
    next_class = class_list[current_index + 1]
    if next_class[1][0] == match_class
      attributes.each do |att|
        next_class << att
      end
    else
      attach_to_next(class_list, current_index + 1, match_class, attributes)
    end
  end
end

def parse_line_elements(line)
  text_field = normalize_synonyms(line['text'])
  elements = text_field.split(/(,|\.\s)/).map { |x| x.strip }
  elements.map { |elem|
    unless /^\s*[,\.]\s*$/.match(elem).nil? then
      elements.delete(elem)
    end }
  tokens = []
  elements.map { |elem| tokens.concat(jitter_tokenizer(elem)) }
  return tokens
end

## Split token into two if begins or ends with a
## single character
def jitter_tokenizer(token)
  toReturn = []
  if (token[1] == " " && token[-2] == " ")
    toReturn << token[0..0]
    toReturn << token[2..-3]
    toReturn << token[-1..-1]
  elsif token[1] == " "
    toReturn << token[0..0]
    toReturn << token[2..-1]
  elsif token[-2] == " "
    toReturn << token[0..-3]
    toReturn << token[-1..-1]
  else
    toReturn << token
  end
  toReturn
end

## Manual string subset replacement
def normalize_synonyms(text_string)
  text_string.gsub(/\s(Av|Ave|av|ave)\.\s/, " Avenue ")
  #text_string.gsub(/\s(W)\.\s/, " West ")
  #ext_string.gsub(/\s(Av|Ave|av|ave)\.\s/, " Avenue ")
  #text_string.gsub(/\s(Av|Ave|av|ave)\.\s/, " Avenue ")
end

## Primary decision tree function
def category_parsing(ordered_array_of_tokens, jobs)
  decisions = ordered_array_of_tokens.each_with_index.map { |token, index| {:token => token, :index => index, :votes => []} }

  ordered_array_of_tokens.each_with_index do |token, index|
    if is_short?(token)
      #if could_be_abbreviation?(token, index)
      if contains_numbers?(token)
        decisions[index][:votes] << {:address_component => 1.0}
      elsif matches_cardinal_dir?(token)
        decisions[index][:votes] << {:address_component => 1.0}
      else
        decisions[index][:votes] << {:predicate => 1.0}
      end
      #else ## not an abbreviation
      #end
    else ## not short
      if contains_numbers?(token)
        decisions[index][:votes] << {:address_component => 1.0}
      end
      if index == 0 ## First token
        ## Automatically, this token is probably a name (based on position)
        decisions[index][:votes] << {:name_component => 1.0}
        unless contains_numbers?(token)
          ## If the first token doesn't contain numbers, even more likely that it is name
          decisions[index][:votes] << {:name_component => 1.0}
        end
      end ## end (first token)
      if ld_probably_job?(token, jobs, 2)
        decisions[index][:votes] << {:job_component => 1.0}
      else
        decisions[index][:votes] << {:job_component => -1.0}
      end
    end # end (not short)
  end ## loop
  decisions
end

## Aggregate token decisions with the most likely token class
## We run this on a list of decisions for a single line entry
def classify_decisions(set_of_token_decisions)
  set_of_token_decisions.map { |token| [token[:token], most_likely_class(token)] }
end

## Used to combine two subsequent address components,
## or two subsequent job components, etc.,
## taking a loss-less join of attributes except for
## :value, which is concatenated, separated by single whitespace
def merge_components(c1, c2)

end

## Count up votes, winner takes all
def most_likely_class(decisions_for_single_token)
  sums = {
      :job_component => 0,
      :name_component => 0,
      :address_component => 0,
      :predicate => 0
  }
  decisions_for_single_token[:votes].each do |vote|
    vote.each do |type, score|
      sums[type] += score
    end
  end
  sums.max_by { |k, v| v }
end

##################################
## Heuristic helper functions,
## used in decision tree
##################################

def contains_numbers?(token)
  !/\d/.match(token).nil?
end

def matches_cardinal_dir?(token)
  !/^(s|S|w|W|e|E|n|N).*$/.match(token).nil?
end

def is_short?(token)
  token.length < 4
end

def could_be_abbreviation?(token, index)
  token.length == 1 && index > 0
end

def guess_abbreviation(token)
end

## Note: good threshold is ~2?
def ld_probably_job?(token, jobs, threshold)
  match_report = closest_match(token, jobs)
  return match_report.keys[0] <= threshold
end

## Turn JSON lines into list of [original_line, parsed_tokens]
def create_parse_pairs(range_of_lines)
  range_of_lines.map { |line| [line, parse_line_elements(line)] }
end

## Given a list of tokens, return a map of token => count
def compute_frequencies(list)
  dict = {}
  list.each do |token|
    unless dict.has_key?(token)
      dict[token] = list.count(token)
    end
  end
  dict
end

## Complements the method above (turns frequences into a csv file)
def freqs_to_csv(frequencies, path)
  CSV.open(path, "wb") do |csv|
    frequencies.map { |k, v| csv << [k, v] }
  end
end

def parse_eval_csv(list_of_parse_pairs, path)
  CSV.open(path, "wb") do |csv|
    list_of_parse_pairs.map { |pair| csv << [pair[0]["text"], pair[1]] }
  end
end

## Find closest matching token from a library (using Levenshtein distance)
def closest_match(token, library)
  closest_tokens = []
  closest_token_score = 999
  library.each do |entity|
    ld_score = levenshtein_distance(token, entity)
    if ld_score < closest_token_score
      closest_token_score = ld_score
      closest_tokens = [entity]
    elsif ld_score == closest_token_score
      closest_tokens << entity
    end
  end
  {closest_token_score => closest_tokens}
end

##################################
## Miscellaneous utility functions
##################################

## Credit: https://stackoverflow.com/questions/16323571/measure-the-distance-between-two-strings-with-ruby
def levenshtein_distance(s, t)
  m = s.length
  n = t.length
  return m if n == 0
  return n if m == 0
  d = Array.new(m+1) { Array.new(n+1) }

  (0..m).each { |i| d[i][0] = i }
  (0..n).each { |j| d[0][j] = j }
  (1..n).each do |j|
    (1..m).each do |i|
      d[i][j] = if s[i-1] == t[j-1] # adjust index into string
                  d[i-1][j-1] # no operation required
                else
                  [d[i-1][j]+1, # deletion
                   d[i][j-1]+1, # insertion
                   d[i-1][j-1]+1, # substitution
                  ].min
                end
    end
  end
  d[m][n]
end
