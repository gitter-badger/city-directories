const fs = require('fs')
const path = require('path')
const csv = require('csv-parser')
const H = require('highland')
const R = require('ramda')
const lunr = require('lunr')

var occupations = JSON.parse(fs.readFileSync("/Users/stephen/git/city-directories/utils/consolidated_occupations.json"));

/*
TODO - widow parsing doesn't seem to be working (5/5/2017)
TODO - improve handling of middle initials / company abbreviations (5/5/2017)
TODO - address cardinal direction scoring by looking at order of token (5/5/2017)
*/

/*
var ndjson_lines = fs.readFileSync("/Users/stephen/Documents/nypl-directories/1854-55/lines.ndjson", {
  'encoding': 'utf-8'
}).split("\n")
var interpreted_lines = []
ndjson_lines.forEach((line, index) => {
  console.log(index);
  parsed = JSON.parse(line);
  interpreted_lines.push([parsed, create_labeled_record(parsed['text'])]);
})
*/

/*
fs.writeFile("/Users/stephen/git/city-directories/utils/parsing_output/node_test_5k_5-5-2017.json", JSON.stringify(interpreted_lines,null,2))
*/

var job_idx = lunr(function() {
  this.ref('id')
  this.field('value')
  this.field('source')
  occupations.forEach(function(doc, index) {
    mdoc = doc;
    mdoc['id'] = index;
    this.add(doc)
  }, this)
})

function job_probability_score(token, search_index) {
  if (search_index.search(token).length > 0) {
    return 1.5;
  } else if (search_index.search(token + "~1").length > 0) {
    return 1.0;
  } else if (search_index.search(token + "~2").length > 0) {
    return 0.9;
  } else if (search_index.search(token + "~4").length > 0) {
    return 0.5;
  } else {
    return -0.5;
  }
}



var contents = fs.readFileSync("/Users/stephen/git/city-directories/utils/parsing_output/nyc-hpc_100k_5-1-2017/out_v85.json");
var json_content = JSON.parse(contents)

/* Class contains heuristic helper functions
   for labeling tokens */
class TokenInterpret {
  static contains_numbers(token) {
    return /\d/.test(token)
  }
  static matches_cardinal_dir(token) {
    return /^(s|S|w|W|e|E|n|N).{0,1}$/.test(token)
  }
  static no_white_space(token) {
    return !/^\S*(\s)+\S*$/.test(token)
  }
  static is_short(token) {
    return (token.length < 4)
  }
  static could_be_abbreviation(token, index) {
    return (token.length == 1 && index > 0)
  }
  static probably_job(token) {
    return true
  }
}

class InterpretedLine {
  constructor(original_ocr_object) {
    this.o_object = original_ocr_object;
    this.o_text = this.o_object['text']
  }
}

function tokenize(line) {
  t1 = line.split(/(,|\.\s)/).map((elem) => {
    return elem.trim();
  })
  t2 = t1.filter((elem) => {
    return !(/^\s*[,\.]\s*$/.test(elem))
  })
  t3 = []
  t2.forEach(function(token) {
    t3 = t3.concat(jitter_split(token));
  })
  return t3;
}

/* Split token into two if begins or ends with a single character */
function jitter_split(token) {
  if (token.slice(1, 2) == ' ' && token.slice(-2, -1) == ' ') {
    return [token.slice(0, 1), token.slice(2, -2), token.slice(-1)]
  } else if (token.slice(1, 2) == ' ') {
    return [token.slice(0, 1), token.slice(2)]
  } else if (token.slice(-2, -1) == ' ') {
    return [token.slice(0, -2), token.slice(-1)]
  } else {
    return [token]
  }
}

