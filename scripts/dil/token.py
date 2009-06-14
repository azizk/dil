# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from __future__ import unicode_literals
from dil.token_list import TOK
import re

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

  def __unicode__(self):
    return self.text
  __str__ = __unicode__

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
    token.value = parse_funcs[kind](token, (tup, str_list))
    i += 1
  return result


escape_table = {
  "'":39,'"':34,'?':63,'\\':92,'a':7,'b':8,'f':12,'n':10,'r':13,'t':9,'v':11
}
rx_newline = re.compile("\r\n?|\n|\u2028|\u2029")
rx_escape = re.compile(
  r"\\(?:u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8}|[0-7]{1,3}|&\w+;|.)"
)

def escape2char(s):
  """ E.g. "\\u0041" -> 'A' """
  from htmlentitydefs import name2codepoint
  c = s[1]
  if c in 'xuU':    c = int(s[2:], 16)
  elif c.isdigit(): c = int(s[1:], 8)
  elif c == '&':    c = name2codepoint.get(s[2:-1], 0xFFFD)
  else:             c = escape_table.get(c, 0xFFFD)
  return unichr(c)

def parse_str(t, more):
  s = t.text.rstrip("cwd") # Strip suffix.
  c = s[0]
  if c == 'r': # Raw string.
    s = s[2:-1]
  elif c == '`': # Raw string.
    s = s[1:-1]
  elif c == '\\': # Escape string.
    return rx_escape.sub(lambda m: escape2char(m.group()), s) + "\0"
  elif c == '"': # Normal string with escape sequences.
    s = rx_escape.sub(lambda m: escape2char(m.group()), s[1:-1])
  elif c == 'q': # Delimited or token string.
    if s[1] == '"': # Delimited string.
      if s[2] in "[({<":
        s = s[3:-2] # E.g.: q"[abcd]" -> abcd
      else:
        # Get the identifier delimiter. |q"Identifier\n| -> 2 + len(delim) + 1
        m = rx_newline.search(s)
        assert m
        delim_len = m.start() - 2
        s = s[2+delim_len+1 : -delim_len-1]
    elif s[1] == '{': # Token string.
      s = s[2:-1]
  elif c == 'x': # Hex string.
    s = s[2:-1] # x"XX" -> XX
    result = ""
    n = None
    for hexd in s: #rx_hexdigits.findall(s): # Regexp not really needed.
      d = ord(hexd)
      if not 48 <= d <= 57 and not 97 <= (d|0x20) <= 102:
        continue
      hexd = int(hexd, 16)
      if n == None:
        n = hexd
        continue
      result += unichr((n << 4) + hexd)
      n = None
    return result + "\0"
  return rx_newline.sub("\n", s) + "\0" # Convert newlines and zero-terminate.

def parse_chr(t, more):
  s = t.text[1:-1] # Remove single quotes. 'x' -> x
  if s[0] == '\\':
    return escape2char(s)
  return s

def parse_int(t, more):
  s = t.text.replace("_", "") # Strip underscore separators.
  base = 10
  if len(s) >= 2:
    if s[1] in 'xX':
      base = 16
    elif s[1] in 'bB':
      base = 2
    elif s[0] == '0':
      base = 8
  return int(s.rstrip("uUL"), base)

def parse_float(t, more):
  # TODO: use mpmath for multiprecission floats. Python has no long doubles.
  # (http://code.google.com/p/mpmath/)
  s = t.text.replace("_", "") # Strip underscore separators.
  imag_or_real = 1j if s[-1] == 'i' else 1.
  float_ = float.fromhex if s[1:2] in 'xX' else float
  return float_(s.rstrip("fFLi")) * imag_or_real

def get_time(t, more):
  return 0 # TODO:
def get_timestamp(t, more):
  return 0 # TODO:
def get_date(t, more):
  return 0 # TODO:
def get_line(t, more):
  return t.linnum # TODO:
def get_file(t, more):
  return "" # TODO:
def get_vendor(t, more):
  return "dil"
def get_version(t, more):
  return "x.xxx" # TODO:

def get_parse_funcs():
  return_None = lambda t,m: None
  func_list = [return_None] * TOK.MAX
  for kind, func in (
      (TOK.Identifier, lambda t,x: t.text),(TOK.String, parse_str),
      (TOK.CharLiteral, parse_chr),(TOK.FILE, get_file),(TOK.LINE, get_line),
      (TOK.DATE, get_date),(TOK.TIME, get_time),(TOK.TIMESTAMP, get_timestamp),
      (TOK.VENDOR, get_vendor),(TOK.VERSION, get_version),
      (TOK.Int32, parse_int),(TOK.Int64, parse_int),(TOK.Uint32, parse_int),
      (TOK.Uint64, parse_int),(TOK.Float32, parse_float),
      (TOK.Float64, parse_float),(TOK.Float80, parse_float),
      (TOK.Imaginary32, parse_float),(TOK.Imaginary64, parse_float),
      (TOK.Imaginary80, parse_float)
    ):
    func_list[kind] = func
  return tuple(func_list)
parse_funcs = get_parse_funcs()
