/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity low)
module dil.ast.ASTPrinter;


import dil.ast.Visitor,
       dil.ast.NodeMembers,
       dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions,
       dil.ast.Statements,
       dil.ast.Types,
       dil.ast.Parameters;

import common;

class ASTPrinter : Visitor2
{
  char[] text;
  Token*[] tokens;
  bool buildTokens;

  void visit(IllegalDecl n)
  {
  }

  void visit(CompoundDecl n)
  {
  }

  void visit(EmptyDecl n)
  {
  }

  void visit(ModuleDecl n)
  {
  }

  void visit(ImportDecl n)
  {
  }

  void visit(AliasDecl n)
  {
  }

  void visit(AliasThisDecl n)
  {
  }

  void visit(TypedefDecl n)
  {
  }

  void visit(EnumDecl n)
  {
  }

  void visit(EnumMemberDecl n)
  {
  }

  void visit(TemplateDecl n)
  {
  }

  void visit(ClassDecl n)
  {
  }

  void visit(InterfaceDecl n)
  {
  }

  void visit(StructDecl n)
  {
  }

  void visit(UnionDecl n)
  {
  }

  void visit(ConstructorDecl n)
  {
  }

  void visit(StaticCtorDecl n)
  {
  }

  void visit(DestructorDecl n)
  {
  }

  void visit(StaticDtorDecl n)
  {
  }

  void visit(FunctionDecl n)
  {
  }

  void visit(VariablesDecl n)
  {
  }

  void visit(InvariantDecl n)
  {
  }

  void visit(UnittestDecl n)
  {
  }

  void visit(DebugDecl n)
  {
  }

  void visit(VersionDecl n)
  {
  }

  void visit(StaticIfDecl n)
  {
  }

  void visit(StaticAssertDecl n)
  {
  }

  void visit(NewDecl n)
  {
  }

  void visit(DeleteDecl n)
  {
  }

  void visit(ProtectionDecl n)
  {
  }

  void visit(StorageClassDecl n)
  {
  }

  void visit(LinkageDecl n)
  {
  }

  void visit(AlignDecl n)
  {
  }

  void visit(PragmaDecl n)
  {
  }

  void visit(MixinDecl n)
  {
  }


  // Statements:
  void visit(IllegalStmt n)
  {
  }

  void visit(CompoundStmt n)
  {
  }

  void visit(EmptyStmt n)
  {
  }

  void visit(FuncBodyStmt n)
  {
  }

  void visit(ScopeStmt n)
  {
  }

  void visit(LabeledStmt n)
  {
  }

  void visit(ExpressionStmt n)
  {
  }

  void visit(DeclarationStmt n)
  {
  }

  void visit(IfStmt n)
  {
  }

  void visit(WhileStmt n)
  {
  }

  void visit(DoWhileStmt n)
  {
  }

  void visit(ForStmt n)
  {
  }

  void visit(ForeachStmt n)
  {
  }

  void visit(ForeachRangeStmt n)
  {
  }
 // D2.0
  void visit(SwitchStmt n)
  {
  }

  void visit(CaseStmt n)
  {
  }

  void visit(CaseRangeStmt n)
  {
  }

  void visit(DefaultStmt n)
  {
  }

  void visit(ContinueStmt n)
  {
  }

  void visit(BreakStmt n)
  {
  }

  void visit(ReturnStmt n)
  {
  }

  void visit(GotoStmt n)
  {
  }

  void visit(WithStmt n)
  {
  }

  void visit(SynchronizedStmt n)
  {
  }

  void visit(TryStmt n)
  {
  }

  void visit(CatchStmt n)
  {
  }

  void visit(FinallyStmt n)
  {
  }

  void visit(ScopeGuardStmt n)
  {
  }

  void visit(ThrowStmt n)
  {
  }

  void visit(VolatileStmt n)
  {
  }

  void visit(AsmBlockStmt n)
  {
  }

  void visit(AsmStmt n)
  {
  }

  void visit(AsmAlignStmt n)
  {
  }

  void visit(IllegalAsmStmt n)
  {
  }

  void visit(PragmaStmt n)
  {
  }

  void visit(MixinStmt n)
  {
  }

  void visit(StaticIfStmt n)
  {
  }

  void visit(StaticAssertStmt n)
  {
  }

  void visit(DebugStmt n)
  {
  }

  void visit(VersionStmt n)
  {
  }


  // Expressions:
  void visit(IllegalExpr n)
  {
  }

  void visit(CondExpr n)
  {
  }

  void visit(CommaExpr n)
  {
  }

  void visit(OrOrExpr n)
  {
  }

  void visit(AndAndExpr n)
  {
  }

  void visit(OrExpr n)
  {
  }

  void visit(XorExpr n)
  {
  }

  void visit(AndExpr n)
  {
  }

  void visit(EqualExpr n)
  {
  }

  void visit(IdentityExpr n)
  {
  }

  void visit(RelExpr n)
  {
  }

  void visit(InExpr n)
  {
  }

  void visit(LShiftExpr n)
  {
  }

  void visit(RShiftExpr n)
  {
  }

  void visit(URShiftExpr n)
  {
  }

  void visit(PlusExpr n)
  {
  }

  void visit(MinusExpr n)
  {
  }