function category_vote(ordered_token_array) {
  decisions = ordered_token_array.map(((token, i) => {
    return {
      'token': token,
      'index': i,
      'votes': []
    }
  }));
  ordered_token_array.forEach(function(token, i) {
    if (TokenInterpret.is_short(token)) {
      if (TokenInterpret.contains_numbers(token)) {
        decisions[i]['votes'].push({
          'address_component': 1.0
        })
      } else if (TokenInterpret.matches_cardinal_dir(token)) {
        decisions[i]['votes'].push({
          'address_component': 1.0
        })
      } else {
        decisions[i]['votes'].push({
          'predicate': 1.0
        })
      }
    } else {
      // Not short
      if (TokenInterpret.contains_numbers(token)) {
        decisions[i]['votes'].push({
          'address_component': 2.0
        })
      }
      if (i == 0) {
        decisions[i]['votes'].push({
          'name_component': 1.0
        })
        if (!TokenInterpret.contains_numbers(token)) {
          decisions[i]['votes'].push({
            'name_component': 1.0
          })
        }
      } // End first token
      decisions[i]['votes'].push({
        'job_component': job_probability_score(token, job_idx)
      })
      if (TokenInterpret.no_white_space(token)) {
        decisions[i]['votes'].push({
          'address_component': 0.5
        })
      }
    }
  })
  return decisions;
}

function most_likely_class(token_decision_object_array) {
  return token_decision_object_array.map((entry) => {
    modified_entry = entry;
    sums = {
      'job_component': 0.0,
      'name_component': 0.0,
      'address_component': 0.0,
      'predicate': 0.0,
      'ambiguous': 0.0
    }
    entry['votes'].forEach(function(vote) {
      entries = Object.entries(vote)
      k = entries[0][0]
      v = entries[0][1]
      sums[k] += v
    })
    modified_entry['sums'] = sums
    return modified_entry;
  })
}

function winner_take_all(array_most_likely_classes) {
  return array_most_likely_classes.map((entry) => {
    modified_entry = entry;
    modified_entry['winning_class'] = Object.entries(entry['sums']).reduce((acc, val) => {
      return (val[1] > acc[1]) ? val : acc
    })
    return modified_entry;
  })
}

function recount_votes(token_decision_object) {
  modified_entry = token_decision_object;
  sums = {
    'job_component': 0.0,
    'name_component': 0.0,
    'address_component': 0.0,
    'predicate': 0.0,
    'ambiguous': 0.0
  }
  token_decision_object['votes'].forEach(function(vote) {
    entries = Object.entries(vote)
    k = entries[0][0]
    v = entries[0][1]
    sums[k] += v
  })
  modified_entry['sums'] = sums
  modified_entry['winning_class'] = Object.entries(modified_entry['sums']).reduce((acc, val) => {
    return (val[1] > acc[1]) ? val : acc
  })
  return modified_entry;
}

function semantic_tokenize(line) {
  return winner_take_all(most_likely_class(category_vote(tokenize(line))))
}

function create_labeled_record(line) {
  return consolidate_features(semantic_tokenize(line))
}

function previous_winning_class(decision_list, current_index) {
  if (current_index - 1 >= 0) {
    return decision_list[current_index - 1]['winning_class'][0]
  }
  return null;
}

function modify_probability_of_subsequent(list_of_acceptable, vote, decisions, curr_index) {
  if (curr_index + 1 < decisions.length) {
    next_decision = decisions[curr_index + 1]
    if (next_decision['winning_class'] != Object.keys(vote)[0] && list_of_acceptable.includes(next_decision['winning_class'][0])) {
      decisions[curr_index + 1].votes.push(vote);
      decisions[curr_index + 1] = recount_votes(decisions[curr_index + 1]);
      return [decisions[curr_index + 1], curr_index]
    } else {
      return modify_probability_of_subsequent(list_of_acceptable, vote, decisions, curr_index + 1);
    }
  }
  return false;
}

function subsequent_is_not_confident(decision_list, current_index) {
  if (current_index + 1 < decision_list.length) {
    next_decision = decision_list[current_index + 1]
    if (next_decision['winning_class'][1] < 1.0) {
      return next_decision['winning_class'][0];
    }
  }
  return null;
}

