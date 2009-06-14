#! /usr/bin/env python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from sys import stdout

toks = (
  "Invalid","Illegal","Comment","#! /shebang/","#line","\"filespec\"","\n",
  "Empty","Identifier","String","CharLiteral","__FILE__","__LINE__","__DATE__",
  "__TIME__","__TIMESTAMP__","__VENDOR__","__VERSION__","Int32","Int64",
  "Uint32","Uint64","Float32","Float64","Float80","Imaginary32","Imaginary64",
  "Imaginary80","(",")","[","]","{","}",".","..","...","!<>=","!<>","!<=","!<",
  "!>=","!>","<>=","<>","=","==","!=","!","<=","<",">=",">","<<=","<<",">>=",
  ">>",">>>=",">>>","|=","||","|","&=","&&","&","+=","++","+","-=","--","-",
  "/=","/","*=","*","%=","%","^=","^","~=","~",":",";","?",",","$",
)
ids = (
  "Invalid","Illegal","Comment","Shebang","HashLine","Filespec","Newline",
  "Empty","Identifier","String","CharLiteral","FILE","LINE","DATE","TIME",
  "TIMESTAMP","VENDOR","VERSION","Int32","Int64","Uint32","Uint64",
  "Float32","Float64","Float80","Imaginary32","Imaginary64","Imaginary80",
  "LParen","RParen","LBracket","RBracket","LBrace","RBrace","Dot","Slice",
  "Ellipses","Unordered","UorE","UorG","UorGorE","UorL","UorLorE","LorEorG",
  "LorG","Assign","Equal","NotEqual","Not","LessEqual","Less",
  "GreaterEqual","Greater","LShiftAssign","LShift","RShiftAssign","RShift",
  "URShiftAssign","URShift","OrAssign","OrLogical","OrBinary","AndAssign",
  "AndLogical","AndBinary","PlusAssign","PlusPlus","Plus","MinusAssign",
  "MinusMinus","Minus","DivAssign","Div","MulAssign","Mul","ModAssign","Mod",
  "XorAssign","Xor","CatAssign","Tilde","Colon","Semicolon","Question","Comma",
  "Dollar",
)

tokens = zip(ids, toks)

keywords = (
  "abstract","alias","align","asm","assert","auto","body","break","case",
  "cast","catch","class","const","continue","debug","default","delegate",
  "delete","deprecated","do","else","enum","export","extern","false","final",
  "finally","for","foreach","foreach_reverse","function","goto","__gshared",
  "if","immutable","import","in","inout","interface","invariant","is","lazy","macro",
  "mixin","module","new","nothrow","null","out","__overloadset","override",
  "package","pragma","private","protected","public","pure","ref","return",
  "shared","scope","static","struct","super","switch","synchronized",
  "template","this","__thread","throw","__traits","true","try","typedef",
  "typeid","typeof","union","unittest","version","volatile","while","with",
  "char","wchar","dchar","bool","byte","ubyte","short","ushort","int","uint",
  "long","ulong","cent","ucent","float","double","real","ifloat",
  "idouble","ireal","cfloat","cdouble","creal","void","HEAD","EOF"
)
for kw in keywords:
  kw2 = kw.lstrip('_')
  tokens += [(kw2[0].upper()+kw2[1:], kw)]

def main():
  def write(text, maxlen=80, term="\n", flush=False, line=[""]):
    if (len(line[0]) + len(text)) >= maxlen or flush:
      stdout.write(line[0] + term)
      line[0] = text
    else:
      line[0] += text

  print "class TOK:"
  stdout.write("  ")
  for tok, tokstr in tokens[:-1]:
    write('%s,' % tok, 76, "\\\n  ")
  write(tokens[-1][0]+" = range(0,%s)" % len(tokens))
  write("", flush=True)
  print "  MAX = %s" % len(tokens)

  stdout.write("  str = (\n    ")
  for tok, tokstr in tokens:
    write("'%s'," % tokstr.replace("\n", "\\n"), 76, "\n    ")
  write("", flush=True)
  print "  )"

if __name__ == '__main__':
  main()
