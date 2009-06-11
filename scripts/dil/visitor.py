# -*- coding: utf-8 -*-
# Author: Aziz Köksal

class NodeVisitor:
  def visit(self, node):
    """ Calls a visit method for this node. """
    method = getattr(self, node.__class__.visit_name, self.default_visit)
    return method(node)

  def default_visit(self, node):
    """ Calls visit() on the subnodes of this node. """
    for n in node:
      self.visit(n)