  void visit(CatExpr n)
  {
  }

  void visit(MulExpr n)
  {
  }

  void visit(DivExpr n)
  {
  }

  void visit(ModExpr n)
  {
  }

  void visit(PowExpr n)
  {
  }
 // D2
  void visit(AssignExpr n)
  {
  }

  void visit(LShiftAssignExpr n)
  {
  }

  void visit(RShiftAssignExpr n)
  {
  }

  void visit(URShiftAssignExpr n)
  {
  }

  void visit(OrAssignExpr n)
  {
  }

  void visit(AndAssignExpr n)
  {
  }

  void visit(PlusAssignExpr n)
  {
  }

  void visit(MinusAssignExpr n)
  {
  }

  void visit(DivAssignExpr n)
  {
  }

  void visit(MulAssignExpr n)
  {
  }

  void visit(ModAssignExpr n)
  {
  }

  void visit(XorAssignExpr n)
  {
  }

  void visit(CatAssignExpr n)
  {
  }

  void visit(PowAssignExpr n)
  {
  }
 // D2
  void visit(AddressExpr n)
  {
  }

  void visit(PreIncrExpr n)
  {
  }

  void visit(PreDecrExpr n)
  {
  }

  void visit(PostIncrExpr n)
  {
  }

  void visit(PostDecrExpr n)
  {
  }

  void visit(DerefExpr n)
  {
  }

  void visit(SignExpr n)
  {
  }

  void visit(NotExpr n)
  {
  }

  void visit(CompExpr n)
  {
  }

  void visit(CallExpr n)
  {
  }

  void visit(NewExpr n)
  {
  }

  void visit(NewClassExpr n)
  {
  }

  void visit(DeleteExpr n)
  {
  }

  void visit(CastExpr n)
  {
  }

  void visit(IndexExpr n)
  {
  }

  void visit(SliceExpr n)
  {
  }

  void visit(ModuleScopeExpr n)
  {
  }

  void visit(IdentifierExpr n)
  {
  }

  void visit(SpecialTokenExpr n)
  {
  }

  void visit(TmplInstanceExpr n)
  {
  }

  void visit(ThisExpr n)
  {
  }

  void visit(SuperExpr n)
  {
  }

  void visit(NullExpr n)
  {
  }

  void visit(DollarExpr n)
  {
  }

  void visit(BoolExpr n)
  {
  }

  void visit(IntExpr n)
  {
  }

  void visit(FloatExpr n)
  {
  }

  void visit(ComplexExpr n)
  {
  }

  void visit(CharExpr n)
  {
  }

  void visit(StringExpr n)
  {
  }

  void visit(ArrayLiteralExpr n)
  {
  }

  void visit(AArrayLiteralExpr n)
  {
  }

  void visit(AssertExpr n)
  {
  }

  void visit(MixinExpr n)
  {
  }

  void visit(ImportExpr n)
  {
  }

  void visit(TypeofExpr n)
  {
  }

  void visit(TypeDotIdExpr n)
  {
  }

  void visit(TypeidExpr n)
  {
  }

  void visit(IsExpr n)
  {
  }

  void visit(ParenExpr n)
  {
  }

  void visit(FuncLiteralExpr n)
  {
  }

  void visit(TraitsExpr n)
  {
  }
 // D2.0
  void visit(VoidInitExpr n)
  {
  }

  void visit(ArrayInitExpr n)
  {
  }

  void visit(StructInitExpr n)
  {
  }

  void visit(AsmTypeExpr n)
  {
  }

  void visit(AsmOffsetExpr n)
  {
  }

  void visit(AsmSegExpr n)
  {
  }

  void visit(AsmPostBracketExpr n)
  {
  }

  void visit(AsmBracketExpr n)
  {
  }

  void visit(AsmLocalSizeExpr n)
  {
  }

  void visit(AsmRegisterExpr n)
  {
  }


  // Types:
  void visit(IllegalType n)
  {
  }

  void visit(IntegralType n)
  {
  }

  void visit(ModuleScopeType n)
  {
  }

  void visit(IdentifierType n)
  {
  }

  void visit(TypeofType n)
  {
  }

  void visit(TemplateInstanceType n)
  {
  }

  void visit(PointerType n)
  {
  }

  void visit(ArrayType n)
  {
  }

  void visit(FunctionType n)
  {
  }

  void visit(DelegateType n)
  {
  }

  void visit(CFuncType n)
  {
  }

  void visit(BaseClassType n)
  {
  }

  void visit(ConstType n)
  {
  }
 // D2.0
  void visit(ImmutableType n)
  {
  }
 // D2.0
  void visit(InoutType n)
  {
  }
 // D2.0
  void visit(SharedType n)
  {
  }
 // D2.0

  // Parameters:
  void visit(Parameter n)
  {
  }

  void visit(Parameters n)
  {
  }

  void visit(TemplateAliasParam n)
  {
  }

  void visit(TemplateTypeParam n)
  {
  }

  void visit(TemplateThisParam n)
  {
  }
 // D2.0
  void visit(TemplateValueParam n)
  {
  }

  void visit(TemplateTupleParam n)
  {
  }

  void visit(TemplateParameters n)
  {
  }

  void visit(TemplateArguments n)
  {
  }
}
