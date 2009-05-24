# -*- coding: utf-8 -*-
# Author: Aziz Köksal

class TOK:
  Invalid,Illegal,Comment,Shebang,HashLine,Filespec,Newline,Empty,Identifier,\
  String,CharLiteral,FILE,LINE,DATE,TIME,TIMESTAMP,VENDOR,VERSION,Int32,\
  Int64,Uint32,Uint64,Float32,Float64,Float80,Imaginary32,Imaginary64,\
  Imaginary80,LParen,RParen,LBracket,RBracket,LBrace,RBrace,Dot,Slice,\
  Ellipses,Unordered,UorE,UorG,UorGorE,UorL,UorLorE,LorEorG,LorG,Assign,\
  Equal,NotEqual,Not,LessEqual,Less,GreaterEqual,Greater,LShiftAssign,LShift,\
  RShiftAssign,RShift,URShiftAssign,URShift,OrAssign,OrLogical,OrBinary,\
  AndAssign,AndLogical,AndBinary,PlusAssign,PlusPlus,Plus,MinusAssign,\
  MinusMinus,Minus,DivAssign,Div,MulAssign,Mul,ModAssign,Mod,XorAssign,Xor,\
  CatAssign,Tilde,Colon,Semicolon,Question,Comma,Dollar,Abstract,Alias,Align,\
  Asm,Assert,Auto,Body,Break,Case,Cast,Catch,Class,Const,Continue,Debug,\
  Default,Delegate,Delete,Deprecated,Do,Else,Enum,Export,Extern,False,Final,\
  Finally,For,Foreach,Foreach_reverse,Function,Goto,Gshared,If,Immutable,\
  Import,In,Inout,Interface,Invariant,Is,Lazy,Macro,Mixin,Module,New,Nothrow,\
  Null,Out,Overloadset,Override,Package,Pragma,Private,Protected,Public,Pure,\
  Ref,Return,Shared,Scope,Static,Struct,Super,Switch,Synchronized,Template,\
  This,Thread,Throw,Traits,True,Try,Typedef,Typeid,Typeof,Union,Unittest,\
  Version,Volatile,While,With,Char,Wchar,Dchar,Bool,Byte,Ubyte,Short,Ushort,\
  Int,Uint,Long,Ulong,Cent,Ucent,Float,Double,Real,Ifloat,Idouble,Ireal,\
  Cfloat,Cdouble,Creal,Void,HEAD,EOF = range(0,194)
  str = (
    'Invalid','Illegal','Comment','#! /shebang/','#line','"filespec"','\n',
    'Empty','Identifier','String','CharLiteral','__FILE__','__LINE__',
    '__DATE__','__TIME__','__TIMESTAMP__','__VENDOR__','__VERSION__','Int32',
    'Int64','Uint32','Uint64','Float32','Float64','Float80','Imaginary32',
    'Imaginary64','Imaginary80','(',')','[',']','{','}','.','..','...','!<>=',
    '!<>','!<=','!<','!>=','!>','<>=','<>','=','==','!=','!','<=','<','>=','>',
    '<<=','<<','>>=','>>','>>>=','>>>','|=','||','|','&=','&&','&','+=','++',
    '+','-=','--','-','/=','/','*=','*','%=','%','^=','^','~=','~',':',';','?',
    ',','$','abstract','alias','align','asm','assert','auto','body','break',
    'case','cast','catch','class','const','continue','debug','default',
    'delegate','delete','deprecated','do','else','enum','export','extern',
    'false','final','finally','for','foreach','foreach_reverse','function',
    'goto','__gshared','if','immutable','import','in','inout','interface',
    'invariant','is','lazy','macro','mixin','module','new','nothrow','null',
    'out','__overloadset','override','package','pragma','private','protected',
    'public','pure','ref','return','shared','scope','static','struct','super',
    'switch','synchronized','template','this','__thread','throw','__traits',
    'true','try','typedef','typeid','typeof','union','unittest','version',
    'volatile','while','with','char','wchar','dchar','bool','byte','ubyte',
    'short','ushort','int','uint','long','ulong','cent','ucent','float',
    'double','real','ifloat','idouble','ireal','cfloat','cdouble','creal',
    'void','HEAD','EOF',
  )
