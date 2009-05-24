# -*- coding: utf-8 -*-
# Author: Aziz Köksal

class Node:
  kind = None
  def __init__(self, *args):
    self.m = args[:-1]
    self.pos = args[-1]

class CompoundDeclaration(Node):
  kind = 0
N0 = CompoundDeclaration

class EmptyDeclaration(Node):
  kind = 1
N1 = EmptyDeclaration

class IllegalDeclaration(Node):
  kind = 2
N2 = IllegalDeclaration

class ModuleDeclaration(Node):
  kind = 3
N3 = ModuleDeclaration

class ImportDeclaration(Node):
  kind = 4
N4 = ImportDeclaration

class AliasDeclaration(Node):
  kind = 5
N5 = AliasDeclaration

class AliasThisDeclaration(Node):
  kind = 6
N6 = AliasThisDeclaration

class TypedefDeclaration(Node):
  kind = 7
N7 = TypedefDeclaration

class EnumDeclaration(Node):
  kind = 8
N8 = EnumDeclaration

class EnumMemberDeclaration(Node):
  kind = 9
N9 = EnumMemberDeclaration

class ClassDeclaration(Node):
  kind = 10
N10 = ClassDeclaration

class InterfaceDeclaration(Node):
  kind = 11
N11 = InterfaceDeclaration

class StructDeclaration(Node):
  kind = 12
N12 = StructDeclaration

class UnionDeclaration(Node):
  kind = 13
N13 = UnionDeclaration

class ConstructorDeclaration(Node):
  kind = 14
N14 = ConstructorDeclaration

class StaticConstructorDeclaration(Node):
  kind = 15
N15 = StaticConstructorDeclaration

class DestructorDeclaration(Node):
  kind = 16
N16 = DestructorDeclaration

class StaticDestructorDeclaration(Node):
  kind = 17
N17 = StaticDestructorDeclaration

class FunctionDeclaration(Node):
  kind = 18
N18 = FunctionDeclaration

class VariablesDeclaration(Node):
  kind = 19
N19 = VariablesDeclaration

class InvariantDeclaration(Node):
  kind = 20
N20 = InvariantDeclaration

class UnittestDeclaration(Node):
  kind = 21
N21 = UnittestDeclaration

class DebugDeclaration(Node):
  kind = 22
N22 = DebugDeclaration

class VersionDeclaration(Node):
  kind = 23
N23 = VersionDeclaration

class StaticIfDeclaration(Node):
  kind = 24
N24 = StaticIfDeclaration

class StaticAssertDeclaration(Node):
  kind = 25
N25 = StaticAssertDeclaration

class TemplateDeclaration(Node):
  kind = 26
N26 = TemplateDeclaration

class NewDeclaration(Node):
  kind = 27
N27 = NewDeclaration

class DeleteDeclaration(Node):
  kind = 28
N28 = DeleteDeclaration

class ProtectionDeclaration(Node):
  kind = 29
N29 = ProtectionDeclaration

class StorageClassDeclaration(Node):
  kind = 30
N30 = StorageClassDeclaration

class LinkageDeclaration(Node):
  kind = 31
N31 = LinkageDeclaration

class AlignDeclaration(Node):
  kind = 32
N32 = AlignDeclaration

class PragmaDeclaration(Node):
  kind = 33
N33 = PragmaDeclaration

class MixinDeclaration(Node):
  kind = 34
N34 = MixinDeclaration

class CompoundStatement(Node):
  kind = 35
N35 = CompoundStatement

class IllegalStatement(Node):
  kind = 36
N36 = IllegalStatement

class EmptyStatement(Node):
  kind = 37
N37 = EmptyStatement

class FuncBodyStatement(Node):
  kind = 38
N38 = FuncBodyStatement

class ScopeStatement(Node):
  kind = 39
N39 = ScopeStatement

class LabeledStatement(Node):
  kind = 40
