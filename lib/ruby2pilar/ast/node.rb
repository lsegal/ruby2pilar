module Ruby2Pilar
  module Pilar
    module AST
      class Node
        attr_accessor :loc
      
        def self.default(attr, default = nil)
          attr_accessor attr
          defaults[attr] = default
        end
        def self.defaults; @defaults ||= {} end
      
        def initialize(opts = {})
          apply_defaults
          opts.each do |k,v|
            send("#{k}=", v) if respond_to?("#{k}=")
          end
        end
      
        alias inspect to_s
        def to_s; to_buf(o = Output.new); o end
        def to_buf(o) o.append(to_s, loc) end
      
        private
      
        def apply_defaults
          self.class.defaults.each do |k,v|
            send("#{k}=", v.clone)
          end
        end
      end
    end
  end
end
