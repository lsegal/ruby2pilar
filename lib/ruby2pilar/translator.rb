require_relative 'ast/procedure'
require_relative 'ast/program'
require_relative 'ast/statement'
require_relative 'ast/expression'
require_relative 'ast/field'

module Ruby2Pilar
  module Pilar
    class Translator
      include AST
    
      attr_accessor :program, :procedure, :varmap, :meth, :in_modifies, :current_contract
    
      def initialize(program = nil)
        self.program = program || Program.new
      end

      def translate_methods
        YARD::Registry.all(:method).each do |meth|
          program.procedures << translate_method(meth)
        end
      end
      
      def translate_classes
        YARD::Registry.all(:class).each do |klass|
          program.type(klass.path, klass.superclass.path)
        end
      end
    
      def translate_method(meth)
        ast = meth.tag(:ast).expression
        self.varmap = {}
        self.procedure = Procedure.new(loc: meth)
        self.meth = meth
        return_type = program.type(meth.tag(:return))
        procedure.returns = Parameter.new(name: "$result", type: program.type(meth.tag(:return)))
        procedure.name = meth.path
        procedure.params = meth.parameters.map {|k,v| Parameter.new(name: k, type: program.type(meth.tags(:param).find {|x| x.name == k })) }
        procedure.params = [Parameter.new(name: 'self'), Parameter.new(name: '&block')] + procedure.params
        procedure.params = procedure.params.reject.with_index {|x, i| procedure.params.find.with_index {|y, j| x != y && x.name == y.name && j < i } }
        procedure.locations = [Location.new(statements: process_statements(ast))]
        %w(requires ensures modifies).each do |tname|
          meth.tags(tname).each do |tag|
            self.in_modifies = true if tname == "modifies"
            self.current_contract = tag
            procedure.contracts << ContractStatement.new(name: tname, expression: visit(tag.expression), loc: tag, procedure: procedure)
            self.current_contract = nil
            self.in_modifies = false
          end
        end
        procedure
      end
    
      def translate_binary(bin)
        BinaryExpression.new(lhs: visit(bin[0]), op: bin[1], rhs: visit(bin[2]), loc: bin)
      end
    
      def translate_return(ret)
        ReturnStatement.new(expression: visit(ret.first.first), loc: ret.first.first)
      end
    
      def translate_var_ref(ref) visit(ref[0]) end
      def translate_int(int) TokenExpression.new(token: int.source) end
        
      def translate_if(stmt)
        node = IfStatement.new(condition: visit(stmt.condition), then: visit(stmt.then_block), else: visit(stmt.else_block), procedure: procedure, loc: stmt.condition)
      end
      
      def translate_assign(assign)
        return translate_call_assign(assign) if assign.last.type == :call
        case assign[0].type
        when :var_field
          name = assign.first.source
          if procedure.params.find {|p| p.name == name } # it's a parameter
            # we need to rewrite this variable name, since you can't assign to parameters in Boogie
            varmap[name] = (name += "0")
          end
          AssignmentStatement.new(lhs: visit(assign[0][0]), rhs: visit(assign[1]), procedure: procedure, loc: assign)
        else
          AssignmentStatement.new(lhs: visit(assign[0]), rhs: visit(assign[1]), procedure: procedure, loc: assign)
        end
      end
      
      def translate_call_assign(assign)
        stmt = nil
        call = assign[1]
        if call[0][0].type == :const && call.last.source == "new"
          declare_local(assign[0].source, program.type(call[0][0].source))
          if init = YARD::Registry.at(call[0].source + "#initialize")
            add_tags(init, :modifies)
            declare_local("unused")
            stmt = CallAssignmentStatement.new(procedure: procedure, loc: assign)
            stmt.rhs = CallStatement.new(procedure: procedure, loc: assign, name: init.path, parameters: [visit(assign[0][0])])
            stmt.lhs = TokenExpression.new(token: "unused")
          end
        else
          declare_local(assign[0].source)
        end
        if stmt.nil?
          stmt = CallAssignmentStatement.new(lhs: visit(assign[0][0]), rhs: visit(assign[1]), procedure: procedure, loc: assign)
        end
        stmt
      end
      
      def translate_ivar(ivar)
        ivar_name = ivar[0][1..-1]
        record = program.records[meth.namespace.path]
        if record
          field = record.fields[ivar_name] ||= Field.new(name: ivar_name)
        else
          field = nil
        end
        if in_modifies
          TokenExpression.new(token: current_contract.object.namespace.path + "." + ivar_name)
        else
          FieldReference.new(record: record, field: field)
        end
      end
      
      def translate_string_literal(str)
        if in_modifies
          TokenExpression.new(token: str.jump(:tstring_content)[0].gsub('@', '$'))
        else
          nil
        end
      end
      
      def translate_ident(ident)
        name = ident.source
        declare_local(name) unless name[0] == "$"
        TokenExpression.new(token: name)
      end
      
      def translate_array(array)
        #@@arrays ||= 0
        #name = "ARRAY$#{@@arrays += 1}"
        #declare_local(name, program.type('Array'))
        ArrayLiteral.new(expressions: visit(array[0]))
      end
      
      def translate_result(res)
        "$result"
      end
    
      def translate_old(old)
        "old(#{visit(old[0])})"
      end
      
      def translate_call(call)
        if call[0][0].respond_to?(:type) && call[0][0].type == :const && call.last.source == "new"
          nil
        elsif call[0].type != :ident
          obj = visit(call[0])
          typeklass = nil
          case obj
          when FieldReference
            typeklass = obj.field.type
          when TokenExpression
            if local = procedure.locals[obj.token]
              typeklass = local.type
            end
          end
        else
          obj = TokenExpression.new(token: 'self')
        end
        
        if call.last.type == :do_block || call.last.type == :brace_block
          blk = declare_block(call)
        else
          blk = NullLiteral.new
        end
        params = [Parameter.new(name: obj), blk]
        if m = YARD::Registry.resolve(meth.namespace, '#' + call.method_name(true).to_s, true, true)
          add_tags(m, :modifies) if m.type != :proxy
          CallStatement.new(name: m.path, parameters: params, procedure: procedure, loc: call)
        end
      end
      alias translate_fcall translate_call
      
      def translate_command(command)
        obj = TokenExpression.new(token: 'self')
        if command.last.type == :do_block || command.last.type == :brace_block
          blk = declare_block(command)
        else
          blk = NullLiteral.new
        end
        params = [obj, blk]
        params += command.parameters.map {|x| x ? x.source : nil }.compact
        m = YARD::Registry.resolve(meth.namespace, command[0].source, true, true)
        CallStatement.new(name: m.path, parameters: params, procedure: procedure, loc: command)
      end
      
      def translate_aref_field(aref)
        TokenExpression.new(token: procedure.locals[aref[0].source].name + "[#{aref[1].source}]")
      end
      
      def translate_aref(aref)
        local = procedure.locals[aref[0].source]
        TokenExpression.new(token: (local ? local.name : aref[0].source) + "[#{aref[1].source}]")
      end
      
      def translate_kw(kw)
        case kw[0]
        when 'nil'
          NullLiteral.new
        else
          TokenExpression.new(token: kw)
        end
      end
      
      def translate_yield(yld)
        params = visit(yld[0]).compact
        CallStatement.new(name: TokenExpression.new(token: "&block"), parameters: params)
      end
    
      private
      
      def declare_local(name, type = 'Object')
        return if procedure.params.any? {|x| x.name == name }
        procedure.locals[name] ||= LocalDeclarationStatement.new(name: name, type: type, procedure: procedure)
      end
      
      # @param [AstNode] call the call node (call.last is block)
      # @return [ProcedureReference]
      def declare_block(call)
        @@block_count ||= 0
        block = call.last
        var_list = block[0].jump(:params)
        if var_list.type == :params
          vars = var_list.required_params.map {|x| Parameter.new(name: x[0]) }
        else
          vars = []
        end
        vars = [Parameter.new(name: TokenExpression.new(token: 'self'))] + vars
        vars = vars.uniq
        proc = Procedure.new(loc: call, name: '__anon_block_' + call.method_name.source + '_' + (@@block_count += 1).to_s, params: vars)
        old_proc = procedure
        self.procedure = proc
        procedure.locations = [Location.new(statements: process_statements(block.last))]
        self.procedure = old_proc
        program.procedures << proc
        ProcedureReference.new(procedure: proc)
      end
      
      def process_statements(ast)
        return [] unless ast
        stmts = visit(ast).flatten
      end
      
      def add_tags(object, type)
        meth.docstring.instance_variable_get("@tags").push *object.tags(type).map {|t| t.dup }
      end
    
      def visit(node)
        return unless node
        return node.map {|n| visit(n) } if node.type == :list
        m = "translate_#{node.type}"
        send(m, node) if respond_to?(m)
      end
    end
  end
end
