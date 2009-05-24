# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from __future__ import unicode_literals
from dil.token_list import TOK

class Token:
  """
  kind = The kind of the token.
  is_ws = Is this a whitespace token?
  ws = Preceding whitespace characters.
  text = The text of the token.
  value = The value (str,int,float etc.) of the token.
  next = Next token in the list.
  prev = Previous token in the list.
  """
  def __init__(self, kind, ws, text):
    self.kind = kind
    self.is_ws = (2 <= kind <= 7) #kind in (2, 3, 4, 5, 6, 7)
    self.ws = ws
    self.text = text
    self.value = None
    self.next = self.prev = None
    self.linnum = None

# Create a table of whitespace strings.
ws_table = " "*20
ws_table = [ws_table[:i] for i in range(1,21)]

def create_tokens(token_list):
  str_list = token_list[0] # The first element must be the string list.
  token_list = token_list[1]
  head = Token(TOK.HEAD, "", "")
  line_num = 1
  prev = head
  result = [None]*len(token_list) # Reserve space.
  i = 0
  for tup in token_list:
    kind = tup[0]
    if kind == TOK.Newline:
      line_num += 1
    ws = tup[1]
    if type(ws) == int:
      # Get ws from the table if short enough, otherwise create it.
      ws = ws_table[ws] if ws < 20 else " "*ws
    # Get the text of the token from str_list if there's a 3rd element,
    # otherwise get it from the table TOK.str.
    text = str_list[tup[2]] if len(tup) >= 3 else TOK.str[kind]
    # Create the token.
    token = Token(kind, ws, text)
    token.linnum = line_num
    token.prev = prev # Link to the previous token.
    prev.next = token # Link to this token from the previous one.
    prev = token
    result[i] = token
    i += 1
  return result
