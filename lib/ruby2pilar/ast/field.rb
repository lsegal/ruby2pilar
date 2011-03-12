require_relative 'node'

module Ruby2Pilar
  module Pilar
    module AST
      class Field < Node
        attr_accessor :name, :type
        
        def to_buf(buf)
          buf.append_line("#{type ? type + ' ' : ''}#{name};")
        end
      end
    end
  end
end
