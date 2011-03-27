/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.i18n.Messages;

import common;

/// Enumeration of indices into the table of compiler messages.
enum MID
{
  // Lexer messages:
  IllegalCharacter,
//   InvalidUnicodeCharacter,
  InvalidUTF8Sequence,
  // ''
  UnterminatedCharacterLiteral,
  EmptyCharacterLiteral,
  // #line
  ExpectedIdentifierSTLine,
  ExpectedIntegerAfterSTLine,
//   ExpectedFilespec,
  UnterminatedFilespec,
  UnterminatedSpecialToken,
  // ""
  UnterminatedString,
  // x""
  NonHexCharInHexString,
  OddNumberOfDigitsInHexString,
  UnterminatedHexString,
  // /* */ /+ +/
  UnterminatedBlockComment,
  UnterminatedNestedComment,
  // `` r""
  UnterminatedRawString,
  UnterminatedBackQuoteString,
  // \x \u \U
  UndefinedEscapeSequence,
  InvalidUnicodeEscapeSequence,
  InsufficientHexDigits,
  // \&[a-zA-Z][a-zA-Z0-9]+;
  UndefinedHTMLEntity,
  UnterminatedHTMLEntity,
  InvalidBeginHTMLEntity,
  // integer overflows
  OverflowDecimalSign,
  OverflowDecimalNumber,
  OverflowHexNumber,
  OverflowBinaryNumber,
  OverflowOctalNumber,
  OverflowFloatNumber,
  OctalNumberHasDecimals,
  NoDigitsInHexNumber,
  NoDigitsInBinNumber,
  HexFloatExponentRequired,
  HexFloatExpMustStartWithDigit,
  FloatExpMustStartWithDigit,
  CantReadFile,
  InexistantFile,
  InvalidOctalEscapeSequence,
  InvalidModuleName,
  DelimiterIsWhitespace,
  DelimiterIsMissing,
  NoNewlineAfterIdDelimiter,
  UnterminatedDelimitedString,
  ExpectedDblQuoteAfterDelim,
  UnterminatedTokenString,

  // Parser messages:
  ExpectedButFound,
  RedundantStorageClass,
  TemplateTupleParameter,
  InContract,
  OutContract,
  MissingLinkageType,
  UnrecognizedLinkageType,
  ExpectedBaseClasses,
  BaseClassInForwardDeclaration,
  InvalidUTF8SequenceInString,
  ModuleDeclarationNotFirst,
  StringPostfixMismatch,
  UnexpectedIdentInType,
  ExpectedIdAfterTypeDot,
  ExpectedModuleIdentifier,
  IllegalDeclaration,
  ExpectedModuleType,
  ExpectedFunctionName,
  ExpectedVariableName,
  ExpectedFunctionBody,
  RedundantLinkageType,
  RedundantProtection,
  ExpectedPragmaIdentifier,
  ExpectedAliasModuleName,
  ExpectedAliasImportName,
  ExpectedImportName,
  ExpectedEnumMember,
  ExpectedEnumBody,
  ExpectedClassName,
  ExpectedClassBody,
  ExpectedInterfaceName,
  ExpectedInterfaceBody,
  ExpectedStructBody,
  ExpectedUnionBody,
  ExpectedTemplateName,
  ExpectedAnIdentifier,
  IllegalStatement,
  ExpectedNonEmptyStatement,
  ExpectedScopeIdentifier,
  InvalidScopeIdentifier,
  ExpectedLinkageIdentifier,
  ExpectedAttributeId,
  UnrecognizedAttribute,
  ExpectedIntegerAfterAlign,
  IllegalAsmStatement,
  IllegalAsmBinaryOp,
  ExpectedDeclaratorIdentifier,
  ExpectedTemplateParameters,
  ExpectedTypeOrExpression,
  ExpectedAliasTemplateParam,
  ExpectedNameForThisTempParam,
  ExpectedIdentOrInt,
  MissingCatchOrFinally,
  ExpectedClosing,
  AliasHasInitializer,
  AliasExpectsVariable,
  TypedefExpectsVariable,
  CaseRangeStartExpression,
  ExpectedParamDefValue,
  IllegalVariadicParam,
  ParamsAfterVariadic,

  // Help messages:
  UnknownCommand,
  HelpMain,
  HelpCompile,
  HelpPytree,
  HelpDdoc,
  HelpHighlight,
  HelpImportGraph,
  HelpTokenize,
  HelpDlexed,
  HelpStatistics,
  HelpTranslate,
  HelpSettings,
  HelpHelp,
}


/// Collection of error messages with no MID yet.
struct MSG
{
static:
  // Converter:
  auto InvalidUTF16Character = "invalid UTF-16 character '\\u{:X4}'.";
  auto InvalidUTF32Character = "invalid UTF-32 character '\\U{:X8}'.";
  auto UTF16FileMustBeDivisibleBy2 = "the byte length of a UTF-16 source file must be divisible by 2.";
  auto UTF32FileMustBeDivisibleBy4 = "the byte length of a UTF-32 source file must be divisible by 4.";
  // DDoc messages:
  auto UndefinedDDocMacro = "DDoc macro ‘{}’ is undefined";
  auto UnterminatedDDocMacro = "DDoc macro ‘{}’ has no closing ‘)’";
  auto UndocumentedSymbol = "undocumented symbol";
  auto EmptyDDocComment = "empty comment";
  auto MissingParamsSection = "missing params section";
  auto UndocumentedParam = "undocumented parameter ‘{}’";

  // Semantic analysis:
  auto CouldntLoadModule = "couldn’t find module file ‘{}’";
  auto ConflictingModuleFiles = "module is in conflict with module ‘{}’";
  auto ConflictingModuleAndPackage = "module is in conflict with package ‘{}’";
  auto ConflictingPackageAndModule = "package ‘{0}’ is in conflict with module ‘{0}’";
  auto ModuleNotInPackage = "expected module to be in package ‘{}’";
  auto UndefinedIdentifier = "undefined identifier ‘{}’";
  auto DeclConflictsWithDecl = "declaration ‘{}’ conflicts with declaration @{}";
  auto VariableConflictsWithDecl = "variable ‘{}’ conflicts with declaration @{}";
  auto InterfaceCantHaveVariables = "an interface can't have member variables";
  auto MixinArgumentMustBeString = "the mixin argument must evaluate to a string";
  auto DebugSpecModuleLevel = "debug={} must be at module level";
  auto VersionSpecModuleLevel = "version={} must be at module level";
}
