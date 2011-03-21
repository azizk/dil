/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module dil.i18n.ResourceBundle;

import dil.i18n.Messages;
import common;

/// Holds language-specific data (e.g. compiler messages.)
class ResourceBundle
{
  /// The language code. E.g.: "en" for English.
  string langCode;
  /// The list of messages.
  string[] messages;

  /// Constructs an object and creates a list of empty messages.
  this()
  {
    this.messages = new string[MID.max + 1];
  }

  /// Contructs an object and takes a list of messages.
  this(string[] msgs)
  {
    assert(MID.max+1 == msgs.length);
    this.messages = msgs;
  }

  /// Contructs an object by inheriting from a parent object.
  this(string[] msgs, ResourceBundle parent)
  {
    if (parent)
      foreach (i, ref msg; msgs)
        if (msg is null)
          msg = parent.messages[i]; // Inherit from parent.
    this(msgs);
  }

  /// Returns a text msg for a msg ID.
  string msg(MID mid)
  {
    return messages[mid];
  }
}
