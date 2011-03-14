require_relative 'node'
require_relative 'statement'

module Ruby2Pilar
  module Pilar
    module AST
      class Location < Node
        attr_accessor :name
        default :statements, []
        
        def to_buf(buf)
          if statements.size == 1
            buf.append(to_s_name)
            statements.first.to_buf(buf)
          else
            buf.append_line(to_s_name)
            buf.indent do
              statements.each do |s|
                s.to_buf(buf)
                buf.append_line(';') if s.is_a?(Expression)
              end
            end
          end
        end
        
        private
        
        def to_s_name
          "##{name}" + (statements.size == 1 && name ? '.' : '') + ' '
        end
      end
      
      class Procedure < Node
        attr_accessor :name, :returns
        default :params, []
        default :locations, []
        default :contracts, []
        default :labels, []
        default :locals, {}
      
        def to_buf(buf)
          buf.append("procedure #{name}(#{params.join(", ")})", loc)
          contracts.each {|c| buf.append(" "); c.to_buf(buf) }
          buf.append_line(" {")
          buf.indent do 
            if locals.size > 0
              buf.append_line("locals")
              buf.indent { locals.values.each {|l| l.to_buf(buf) } }
            end
            locations.each {|l| next unless l; l.to_buf(buf) }
          end
          buf.append_line("}")
        end
      
        private
      
        def to_s_contracts
          contracts.empty? ? "" : contracts.join(" ") + " "
        end
      end
    end
  end
end