/* Returns a record with labeled attributes */
function consolidate_features(all_decisions) {
  record = {
    'subject': [],
    'location': []
  }
  all_decisions.forEach((token, index) => {
    parsed_class = token['winning_class'][0]
    token_value = token['token']
    if (index == 0 && parsed_class == 'name_component') {
      record['subject'].push({
        'value': token_value,
        'type': 'primary'
      })
    } else {
      switch (parsed_class) {
        case 'job_component':
          if (!record['subject'].length == 0) {
            record['subject'][0]['occupation'] = token_value;
          }
          break;
        case 'predicate':
          switch (token_value) {
            case 'wid':
              if (!record['subject'].length == 0) {
                record['subject'][0]['occupation'] = 'widow';
              }
              deceased_name = look_for_name_of_deceased(all_decisions, index)
              if (deceased_name) {
                record['subject'].push({
                  'value': deceased_name,
                  'type': 'deceased spouse of primary'
                })
              }
              break;
            case 'h':
              modify_probability_of_subsequent(['job_component', 'name_component'], {
                "address_component": 1.0
              }, all_decisions, index)
              attach_to_next(all_decisions, index, 'address_component', [{
                'type': 'home'
              }])
              break;
            case 'r':
              modify_probability_of_subsequent(['job_component', 'name_component'], {
                "address_component": 1.0
              }, all_decisions, index)
              attach_to_next(all_decisions, index, 'address_component', [{
                'position': 'rear'
              }])
              break;
          }
          break;
        case 'address_component':
          /* We check the confidence of the next token too,
            and may merge it into the address as well */
          subsequent_class = subsequent_is_not_confident(all_decisions, index)
          if (subsequent_class == "job_component") {
            all_decisions[index + 1]['winning_class'] = ['address_component', 1.0]
          }
          loc = {
            'value': token_value
          }
          if (token['additional']) {
            token['additional'].forEach((obj) => {
              pair = Object.entries(obj)[0]
              k = pair[0]
              v = pair[1]
              loc[k] = v
            })
          }
          mr = merge_if_directly_subsequent_is_alike(all_decisions, index, parsed_class)
          if (mr) {
            all_decisions[index + 1] = mr
          } else {
            record['location'].push(loc)
          }
          break;
      }
    }
  })
  return record;
}

function merge_if_directly_subsequent_is_alike(decision_list, current_index, current_token_class) {
  if (current_index + 1 < decision_list.length) {
    next_decision = decision_list[current_index + 1]
    if (next_decision['winning_class'][0] == current_token_class) {
      next_decision['token'] = decision_list[current_index]['token'] + " " + next_decision['token']
      if (decision_list[current_index]['additional']) {
        if (next_decision['additional']) {
          next_decision['additional'].concat(decision_list[current_index]['additional'])
        } else {
          next_decision['additional'] = decision_list[current_index]['additional']
        }
      }
      return next_decision;
    }
  }
  return false;
}

function attach_to_next(class_list, current_index, match_class, attributes) {
  if (current_index + 1 < class_list.length) {
    next_class = class_list[current_index + 1]
    if (next_class['winning_class'][0] == match_class) {
      attributes.forEach((att) => {
        if (next_class['additional']) {
          next_class['additional'].push(att)
        } else {
          next_class['additional'] = [att]
        }
      })
    } else {
      attach_to_next(class_list, current_index + 1, match_class, attributes)
    }
  }
}

function look_for_name_of_deceased(list_of_classes, current_index) {
  if (current_index + 1 < list_of_classes.count) {
    next_class = list_of_classes[current_index + 1]
    if (next_class['winning_class'][0] == 'name_component' || ['winning_class'][1] <= 0.5) {
      // we check if the next class is either a name_component, or had a low confidence
      next_class['winning_class'][0] = 'already_considered'
      return next_class['token']
    }
  }
  return null;
}


/*
var output = fs.createWriteStream('/Users/stephen/Documents/nypl-directories/1854-55/stream_out.ndjson')
var dest = H(fs.createWriteStream('/Users/stephen/Documents/nypl-directories/1854-55/stream_out.ndjson'))
labeled_records = []
H(fs.createReadStream('/Users/stephen/Documents/nypl-directories/1854-55/lines.ndjson')).split().compact().map(JSON.parse).each((line) => {
  labeled_records.push([line, create_labeled_record(line['text'])])
})
*/
