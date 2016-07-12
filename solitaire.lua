-- solitaire-cipher
-- this implementation is based on schneier's description,
-- not the perl code provided in stephenson's cryptonomicon
-- see: https://www.schneier.com/academic/solitaire/

function usage()
  io.write [[Pontifex-Solitaire Cipher
Uses a two character deck notation for rank and suit, examples are:
  "Ac" is Ace of Clubs,    "5h" is Five of Hearts
  "Qs" is Queen of Spades, "Jd" is Jack of Diamonds
  "0c" is Ten of Clubs,    "Kh" is King of Hearts
  "Ja" is the Small Joker, "Jb" is the Big Joker

Options:
  --deck        Sets the initial keyed deck
  --passphrase  Use a passphrase to set the initial keyed deck
  --shuffle     Output a shuffled deck based on the current time
  --encrypt     Converts a plain text to a cipher text from arguments
  --decrypt     Converts a cipher text to a plain text from arguments (default)
  -             Indicate that input is taken from stdin

Examples
  --deck=JAAC2C3C4C5C6C7C8C9C0CJCQCKCAD2D3D ... etc.
  --passphrase=cryptonomicon
  --encrypt SOLIT AIRE
  --decrypt KIRAK SFJAN

Notes:
  The Optional Step from the Passphrase key method is NOT performed.
  Schneier's description is unclear, and his sample vectors don't
  include this step in their output.
]]
end

---- Deck manipulation -------------------------------------------------------

SMALL_JOKER = 53
BIG_JOKER = 54

function find_joker(deck, which)
  local index = 1
  while deck[index] ~= which and index < #deck do index = index + 1 end
  return index
end

function do_step_one(deck)
  local from = find_joker(deck, SMALL_JOKER)
  local to = from + 1
  if to == 55 then to = 2 end
  table.insert(deck, to, table.remove(deck, from))
end

function do_step_two(deck)
  local from = find_joker(deck, BIG_JOKER)
  local to = from + 2
  if to == 55 then to = 2
  elseif to == 56 then to = 3 end
  table.insert(deck, to, table.remove(deck, from))
end

function do_step_three(deck)
  local first = find_joker(deck, SMALL_JOKER)
  local second = find_joker(deck, BIG_JOKER)

  if second < first then first, second = second, first end

  -- deck would be unchanged if jokers were at both ends of the deck.
  if first > 1 or second < #deck then

    -- move cards second second joker to the other hand
    local other_hand = {}
    for i = second+1, #deck do
      table.insert(other_hand, table.remove(deck, second+1))
    end

    -- move cards from first the first joke to the back of the first deck
    for i = 1, first-1 do
      table.insert(deck, table.remove(deck, 1))
    end

    -- move cards from other hand to front of the deck
    for i = 1, #other_hand do
      table.insert(deck, i, table.remove(other_hand, 1))
    end
  end
end

