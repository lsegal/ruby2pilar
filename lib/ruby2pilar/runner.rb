require 'yard'
require_relative 'yard_ext'
require_relative 'translator'
require_relative 'output'
require_relative 'ast/program'

include Ruby2Pilar::Pilar
include AST

module Ruby2Pilar
  def self.parse(str)
    YARD::Registry.clear
    YARD.parse_string(str)
    program = AST::Program.new
    translator = Translator.new(program)
    translator.translate_classes
    translator.translate_methods
    program
  end
end

output = Ruby2Pilar::Pilar::Output.new
program = Ruby2Pilar.parse(<<-eof)
  def make_odd(x)
    if x % 2 == 0
      x = x + 1
    end
#    assert x % 2 == 1
  end
eof
program.to_buf(output)
puts output