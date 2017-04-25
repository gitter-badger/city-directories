#require 'JSON'
#lines = []
#File.open('/Users/stephen/Downloads/1854-55/lines.ndjson').each do |line|
#  lines << JSON.parse(line)
#end

def parse_line_elements(line)
  text_field = normalize_synonyms(line['text'])
  elements = text_field.split(/(,|\.\s)/).map{|x| x.strip}
  elements.map{ |elem| unless /^\s*[,\.]\s*$/.match(elem).nil? then elements.delete(elem) end }
  return elements
end

## Manual string subset replacement
def normalize_synonyms(text_string)
  text_string.gsub(/\s(Av|Ave|av|ave)\.\s/, " Avenue ")
  #text_string.gsub(/\s(W)\.\s/, " West ")
  #ext_string.gsub(/\s(Av|Ave|av|ave)\.\s/, " Avenue ")
  #text_string.gsub(/\s(Av|Ave|av|ave)\.\s/, " Avenue ")
end

# Primary decision tree function
def category_parsing(ordered_array_of_tokens, jobs)
  decisions = ordered_array_of_tokens.each_with_index.map{ |token,index| {:token => token, :index => index, :votes => []} }

  ordered_array_of_tokens.each_with_index do |token,index|
    if is_short?(token)
      if could_be_abbreviation?(token, index)
        decisions[index][:votes] << {:predicate => 1.0}
      else ## not an abbreviation
      end
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
  end  ## loop
  decisions
end

## Aggregate token decisions with the most likely token class
def classify_decisions(set_of_token_decisions)
  set_of_token_decisions.map{|token| [token[:token], most_likely_class(token)]}
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
    vote.each do |type,score|
      sums[type] += score
    end
  end
  sums.max_by{|k,v| v}
end

##################################
## Heuristic helper functions,
## used in decision tree
##################################

def contains_numbers?(token)
  !/\d/.match(token).nil?
end

def is_short?(token)
  token.length < 5
end

def could_be_abbreviation?(token, index)
  token.length == 1 && index > 0
end

def guess_abbrevition(token)
  if token.

end

## Note: good threshold is ~2?
def ld_probably_job?(token, jobs, threshold)
  match_report = closest_match(token, jobs)
  return match_report.keys[0] <= threshold
end

## Turn JSON lines into list of [original_line, parsed_tokens]
def create_parse_pairs(range_of_lines)
  range_of_lines.map{ |line| [line, parse_line_elements(line)]}
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
    frequencies.map{ |k,v| csv << [k, v]}
  end
end

def parse_eval_csv(list_of_parse_pairs, path)
  CSV.open(path, "wb") do |csv|
    list_of_parse_pairs.map{ |pair| csv << [pair[0]["text"], pair[1]]}
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
  d = Array.new(m+1) {Array.new(n+1)}

  (0..m).each {|i| d[i][0] = i}
  (0..n).each {|j| d[0][j] = j}
  (1..n).each do |j|
    (1..m).each do |i|
      d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
                  d[i-1][j-1]       # no operation required
                else
                  [ d[i-1][j]+1,    # deletion
                    d[i][j-1]+1,    # insertion
                    d[i-1][j-1]+1,  # substitution
                  ].min
                end
    end
  end
  d[m][n]
end