N40 = LabeledStatement

class ExpressionStatement(Node):
  kind = 41
N41 = ExpressionStatement

class DeclarationStatement(Node):
  kind = 42
N42 = DeclarationStatement

class IfStatement(Node):
  kind = 43
N43 = IfStatement

class WhileStatement(Node):
  kind = 44
N44 = WhileStatement

class DoWhileStatement(Node):
  kind = 45
N45 = DoWhileStatement

class ForStatement(Node):
  kind = 46
N46 = ForStatement

class ForeachStatement(Node):
  kind = 47
N47 = ForeachStatement

class ForeachRangeStatement(Node):
  kind = 48
N48 = ForeachRangeStatement

class SwitchStatement(Node):
  kind = 49
N49 = SwitchStatement

class CaseStatement(Node):
  kind = 50
N50 = CaseStatement

class DefaultStatement(Node):
  kind = 51
N51 = DefaultStatement

class ContinueStatement(Node):
  kind = 52
N52 = ContinueStatement

class BreakStatement(Node):
  kind = 53
N53 = BreakStatement

class ReturnStatement(Node):
  kind = 54
N54 = ReturnStatement

class GotoStatement(Node):
  kind = 55
N55 = GotoStatement

class WithStatement(Node):
  kind = 56
N56 = WithStatement

class SynchronizedStatement(Node):
  kind = 57
N57 = SynchronizedStatement

class TryStatement(Node):
  kind = 58
N58 = TryStatement

class CatchStatement(Node):
  kind = 59
N59 = CatchStatement

class FinallyStatement(Node):
  kind = 60
N60 = FinallyStatement

class ScopeGuardStatement(Node):
  kind = 61
N61 = ScopeGuardStatement

class ThrowStatement(Node):
  kind = 62
N62 = ThrowStatement

class VolatileStatement(Node):
  kind = 63
N63 = VolatileStatement

class AsmBlockStatement(Node):
  kind = 64
N64 = AsmBlockStatement

class AsmStatement(Node):
  kind = 65
N65 = AsmStatement

class AsmAlignStatement(Node):
  kind = 66
N66 = AsmAlignStatement

class IllegalAsmStatement(Node):
  kind = 67
N67 = IllegalAsmStatement

class PragmaStatement(Node):
  kind = 68
N68 = PragmaStatement

class MixinStatement(Node):
  kind = 69
N69 = MixinStatement

class StaticIfStatement(Node):
  kind = 70
N70 = StaticIfStatement

class StaticAssertStatement(Node):
  kind = 71
N71 = StaticAssertStatement

class DebugStatement(Node):
  kind = 72
N72 = DebugStatement

class VersionStatement(Node):
  kind = 73
N73 = VersionStatement

class IllegalExpression(Node):
  kind = 74
N74 = IllegalExpression

class CondExpression(Node):
  kind = 75
N75 = CondExpression

class CommaExpression(Node):
  kind = 76
N76 = CommaExpression

class OrOrExpression(Node):
  kind = 77
N77 = OrOrExpression

class AndAndExpression(Node):
  kind = 78
N78 = AndAndExpression

class OrExpression(Node):
  kind = 79
N79 = OrExpression

class XorExpression(Node):
  kind = 80
N80 = XorExpression

class AndExpression(Node):
  kind = 81
N81 = AndExpression

class EqualExpression(Node):
  kind = 82
N82 = EqualExpression

class IdentityExpression(Node):
  kind = 83
N83 = IdentityExpression

class RelExpression(Node):
  kind = 84
N84 = RelExpression

class InExpression(Node):
  kind = 85
N85 = InExpression

class LShiftExpression(Node):
  kind = 86
N86 = LShiftExpression

class RShiftExpression(Node):
  kind = 87
N87 = RShiftExpression

class URShiftExpression(Node):
  kind = 88
N88 = URShiftExpression

class PlusExpression(Node):
  kind = 89
