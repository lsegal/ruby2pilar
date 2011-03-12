require_relative 'node'
require_relative 'constant'

module Ruby2Pilar
  module Pilar
    module AST
      class Record < Node
        attr_accessor :name, :superclass
        default :fields, {}
        
        def to_buf(buf)
          buf.append("record #{name}")
          buf.append(" extends #{superclass}") if superclass && superclass != 'Object'
          buf.append_line(" {")
          buf.indent { fields.values.each {|f| f.to_buf(buf) } }
          buf.append_line("}")
        end
      end
      
      class Program < Node
        default :records, {}
        default :procedures, []
        
        def initialize(*args)
          super
          type('Fixnum', 'Integer')
        end

        def to_buf(buf)
          records.values.each {|h| buf.append_line(h) }
          buf.append_line("")
          procedures.each {|p| p.to_buf(buf); buf.append_line("") }
        end
        
        def type(name, superclass = "Object")
          return unless name
          name = name.types.first if name.respond_to?(:types)
          return name if ["Object", "Integer"].include?(name)
          return name if records[name]
          records[name] = Record.new(name: name, superclass: superclass)
          name
        end
      end
    end
  end
end
