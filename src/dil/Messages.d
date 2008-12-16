/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.Messages;

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

  // Help messages:
  HelpMain,
  HelpGenerate,
  HelpImportGraph,
}

/// The table of compiler messages.
private string[] g_compilerMessages;

static this()
{
  g_compilerMessages = new string[MID.max+1];
}

/// Sets the compiler messages.
void SetMessages(string[] msgs)
{
  assert(MID.max+1 == msgs.length);
  g_compilerMessages = msgs;
}

/// Returns the compiler message for mid.
string GetMsg(MID mid)
{
  assert(mid < g_compilerMessages.length);
  return g_compilerMessages[mid];
}

/// Returns a formatted string.
char[] FormatMsg(MID mid, ...)
{
  return Format(_arguments, _argptr, GetMsg(mid));
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
  // DDoc macros:
  auto UndefinedDDocMacro = "DDoc macro '{}' is undefined";
  auto UnterminatedDDocMacro = "DDoc macro '{}' has no closing ')'";
  // Lexer messages:
  auto CantReadFile = "can't read module file";
  auto InexistantFile = "module file doesn't exist";
  auto InvalidOctalEscapeSequence = "value of octal escape sequence is greater than 0xFF: '{}'";
  auto InvalidModuleName = "the file name '{}' can't be used as a module name; it's an invalid or reserved D identifier.";
  // Parser messages:
  auto InvalidUTF8SequenceInString = "invalid UTF-8 sequence in string literal: '{0}'";
  auto ModuleDeclarationNotFirst = "a module declaration is only allowed as the first declaration in a file";
  auto StringPostfixMismatch = "string literal has mistmatching postfix character";
  auto ExpectedIdAfterTypeDot = "expected identifier after '(Type).', not '{}'";
  auto ExpectedModuleIdentifier = "expected module identifier, not '{}'";
  auto IllegalDeclaration = "illegal declaration found: {}";
  auto ExpectedFunctionName = "expected function name, not '{}'";
  auto ExpectedVariableName = "expected variable name, not '{}'";
  auto ExpectedFunctionBody = "expected function body, not '{}'";
  auto RedundantLinkageType = "redundant linkage type: {}";
  auto ExpectedPragmaIdentifier = "expected pragma identifier, not '{}'";
  auto ExpectedAliasModuleName = "expected alias module name, not '{}'";
  auto ExpectedAliasImportName = "expected alias name, not '{}'";
  auto ExpectedImportName = "expected an identifier, not '{}'";
  auto ExpectedEnumMember = "expected enum member, not '{}'";
  auto ExpectedEnumBody = "expected enum body, not '{}'";
  auto ExpectedClassName = "expected class name, not '{}'";
  auto ExpectedClassBody = "expected class body, not '{}'";
  auto ExpectedInterfaceName = "expected interface name, not '{}'";
  auto ExpectedInterfaceBody = "expected interface body, not '{}'";
  auto ExpectedStructBody = "expected struct body, not '{}'";
  auto ExpectedUnionBody = "expected union body, not '{}'";
  auto ExpectedTemplateName = "expected template name, not '{}'";
  auto ExpectedAnIdentifier = "expected an identifier, not '{}'";
  auto IllegalStatement = "illegal statement found: {}";
  auto ExpectedNonEmptyStatement = "didn't expect ';', use {{ } instead";
  auto ExpectedScopeIdentifier = "expected 'exit', 'success' or 'failure', not '{}'";
  auto InvalidScopeIdentifier = "'exit', 'success', 'failure' are valid scope identifiers, but not '{}'";
  auto ExpectedIntegerAfterAlign = "expected an integer after align, not '{}'";
  auto IllegalAsmStatement = "illegal asm statement found: {}";
  auto ExpectedDeclaratorIdentifier = "expected declarator identifier, not '{}'";
  auto ExpectedTemplateParameters = "expected one or more template parameters, not ')'";
  auto ExpectedTypeOrExpression = "expected a type or and expression, not ')'";
  auto ExpectedAliasTemplateParam = "expected name for alias template parameter, not '{}'";
  auto ExpectedNameForThisTempParam = "expected name for 'this' template parameter, not '{}'";
  auto ExpectedIdentOrInt = "expected an identifier or an integer, not '{}'";
  auto MissingCatchOrFinally = "try statement is missing a catch or finally body.";
  auto ExpectedClosing = "expected closing '{}' {}, not '{}'";
  // Semantic analysis:
  auto CouldntLoadModule = "couldn't import module '{}'";
  auto ConflictingModuleFiles = "module is in conflict with module '{}'";
  auto ConflictingModuleAndPackage = "module is in conflict with package '{}'";
  auto ModuleNotInPackage = "expected module to be in package '{}'";
  auto UndefinedIdentifier = "undefined identifier '{}'";
  auto DeclConflictsWithDecl = "declaration '{}' conflicts with declaration @{}";
  auto VariableConflictsWithDecl = "variable '{}' conflicts with declaration @{}";
  auto InterfaceCantHaveVariables = "an interface can't have member variables";
  auto MixinArgumentMustBeString = "the mixin argument must evaluate to a string";
  auto DebugSpecModuleLevel = "debug={} must be at module level";
  auto VersionSpecModuleLevel = "version={} must be at module level";

  auto EnumBaseTypeInvalid = "Enum base type must be an integral type or enum";
  auto EnumMustHaveMember = "Enums must have at least one member";
  auto EnumIntegerExprExpected = "Integer expression expected";
  auto EnumMemberTypeInvalid = "Enum member type must be an integral type or enum";
  auto EnumOverflow = "The value assigned here overflows the enum type";
  auto CannotAddPointers = "Cannot add a pointer to a pointer";

}