N89 = PlusExpression

class MinusExpression(Node):
  kind = 90
N90 = MinusExpression

class CatExpression(Node):
  kind = 91
N91 = CatExpression

class MulExpression(Node):
  kind = 92
N92 = MulExpression

class DivExpression(Node):
  kind = 93
N93 = DivExpression

class ModExpression(Node):
  kind = 94
N94 = ModExpression

class AssignExpression(Node):
  kind = 95
N95 = AssignExpression

class LShiftAssignExpression(Node):
  kind = 96
N96 = LShiftAssignExpression

class RShiftAssignExpression(Node):
  kind = 97
N97 = RShiftAssignExpression

class URShiftAssignExpression(Node):
  kind = 98
N98 = URShiftAssignExpression

class OrAssignExpression(Node):
  kind = 99
N99 = OrAssignExpression

class AndAssignExpression(Node):
  kind = 100
N100 = AndAssignExpression

class PlusAssignExpression(Node):
  kind = 101
N101 = PlusAssignExpression

class MinusAssignExpression(Node):
  kind = 102
N102 = MinusAssignExpression

class DivAssignExpression(Node):
  kind = 103
N103 = DivAssignExpression

class MulAssignExpression(Node):
  kind = 104
N104 = MulAssignExpression

class ModAssignExpression(Node):
  kind = 105
N105 = ModAssignExpression

class XorAssignExpression(Node):
  kind = 106
N106 = XorAssignExpression

class CatAssignExpression(Node):
  kind = 107
N107 = CatAssignExpression

class AddressExpression(Node):
  kind = 108
N108 = AddressExpression

class PreIncrExpression(Node):
  kind = 109
N109 = PreIncrExpression

class PreDecrExpression(Node):
  kind = 110
N110 = PreDecrExpression

class PostIncrExpression(Node):
  kind = 111
N111 = PostIncrExpression

class PostDecrExpression(Node):
  kind = 112
N112 = PostDecrExpression

class DerefExpression(Node):
  kind = 113
N113 = DerefExpression

class SignExpression(Node):
  kind = 114
N114 = SignExpression

class NotExpression(Node):
  kind = 115
N115 = NotExpression

class CompExpression(Node):
  kind = 116
N116 = CompExpression

class CallExpression(Node):
  kind = 117
N117 = CallExpression

class NewExpression(Node):
  kind = 118
N118 = NewExpression

class NewAnonClassExpression(Node):
  kind = 119
N119 = NewAnonClassExpression

class DeleteExpression(Node):
  kind = 120
N120 = DeleteExpression

class CastExpression(Node):
  kind = 121
N121 = CastExpression

class IndexExpression(Node):
  kind = 122
N122 = IndexExpression

class SliceExpression(Node):
  kind = 123
N123 = SliceExpression

class ModuleScopeExpression(Node):
  kind = 124
N124 = ModuleScopeExpression

class IdentifierExpression(Node):
  kind = 125
N125 = IdentifierExpression

class SpecialTokenExpression(Node):
  kind = 126
N126 = SpecialTokenExpression

class DotExpression(Node):
  kind = 127
N127 = DotExpression

class TemplateInstanceExpression(Node):
  kind = 128
N128 = TemplateInstanceExpression

class ThisExpression(Node):
  kind = 129
N129 = ThisExpression

class SuperExpression(Node):
  kind = 130
N130 = SuperExpression

class NullExpression(Node):
  kind = 131
N131 = NullExpression

class DollarExpression(Node):
  kind = 132
N132 = DollarExpression

class BoolExpression(Node):
  kind = 133
N133 = BoolExpression

class IntExpression(Node):
  kind = 134
N134 = IntExpression

class RealExpression(Node):
  kind = 135
N135 = RealExpression

class ComplexExpression(Node):
  kind = 136
N136 = ComplexExpression

class CharExpression(Node):
  kind = 137
N137 = CharExpression

