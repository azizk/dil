#! /usr/bin/env python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from future import unicode_literals, print_function
from common import *
__file__ = tounicode(__file__)

nodes_info = (
  # Declarations:
  "CompoundDeclaration",
  "EmptyDeclaration",
  "IllegalDeclaration",
  "ModuleDeclaration",
  "ImportDeclaration",
  "AliasDeclaration",
  "AliasThisDeclaration",
  "TypedefDeclaration",
  "EnumDeclaration",
  "EnumMemberDeclaration",
  "ClassDeclaration",
  "InterfaceDeclaration",
  "StructDeclaration",
  "UnionDeclaration",
  "ConstructorDeclaration",
  "StaticConstructorDeclaration",
  "DestructorDeclaration",
  "StaticDestructorDeclaration",
  "FunctionDeclaration",
  "VariablesDeclaration",
  "InvariantDeclaration",
  "UnittestDeclaration",
  "DebugDeclaration",
  "VersionDeclaration",
  "StaticIfDeclaration",
  "StaticAssertDeclaration",
  "TemplateDeclaration",
  "NewDeclaration",
  "DeleteDeclaration",
  "ProtectionDeclaration",
  "StorageClassDeclaration",
  "LinkageDeclaration",
  "AlignDeclaration",
  "PragmaDeclaration",
  "MixinDeclaration",

  # Statements:
  "CompoundStatement",
  "IllegalStatement",
  "EmptyStatement",
  "FuncBodyStatement",
  "ScopeStatement",
  "LabeledStatement",
  "ExpressionStatement",
  "DeclarationStatement",
  "IfStatement",
  "WhileStatement",
  "DoWhileStatement",
  "ForStatement",
  "ForeachStatement",
  "ForeachRangeStatement", # D2.0
  "SwitchStatement",
  "CaseStatement",
  "DefaultStatement",
  "ContinueStatement",
  "BreakStatement",
  "ReturnStatement",
  "GotoStatement",
  "WithStatement",
  "SynchronizedStatement",
  "TryStatement",
  "CatchStatement",
  "FinallyStatement",
  "ScopeGuardStatement",
  "ThrowStatement",
  "VolatileStatement",
  "AsmBlockStatement",
  "AsmStatement",
  "AsmAlignStatement",
  "IllegalAsmStatement",
  "PragmaStatement",
  "MixinStatement",
  "StaticIfStatement",
  "StaticAssertStatement",
  "DebugStatement",
  "VersionStatement",

  # Expressions:
  "IllegalExpression",
  "CondExpression",
  "CommaExpression",
  "OrOrExpression",
  "AndAndExpression",
  "OrExpression",
  "XorExpression",
  "AndExpression",
  "EqualExpression",
  "IdentityExpression",
  "RelExpression",
  "InExpression",
  "LShiftExpression",
  "RShiftExpression",
  "URShiftExpression",
  "PlusExpression",
  "MinusExpression",
  "CatExpression",
  "MulExpression",
  "DivExpression",
  "ModExpression",
  "AssignExpression",
  "LShiftAssignExpression",
  "RShiftAssignExpression",
  "URShiftAssignExpression",
  "OrAssignExpression",
  "AndAssignExpression",
  "PlusAssignExpression",
  "MinusAssignExpression",
  "DivAssignExpression",
  "MulAssignExpression",
  "ModAssignExpression",
  "XorAssignExpression",
  "CatAssignExpression",
  "AddressExpression",
  "PreIncrExpression",
  "PreDecrExpression",
  "PostIncrExpression",
  "PostDecrExpression",
  "DerefExpression",
  "SignExpression",
  "NotExpression",
  "CompExpression",
  "CallExpression",
  "NewExpression",
  "NewAnonClassExpression",
  "DeleteExpression",
  "CastExpression",
  "IndexExpression",
  "SliceExpression",
  "ModuleScopeExpression",
  "IdentifierExpression",
  "SpecialTokenExpression",
  "DotExpression",
  "TemplateInstanceExpression",
  "ThisExpression",
  "SuperExpression",
  "NullExpression",
  "DollarExpression",
  "BoolExpression",
  "IntExpression",
  "RealExpression",
  "ComplexExpression",
  "CharExpression",
  "StringExpression",
  "ArrayLiteralExpression",
  "AArrayLiteralExpression",
  "AssertExpression",
  "MixinExpression",
  "ImportExpression",
  "TypeofExpression",
  "TypeDotIdExpression",
  "TypeidExpression",
  "IsExpression",
  "ParenExpression",
  "FunctionLiteralExpression",
  "TraitsExpression", # D2.0
  "VoidInitExpression",
  "ArrayInitExpression",
  "StructInitExpression",
  "AsmTypeExpression",
  "AsmOffsetExpression",
  "AsmSegExpression",
  "AsmPostBracketExpression",
  "AsmBracketExpression",
  "AsmLocalSizeExpression",
  "AsmRegisterExpression",

  # Types:
  "IllegalType",
  "IntegralType",
  "QualifiedType",
  "ModuleScopeType",
  "IdentifierType",
  "TypeofType",
  "TemplateInstanceType",
  "PointerType",
  "ArrayType",
  "FunctionType",
  "DelegateType",
  "CFuncPointerType",
  "BaseClassType",
  "ConstType", # D2.0
  "InvariantType", # D2.0

  # Parameters:
  "Parameter",
  "Parameters",
  "TemplateAliasParameter",
  "TemplateTypeParameter",
  "TemplateThisParameter", # D2.0
  "TemplateValueParameter",
  "TemplateTupleParameter",
  "TemplateParameters",
  "TemplateArguments",
)

def main():
  this_dir = Path(__file__).folder
  f = (this_dir/"nodes.py").open("w")

  f.write("""# -*- coding: utf-8 -*-
# Author: Aziz Köksal

class Node:
  kind = None
  def __init__(self, *args):
    self.m = args[:-1]
    self.pos = args[-1]

""")

  i = 0
  for n in nodes_info:
    # Write a class that inherits from Node.
    f.write("class %s(Node):\n  kind = %d\n" % (n, i))
    # Write an alias.
    f.write("N%s = %s\n\n" % (i, n))
    i += 1

if __name__ == '__main__':
  main()
