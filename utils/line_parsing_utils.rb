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

## Turn JSON lines into list of [original_line, parsed_tokens]
def test_parsing(range_of_lines)
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