class StringExpression(Node):
  kind = 138
N138 = StringExpression

class ArrayLiteralExpression(Node):
  kind = 139
N139 = ArrayLiteralExpression

class AArrayLiteralExpression(Node):
  kind = 140
N140 = AArrayLiteralExpression

class AssertExpression(Node):
  kind = 141
N141 = AssertExpression

class MixinExpression(Node):
  kind = 142
N142 = MixinExpression

class ImportExpression(Node):
  kind = 143
N143 = ImportExpression

class TypeofExpression(Node):
  kind = 144
N144 = TypeofExpression

class TypeDotIdExpression(Node):
  kind = 145
N145 = TypeDotIdExpression

class TypeidExpression(Node):
  kind = 146
N146 = TypeidExpression

class IsExpression(Node):
  kind = 147
N147 = IsExpression

class ParenExpression(Node):
  kind = 148
N148 = ParenExpression

class FunctionLiteralExpression(Node):
  kind = 149
N149 = FunctionLiteralExpression

class TraitsExpression(Node):
  kind = 150
N150 = TraitsExpression

class VoidInitExpression(Node):
  kind = 151
N151 = VoidInitExpression

class ArrayInitExpression(Node):
  kind = 152
N152 = ArrayInitExpression

class StructInitExpression(Node):
  kind = 153
N153 = StructInitExpression

class AsmTypeExpression(Node):
  kind = 154
N154 = AsmTypeExpression

class AsmOffsetExpression(Node):
  kind = 155
N155 = AsmOffsetExpression

class AsmSegExpression(Node):
  kind = 156
N156 = AsmSegExpression

class AsmPostBracketExpression(Node):
  kind = 157
N157 = AsmPostBracketExpression

class AsmBracketExpression(Node):
  kind = 158
N158 = AsmBracketExpression

class AsmLocalSizeExpression(Node):
  kind = 159
N159 = AsmLocalSizeExpression

class AsmRegisterExpression(Node):
  kind = 160
N160 = AsmRegisterExpression

class IllegalType(Node):
  kind = 161
N161 = IllegalType

class IntegralType(Node):
  kind = 162
N162 = IntegralType

class QualifiedType(Node):
  kind = 163
N163 = QualifiedType

class ModuleScopeType(Node):
  kind = 164
N164 = ModuleScopeType

class IdentifierType(Node):
  kind = 165
N165 = IdentifierType

class TypeofType(Node):
  kind = 166
N166 = TypeofType

class TemplateInstanceType(Node):
  kind = 167
N167 = TemplateInstanceType

class PointerType(Node):
  kind = 168
N168 = PointerType

class ArrayType(Node):
  kind = 169
N169 = ArrayType

class FunctionType(Node):
  kind = 170
N170 = FunctionType

class DelegateType(Node):
  kind = 171
N171 = DelegateType

class CFuncPointerType(Node):
  kind = 172
N172 = CFuncPointerType

class BaseClassType(Node):
  kind = 173
N173 = BaseClassType

class ConstType(Node):
  kind = 174
N174 = ConstType

class InvariantType(Node):
  kind = 175
N175 = InvariantType

class Parameter(Node):
  kind = 176
N176 = Parameter

class Parameters(Node):
  kind = 177
N177 = Parameters

class TemplateAliasParameter(Node):
  kind = 178
N178 = TemplateAliasParameter

class TemplateTypeParameter(Node):
  kind = 179
N179 = TemplateTypeParameter

class TemplateThisParameter(Node):
  kind = 180
N180 = TemplateThisParameter

class TemplateValueParameter(Node):
  kind = 181
N181 = TemplateValueParameter

class TemplateTupleParameter(Node):
  kind = 182
N182 = TemplateTupleParameter

class TemplateParameters(Node):
  kind = 183
N183 = TemplateParameters

class TemplateArguments(Node):
  kind = 184
N184 = TemplateArguments

