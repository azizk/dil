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
struct TokenSerializer
{
static:
  const string HEADER = "DIL1.0TOKS\x1A\x04\n";

  ubyte[] serialize(Token* first_token)
  {
    ubyte[] data;

    void writeS(string x)
    {
      data ~= cast(ubyte[])x;
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
    char* prev_end = t.prev.end; // End of the previous token.
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
        uint id_index;
        if (!pindex)
          (id_index = idents.length),
          (idents ~= t),
          (idtable[hash] = id_index);
        else
          id_index = *pindex;
        // Write the bytes.
        write1B(t.kind); // TOK
        write2B(t.start - prev_end); // OffsetToStart
        write2B(id_index); // IdentsIndex
        break;
      // case TOK.Newline:
      //   break;
      // case TOK.String:
      //   break;
      // case TOK.HashLine:
      //   break;
      default:
        // Format: <1B:TOK><2B:OffsetToStart><2B:TokenLength>
        write1B(t.kind); // TOK
        write2B(t.start - prev_end); // OffsetToStart
        write2B(t.end - t.start); // TokenLength
      }
      prev_end = t.end;
    }

    ubyte[] data_body = data;
    data = null;
    // Write file header.
    writeS(HEADER);
    writeS("Ids:");
    write2B(idents.length);
    auto text_begin = first_token.prev.end;
    foreach (id; idents)
      write4B(id.start - text_begin),
      write2B(id.end - id.start);
    writeS("\n");
    writeS("Toks:");
    write4B(token_count);
    write4B(data_body.length);
    data ~= data_body;
    writeS("\n");
    return data;
  }

  Token[] deserialize(ubyte[] data, string srcText, IdTable idtable,
    void delegate(Token* next_token) callback)
  {
    ubyte* p = data.ptr;
    ubyte* end = data.ptr + data.length;

    // Define nested functions for reading data and advancing the pointer.
    bool match(string x)
    {
      return p+x.length <= end && p[0..x.length] == cast(ubyte[])x &&
        ((p += x.length), 1);
    }
    bool read(ref string x, uint len)
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
    char* prev_end = srcText.ptr;
    char* src_end = srcText.ptr+srcText.length;

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
        token_len = token.ident.str.length;
        break;
      default:
        if (!read2B(token_len)) goto Lerr;
      }
      // Set token.end.
      token.end = prev_end = token.start + token_len;
      if (prev_end > src_end) goto Lerr;
      // Pass the token back to the client.
      callback(token);
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
