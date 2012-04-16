/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.lexer.TokenSerializer;

import dil.lexer.Identifier,
       dil.lexer.IdTable,
       dil.lexer.Funcs,
       dil.lexer.Token;
import dil.Location;
import dil.Float : Float;
import common;

/// Serializes a linked list of tokens to a buffer.
/// $(BNF
//// FileFormat := Header IdArray Tokens
////     Header := "DIL1.0TOKS\x1A\x04\n"
////    IdArray := "Ids:" IdCount IdElement* "\n"
////  IdElement := AbsOffset IdLength
////     Tokens := "Toks:" TokenCount BodyLength (IdTok | OtherTok)+ "\n"
////      IdTok := TOK RelOffset IdIndex
////   OtherTok := TOK RelOffset TokenLength
////    IdCount := 2B # Number of elements in IdArray (=Identifier*[].)
////  AbsOffset := 4B # Absolute offset from the beginning of the source text.
////   IdLength := 2B # The length of the identifier.
//// TokenCount := 4B # Number of tokens (including EOF.)
//// BodyLength := 4B # Total length of the token data.
////        TOK := 1B # The token kind.
////  RelOffset := 2B # Relative offset to previous token (=whitespace.)
////    IdIndex := 2B # Index into IdArray.
////TokenLength := 2B # Length of the token's text.
////         1B := 1Byte
////         2B := 2Bytes
////         4B := 4Bytes
////)
struct TokenSerializer
{
static:
  immutable string HEADER = "DIL1.0TOKS\x1A\x04\n";

  ubyte[] serialize(Token* first_token)
  {
    ubyte[] data;

    void writeS(cstring x)
    {
      data ~= cast(const(ubyte)[])x;
    }
    void write1B(ubyte x)
    {
      data ~= x;
    }
    void write2B(ushort x)
    {
      data ~= (cast(ubyte*)&x)[0..2];
    }
    void write4B(uint x)
    {
      data ~= (cast(ubyte*)&x)[0..4];
    }

    Token*[] idents; // List of all unique ids in this file.
    size_t[hash_t] idtable; // Table of ids seen so far.
                            // Maps the id hash to an index into idents.
    auto t = first_token; // Get first token.
    auto prev_end = t.prev.end; // End of the previous token.
    uint token_count; // The number of tokens in this file.

    for (; t; t = t.next)
    {
      token_count++;
      switch (t.kind)
      {
      case TOK.Identifier:
        // Format: <1B:TOK><2B:OffsToStart><2B:IdentsIndex>
        auto hash = hashOf(t.ident.str);
        auto pindex = hash in idtable;
        size_t id_index;
        if (!pindex)
          (id_index = idents.length),
          (idents ~= t),
          (idtable[hash] = id_index);
        else
          id_index = *pindex;
        // Write the bytes.
        write1B(cast(ubyte)t.kind); // TOK
        write2B(cast(ushort)(t.start - prev_end)); // OffsetToStart
        write2B(cast(ushort)id_index); // IdentsIndex
        break;
      // case TOK.Newline:
      //   break;
      // case TOK.String:
      //   break;
      // case TOK.HashLine:
      //   break;
      default:
        // Format: <1B:TOK><2B:OffsetToStart><2B:TokenLength>
        write1B(cast(ubyte)t.kind); // TOK
        write2B(cast(ushort)(t.start - prev_end)); // OffsetToStart
        write2B(cast(ushort)(t.end - t.start)); // TokenLength
      }
      prev_end = t.end;
    }

    ubyte[] data_body = data;
    data = null;
    // Write file header.
    writeS(HEADER);
    writeS("Ids:");
    write2B(cast(ushort)idents.length);
    auto text_begin = first_token.prev.end;
    foreach (id; idents)
      write4B(cast(uint)(id.start - text_begin)),
      write2B(cast(ushort)(id.end - id.start));
    writeS("\n");
    writeS("Toks:");
    write4B(token_count);
    write4B(cast(uint)data_body.length);
    data ~= data_body;
    writeS("\n");
    return data;
  }

  Token[] deserialize(ubyte[] data, cstring srcText, IdTable idtable,
    bool delegate(Token* next_token) callback)
  {
    ubyte* p = data.ptr;
    ubyte* end = data.ptr + data.length;

    // Define nested functions for reading data and advancing the pointer.
    bool match(string x)
    {
      return p+x.length <= end &&
        p[0..x.length] == cast(immutable(ubyte)[])x &&
        ((p += x.length), 1);
    }
    bool read(ref char[] x, uint len)
    {
      return p+len <= end && ((x = (cast(char*)p)[0..len]), (p += len), 1);
    }
    bool read2B(ref uint x)
    {
      return p+1 < end && ((x = *cast(ushort*)p), (p += 2), 1);
    }
    bool read4B(ref uint x)
    {
      return p+3 < end && ((x = *cast(uint*)p), (p += 4), 1);
    }
    Identifier* readID()
    {
      uint id_begin = void, id_len = void;
      if (!read4B(id_begin) || !read2B(id_len) ||
          id_begin+id_len > srcText.length) return null;
      auto id_str = srcText[id_begin .. id_begin + id_len];
      if (!IdTable.isIdentifierString(id_str)) return null;
      return idtable.lookup(id_str);
    }

    if (srcText.length == 0) goto Lerr;

    Token[] tokens;
    Identifier*[] idents;

    if (!match(HEADER)) goto Lerr;

    if (!match("Ids:")) goto Lerr;

    uint id_count = void;
    if (!read2B(id_count)) goto Lerr;
    idents = new Identifier*[id_count];

    for (uint i; i < id_count; i++)
      if (auto id = readID())
        idents[i] = id;
      else
        goto Lerr;

    if (!match("\nToks:")) goto Lerr;

    uint token_count = void;
    if (!read4B(token_count)) goto Lerr;

    uint body_length = void;
    if (!read4B(body_length)) goto Lerr;
    if (p + body_length + 1 != end) goto Lerr;
    if (*(p + body_length) != '\n') goto Lerr; // Terminated with '\n'.

    // We can allocate the exact amount of tokens we need.
    tokens = new Token[token_count];
    Token* token = &tokens[0];
    auto prev_end = srcText.ptr;
    auto src_end = srcText.ptr+srcText.length;

    // Main loop that reads and initializes the tokens.
    while (p < end && token_count)
    {
      token.kind = cast(TOK)*p++;
      if (token.kind >= TOK.MAX) goto Lerr;

      uint offs_start = void;
      if (!read2B(offs_start)) goto Lerr;
      if (offs_start)
        token.ws = prev_end;
      token.start = prev_end + offs_start;
      if (token.start >= src_end) goto Lerr;

      uint token_len = void;
      switch (token.kind)
      {
      case TOK.Identifier:
        uint index = void;
        if (!read2B(index) && index < idents.length) goto Lerr;
        token.ident = idents[index];
        token_len = cast(uint)token.ident.str.length;
        break;
      default:
        if (!read2B(token_len)) goto Lerr;
      }
      // Set token.end.
      token.end = prev_end = token.start + token_len;
      if (prev_end > src_end) goto Lerr;
      // Pass the token back to the client.
      if (!callback(token))
        goto Lerr;
      // Advance the pointer to the next token in the array.
      token++;
      token_count--;
    }
    assert(token == tokens.ptr + tokens.length, "token pointer not at end");
    token--; // Go back to the last token.

    if (token.kind != TOK.EOF) // Last token must be EOF.
      goto Lerr;

    return tokens;
  Lerr:
    delete tokens;
    delete idents;
    // delete data; // Not owned by this function.
    return null;
  }
}
