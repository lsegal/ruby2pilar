require_relative 'node'

module Ruby2Pilar
  module Pilar
    module AST
      class Expression < Node; end

      class Parameter < Expression
        attr_accessor :name, :type
        def to_s; "#{type ? type + " " : ""}#{name}" end
      end
    
      class BinaryExpression < Expression
        attr_accessor :lhs, :op, :rhs
        def to_s; "#{lhs} #{op} #{rhs}" end
      end
      
      class TokenExpression < Expression
        attr_accessor :token
        alias to_s token
      end
      
      class FieldReference < Expression
        attr_accessor :record
        attr_accessor :field
        def to_s; "#{record.name}.#{field.name}" end
      end
      
      class ProcedureReference < Expression
        attr_accessor :procedure
        def to_s; procedure.name end
      end
      
      class NullLiteral < Expression
        def to_s; 'nil' end
      end
      
      class ArrayLiteral < Expression
        default :expressions, []
        def to_s; '[' + expressions.join(', ') + ']' end
      end
    end
  end
end