function do_step_four(deck)
  -- deck would be unchanged if last card was a joker
  if deck[#deck] ~= SMALL_JOKER and deck[#deck] ~= BIG_JOKER then
    do_counting_cut(deck, deck[#deck])
  end
end

function do_counting_cut(deck, char_num)
  -- save the back card
  local back_card = table.remove(deck)

  -- move front cut to the back
  for i = 1, char_num do
    table.insert(deck, table.remove(deck, 1))
  end

  -- restore the back card to the end of the deck
  table.insert(deck, back_card)
end

function do_all_four_steps(deck)
  do_step_one(deck)
  do_step_two(deck)
  do_step_three(deck)
  do_step_four(deck)
end

-- step 5 and step 6
function get_output_card_number(deck)
  local top_card = deck[1]
  if top_card == SMALL_JOKER or top_card == BIG_JOKER then top_card = 53 end
  local output_card = deck[1+top_card]

  -- Joker cards do not produce an output
  if output_card == SMALL_JOKER or output_card == BIG_JOKER then return nil end

  return 1 + ((output_card-1) % 26)
end

function char2code(ch)
  return string.byte(string.upper(ch))-64
end

function code2char(code)
  return string.char(code+64)
end

function exit_error(...)
  io.stderr:write(...)
  io.stderr:write('\n')
  os.exit(1)
end

function key2card(key)
  if key==SMALL_JOKER then return "Ja" elseif key==BIG_JOKER then return "Jb" end
  local suitNum, suit = math.floor((key-1)/13)
  if suitNum == 0 then suit = "c"
  elseif suitNum == 1 then suit = "d"
  elseif suitNum == 2 then suit = "h"
  else suit = "s" end
  local rank = 1+((key-1) % 13)
  if rank==1 then
    return "A" .. suit
  elseif rank==10 then
    return "T" .. suit
  elseif rank==11 then
    return "J" .. suit

  elseif rank==12 then
    return "Q" .. suit
  elseif rank==13 then
    return "K" .. suit
  else
    return tostring(rank) .. suit
  end
end

function card2key(card)
  if card == "Ja" then return SMALL_JOKER
  elseif card == "Jb" then return BIG_JOKER end
  local rank, suit = card:sub(1,1), card:sub(2,2)
  local key
  if suit == "c" then key = 0
  elseif suit == "d" then key = 13
  elseif suit == "h" then key = 26
  elseif suit == "s" then key = 39 end
  if rank == "A" then
    return key + 1
  elseif rank=="T" then
    return key + 10
  elseif rank=="J" then
    return key + 11
  elseif rank=="Q" then
    return key + 12
  elseif rank=="K" then
    return key + 13
  else
    return key + tonumber(rank)
  end
end

function deck2cards(deck)
  local t = {}
  for i = 1, #deck do
    t[i]=key2card(deck[i])
  end
  return table.concat(t)
end

function build_initial_deck()
  local deck = {}
  for i = 1, 54 do
    deck[i] = i
  end
  return deck
end

function valid_deck(deck)
  local card_count = {}
  for i = 1, 54 do card_count[i] = 0 end
  for i = 1, #deck do
    card_count[deck[i]] = card_count[deck[i]] + 1
  end
  for i = 1, 54 do
    if card_count[i] == 0 then
      exit_error("Cards are missing from the deck!")
    elseif card_count[i] > 1 then
      exit_error("Duplicate cards were found in the deck!")
    end
  end
  return deck
end

function shuffled_deck()
  math.randomseed(os.time())
  math.random()
  math.random()
  math.random()
  local deck = build_initial_deck()
  for i = 1, #deck-1 do
    local j = math.random(1, #deck)
    deck[i], deck[j] = deck[j], deck[i]
  end
  return valid_deck(deck)
end

function parse_deck(deckphrase)
  local deck = {}
  for i = 1, math.floor(string.len(deckphrase)/2)*2, 2 do
    deck[#deck+1] = card2key(deckphrase:sub(i, i+1))
  end
  return valid_deck(deck)
end

function parse_passphrase(passphrase)
  local deck = build_initial_deck()
  for i = 1, string.len(passphrase) do
    do_all_four_steps(deck)
    do_counting_cut(deck, char2code(passphrase:sub(i,i)))
  end
  return valid_deck(deck)
end

function encrypt(deck, phrase)
  local plaintext = {}
  for i = 1, string.len(phrase) do plaintext[#plaintext+1] = phrase:sub(i,i) end
  while (#plaintext % 5) ~= 0 do plaintext[#plaintext+1] = 'X' end

  local ciphertext = {}

  local i = 1
  while i <= #plaintext do
    do_all_four_steps(deck)
    local output_card = get_output_card_number(deck)
    if output_card then
      local code = char2code(plaintext[i]) + output_card
      if code > 26 then code = code - 26 end
      ciphertext[i] = code2char(code)
      i = i + 1
    end
  end

  i = 6
  while i <= #plaintext do
    table.insert(ciphertext, i, ' ')
    i = i + 6
  end
  return table.concat(ciphertext)
end

function decrypt(deck, phrase)
  local ciphertext = {}
  for i = 1, string.len(phrase) do ciphertext[#ciphertext+1] = phrase:sub(i,i) end
  local plaintext = {}

  for i = 1, #ciphertext do
    do_all_four_steps(deck)
    local code = char2code(ciphertext[i]) - get_output_card_number(deck)
    if code < 1 then code = code + 26 end
    plaintext[i] = code2char(code)
  end

  local i = 6
  while i <= #plaintext do
    table.insert(plaintext, i, ' ')
    i = i + 6
  end
  return table.concat(plaintext)
end

function clean_input(user)
  assert(type(user) == "string")
  local s = {}
  for i = 1, #user do
    local k = user:sub(i,i):upper()
    -- skip spaces as they're traditional
    if k ~= ' ' and k ~= '\t' then
      local x = string.byte(k)
      if x < 65 or x > 90 then
        exit_error("Invalid character in input stream: "..k)
      else
        s[#s+1]=k
      end
    end
  end
  return table.concat(s)
end

function optparse(...)
  local cfg = {}
  for i = 1, select('#', ...) do
    local arg = tostring((select(i, ...)))
    local cmd, opt = arg:match('^%-+([A-Za-z0-9_]+)=([A-Za-z0-9_]+)$')
    if cmd == nil then
      cmd, opt = arg:match('^%-+([A-Za-z0-9_]+)$'), true
    end
    if cmd ~= nil then
      cfg[cmd] = opt
    else
      cfg[#cfg+1] = arg
    end
  end
  return cfg
end

function main(...)
  local opts = optparse(...)
  if opts["help"] then
    return usage()
  end

  if opts["shuffle"] then
    io.write("Generating a shuffled deck.", '\n')
    io.write("Warning, this was not done with a cryptographically secure RNG!", '\n')
    local deck = shuffled_deck()
    io.write("Deck: ", deck2cards(deck), '\n')
    return
  end

  if opts["passphrase"] and opts["deck"] then
    exit_error("Only use a passphrase, or the deck, not both.")
  end
  if opts["encrypt"] and opts["decrypt"] then
    exit_error("Only encrypt, or decrypt, not both.")
  end

  local deck
  if opts["passphrase"] then
    if type(opts["passphrase"])~="string" then
      exit_error("Invalid usage of the passphase argument (are you missing an = sign?)")
    end
    deck = parse_passphrase(clean_input(opts["passphrase"]))
  elseif opts["deck"] then
    if type(opts["passphrase"])~="string" then
      exit_error("Invalid usage of the deck argument (are you missing an = sign?)")
    end
    deck = parse_deck(opts["deck"])
  else
    deck = build_initial_deck()
    io.write("Warning, using unkeyed deck!", '\n')
  end

  io.write("Initial deck: ", deck2cards(deck), '\n')

  local codecFn, message = decrypt, "Decrypted"
  if opts["encrypt"] then
    codecFn, message = encrypt, "Encrypted"
  end

  local inputFn
  if opts[1] == '-' then
    inputFn = function() return io.read("*l") end
  else
    local line = table.concat(opts)
    inputFn = function() local _line; _line, line = line, nil; return _line end
  end

  local line
  repeat
    local line = inputFn()
    if line then
      io.write(message, ": ", codecFn(deck, clean_input(line)), '\n')
      io.write("Deck: ", deck2cards(deck), '\n')
    end
  until not line
end

main(...)

