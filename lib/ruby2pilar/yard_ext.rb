require 'yard'

module Ruby2Pilar
  class ExpressionTag < YARD::Tags::Tag
    include YARD::Parser::Ruby
    
    attr_accessor :expression
    def initialize(tag, expr)
      super(tag, nil)
      self.expression = parse_expr(expr)
    end
    
    private
    
    def parse_expr(expr)
      return expr if expr.is_a?(AstNode)
      expr = RubyParser.new(expr, '<stdin>').parse.enumerator[0]
      expr.traverse do |node|
        node[0].type = :result if node == s(:var_ref, s(:gvar, "$result"))
        if node.type == :fcall && node[0] == s(:ident, "old")
          node.type = :old 
          node.replace(node.parameters[0])
        end
      end
      expr
    end
  end
  
  class MethodHandler < YARD::Handlers::Ruby::MethodHandler
    handles :def
    
    def register(obj) super; @obj = obj end
    
    def process
      super
      @obj.docstring.add_tag(ExpressionTag.new(:ast, statement.last))
    end
  end
end

class YARD::Tags::Library
  define_tag 'Precondition', :requires, Ruby2Pilar::ExpressionTag
  define_tag 'Postcondition', :ensures, Ruby2Pilar::ExpressionTag
  define_tag 'Modifies Clause', :modifies, Ruby2Pilar::ExpressionTag
  define_tag 'AST', :ast, Ruby2Pilar::ExpressionTag
end
