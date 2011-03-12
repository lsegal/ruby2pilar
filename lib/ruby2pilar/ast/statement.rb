require_relative 'node'
require_relative 'procedure'

module Ruby2Pilar
  module Pilar
    module AST
      class Statement < Node
        attr_accessor :procedure
        def to_buf(o) o.append_line(to_s, loc) end
      end
    
      class ContractStatement < Statement
        attr_accessor :name, :expression
        def to_s; "#{name} #{expression};" end
        def to_buf(o) o.append(to_s, loc) end
      end
    
      class AssignmentStatement < Statement
        attr_accessor :lhs, :rhs

        def to_buf(o)
          lhs.to_buf(o)
          o.append(" := ", loc)
          rhs.to_buf(o)
          o.append_line(";")
        end
      end
      
      class LocalDeclarationStatement < Statement
        attr_accessor :name
        default :type, 'Object'
        def to_s; "#{type && type != 'Object' ? type + " " : ""}#{name};" end
      end
    
      class AssertStatement < Statement
        attr_accessor :expression
        def to_s; "assert #{expression};" end
      end
    
      class AssumeStatement < Statement
        attr_accessor :expression
        def to_s; "assume #{expression};" end
      end
      
      class CallStatement < Statement
        attr_accessor :name
        default :parameters, []
        
        def to_buf(o)
          o.append("call unused", loc)
          o.append(" := ", loc)
          o.append(name, loc)
          o.append_line("(" + parameters.join(', ') + ");")
        end
      end
      
      class CallAssignmentStatement < AssignmentStatement
        def to_buf(o)
          o.append("call ", loc)
          lhs.to_buf(o)
          o.append(" := ", loc)
          o.append_line("#{rhs.name}(#{rhs.parameters.join(', ')});");
        end
      end
    
      class ReturnStatement < Statement
        attr_accessor :expression
        def to_buf(o)
          o.append_line("return#{expression ? " " + expression.to_s : ""};")
        end
      end
      
      class IfStatement < Statement
        attr_accessor :condition
        default :then, []
        default :else, []
        
        def to_buf(o)
          o.append(":: (");
          condition.to_buf(o)
          o.append_line(") +>")
          o.indent { self.then.each {|t| t.to_buf(o) } }
          if self.else
            o.append_line("| else")
            o.indent { self.else.each {|e| e.to_buf(o) } }
          end
        end
      end
      
      class LabelStatement < Statement
        attr_accessor :name
        
        def initialize(*args)
          super
          if procedure
            self.name += procedure.labels.select {|l| l.name.start_with?(name) }.size.to_s
            procedure.labels << self
          end
        end
        
        def to_s; "##{name}." end
      end
    end
  end
end
