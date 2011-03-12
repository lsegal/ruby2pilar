module Ruby2Pilar
  module Pilar
    class Output < String
      attr_accessor :indent
      attr_accessor :nodemap
    
      def initialize
        @newline = false
        @source_point = [1,1]
        self.nodemap = {}
        self.indent = 0
        class << @source_point
          def col; self[1] end
          def row; self[0] end
          def col=(val); self[1] = val end
          def row=(val); self[0] = val end
        end
      end
    
      def append(str, node = nil)
        if @newline && indent > 0
          extra_indent = "  " * indent 
          self << extra_indent
          @source_point.col += extra_indent.size
        end
        nodemap[@source_point.dup] = node if node
        self << str.to_s
        @newline = false
        @source_point.col += str.to_s.size
      end
    
      def append_line(str, node = nil)
        append(str, node)
        self << "\n"
        @newline = true
        @source_point.row += 1
        @source_point.col = 1
      end
    
      def indent(&block)
        return @indent unless block_given?
        @indent += 1
        yield
        @indent -= 1
        @indent
      end
    end
  end
end
