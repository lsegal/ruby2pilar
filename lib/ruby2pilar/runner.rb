require 'yard'
require_relative 'yard_ext'
require_relative 'translator'
require_relative 'output'
require_relative 'ast/program'

include Ruby2Pilar::Pilar
include AST

require 'ripper'
require 'pp'

module Ruby2Pilar
  def self.parse(str)
    #pp Ripper.sexp(str)
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
    y = [1,2,3]
    y[0] = 2
    nil
    each([1,2,3]) do |f|
      puts f
    end
  end
  
  def each(arr, &block)
    yield arr[0]
    yield arr[1]
    yield arr[2]
  end
eof
program.to_buf(output)
puts output