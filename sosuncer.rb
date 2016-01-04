#coding: utf-8

#Jonny言語

#制約
#原則、ブロック外ではグローバル変数の宣言しかできない
#String型のスカラー値を条件に使うことはゆるされない
#拡張子を間違えることは許されざる行為。

#注意
#いくつかネストする際、変数のスコープの問題が発生(Array#clearしているので、関係無いlocalスコープから他のlocalスコープへの干渉が起きる。おそらく、ネスト前のスコープの変数が消滅するという現象が起こる)

###時間が無い中、実現できて欲しかった範囲でできないこと
##Fatal
#ローカル変数が、正しいスコープで機能できていない
#関数のネスト呼び出しについて、実装しきれていない(再帰もキツイ)
##Bad
#フォーマット文字列を使えない
#配列がない
#文字列に添え字アクセスできない
#文字列の掛け算ができない
#文字列のスライスができない
#辞書型がない
#OOP出来ない
#他ライブラリのimportができない
#変数宣言にいちいちglobalとかlocalとかつけなきゃいけない(プログラマに、ブロック外ではglobal宣言を強いている)

class RenchonException < Exception; end
class Compiler
	#******************** Fields ********************
	@@code = '' #Source Code
	@@keywords = {
		#sentences
		'global' => :global_declare,
		'local' => :local_declare,
		'if' => :if,
		'elif' => :elif,
		'else' => :else,
		'while' => :while,
		'print' => :print,
		'read' => :read,
		'def' => :def,
		'return' => :return,
		#signs
		'(' => :lpar,
		')' => :rpar,
		'{' => :lbrace,
		'}' => :rbrace,
		',' => :comma,
		#operators
		'>=' => :ge,
		'<=' => :le,
		'+=' => :add_substitute,
		'-=' => :sub_substitute,
		'*=' => :mul_substitute,
		'/=' => :div_substitute,
		'%=' => :mod_substitute,
		'==' => :eq,
		'+' => :add,
		'-' => :sub,
		'*' => :mul,
		'/' => :div,
		'%' => :mod,
		'!=' => :ne,
		'>' => :gt,
		'<' => :lt,
		'=' => :substitute
	}
	@@operation_operators = [:add , :sub, :mul, :div, :mod]
	@@substitute_operators = [:substitute, :add_substitute, :sub_substitute, :mul_substitute, :div_substitute, :mod_substitute]
	@@cond_operators = [:eq, :ne, :gt, :ge, :lt, :le]

	@@debug_mode = false #Compilerのデバッグ出力をするか否か
	#******************** Initialize ********************

	def initialize()
		@@code = File.open(ARGV[0], "r").read()
		e = File.extname(ARGV[0]) 
		unless e =~ /\A\.renchon(:?saikou|.*suki|kami)\z/
			raise RenchonException, "こんぱいるしたくないのん..."
		end
		@global_variables = Hash.new
		@local_variables  = Hash.new

		@func_names       = Array.new
		@func_programs    = Hash.new
		@func_arguments   = Hash.new
		@current_func_name = nil

		@look_func = false
		@look_func_call = false
	end

	#******************** Debug ********************

	def debug(st)
		if @@debug_mode
			puts st
		end
	end

	#******************** Token ********************
	def get_token()
		#debug "func_names = #{@func_names.join('|')}"
		debug "Excess code = #{@@code}"
		#Keyword
		if @@code =~ /\A\s*(#{@@keywords.keys.map{|t| Regexp.escape(t)}.join('|')})/
			@@code = $'
			debug "[Eat@keywords] #{$1}"
			if @@keywords[$1] == :def
				@look_func = true
			end
			return @@keywords[$1]
		#function name
		elsif @look_func && @@code =~ /\A\s*([a-zA-Z][a-zA-Z0-9_]*)\s*\(/
			@@code =  '(' + $'
			debug "[Eat@func_name] #{$1}"
			@func_names << $1
			return [:func_name, $1]
		#function arguments name
		elsif @look_func && @@code =~ /\A\s*([a-zA-Z][a-zA-Z0-9_]*)\s*(,|\))/
			@@code = $2 + $'
			debug "[Eat@func_arg] #{$1}"
			return [:func_arg_name, $1]
		#function call
		elsif @@code =~ /\A\s*(#{@func_names.join('|')})\s*\(/
			@@code = '(' + $'
			debug "[Eat@call] #{$1}"
			return [:func_call, $1]
		#function call arguments(関数呼び出しの引数を取り出す)
		elsif @look_func_call && @@code =~ /\A\s*([a-zA-Z][a-zA-Z0-9_]*)\s*(,|\))/
			@@code = $2 + $'
			debug "[Eat@func_call_arg] #{$1}"
			return [:func_call_arg, $1]
		#Numerical value
		elsif @@code =~ /\A\s*([0-9.]+)/
			@@code = $'
			debug "[Eat@numerical] #{$1}"
			return $1.to_f
		#String value
		elsif @@code =~ /\A\s*\"(.*?)\"/
			@@code = $'
			debug "[Eat@string] #{$1}"
			return $1
		#True of False
		elsif @@code =~ /\A\s*(true|false)/
			@@code = $'
			debug "[Eat@true_or_false] #{$1}"
			return eval($1)
		#Variable name
		elsif @@code =~ /\A\s*([a-zA-Z][a-zA-Z0-9_]*)/
			@@code = $'
			debug "[Eat@variable_name] #{$1}"
			return [:variable, $1]
		#Whitespaces
		elsif @@code =~ /\A\s*\z/
			@@code = $'
			debug "[Empty@whitespace]"
			return nil
		end
		return :bad_token
	end

	def unget_token(token)
		debug "[UnEat] #{token}"
		if token.is_a?(Numeric) || (token.is_a?(TrueClass)) || (token.is_a?(FalseClass)) #文字列じゃないなら、一旦文字列に変換してソースコードに戻す
			@@code = " " + token.to_s + " " + @@code
		elsif @@keywords.values.include?(token) #キーワード
			@@code = @@keywords.key(token) ? " " + @@keywords.key(token) + " " + @@code : @@code
		elsif token.is_a?(Array)
			@@code = " " + token[1] + " " + @@code
		elsif token == nil || token == :bad_token #空白
			debug "bad token uneat"
		else #文字列
			@@code = " \"" + token + "\" " + @@code 
		end
	end

	#******************** 字句解析 ********************

	###Foundation
	def program()
		result = []
		sent = sentence()
		if sent == nil
			raise Exception, "Invalid sentence"
		end
		result << sent
		while true
			sent = sentence()
			if sent == nil
				break
			end
			debug "[program] push #{sent}"
			result << sent
		end
		return result
	end

	def sentence()
		result = nil #resultをここで初期化しておく

		#各sentenceをチェックしていく
		unless (result=def_sentence()) || (result=call_sentence()) || (result=return_sentence()) || (result=print_sentence()) || (result=read_sentence()) || (result=declare_sentence()) || (result=if_sentence()) || (result=while_sentence()) ||  (result=substitution())
			debug "Invalid sentence"
		end
		debug "[+]#{result}"
		debug "Excess code = #{@@code}"
		return result
	end

	###Sentences
	def declare_sentence()
		debug "[declare] in"
		token = get_token()
		unless token == :global_declare || token == :local_declare
			debug "[declare] Oops"
			unget_token(token)
			return nil
		end
		debug "[declare] get token #{token}"
		name = scalar() #変数名(get_token後、文字列と同じ扱い)
		debug "[declare] get name #{name}"
		if token == nil || token == :bad_token
			raise Exception, "Ungettable variable name"
		end
		equal = get_token()
		debug "[declare] get equal #{equal}"
		unless equal == :substitute # '='
			raise Exception, "expected \'=\' token"
		end
		value = condition() || call_sentence() || scalar() || string_concat() || expression()
		debug "[declare] get value #{value}"
		if token == nil || token == :bad_token
			raise Exception, "Ungettable value"
		end
		return [token, name, value]
	end

	def print_sentence()
		debug "[print] in"
		token = get_token()
		debug "[print] get token #{token}"
		unless token == :print
			debug "[print] Oops"
			unget_token(token)
			return nil
		end
		exp =  condition() || call_sentence() || scalar() || string_concat() || expression() 
		debug "[print] get scalar #{exp}"
		result = [:print, exp]
		return result
	end

	def read_sentence()
		debug "[read] in"
		token = get_token()
		unless token == :read
			debug "[read] Oops"
			unget_token(token)
			return nil
		end
		debug "[read] get token #{token}"
		variable = scalar()
		debug "[read] get scalar #{variable}"
		return [:read, variable]
	end

	def if_sentence()
		debug "[if] in"
		result = []
		token = get_token()
		unless token == :if
			debug "[if] not if_sentence"
			unget_token(token)
			return nil
		end
		token = get_token()
		unless token == :lpar
			raise Exception, "Expected \'(\' token"
		end
		debug "[if] get token #{token}"
		cond = condition() || call_sentence() || scalar() || expression()
		debug "[if] get cond #{cond}"
		token = get_token()
		unless token == :rpar
			raise Exception, "Expected \')\' token"
		end
		debug "[if] get token #{token}"
		token = get_token()
		unless token == :lbrace
			raise Exception, "Expected \'{\' token"
		end
		debug "[if] get token #{token}"
		prog = program()
		token = get_token()
		unless token == :rbrace
			raise Exception, "Expected \'}\' token"
		end
		debug "[if] get token #{token}"
		return [:if, cond, prog, elif_else_sentence()]
	end

	def elif_else_sentence()
		token = get_token()
		unless token == :elif #else
			if token == :else
				token = get_token()
				unless token == :lbrace
					raise Exception, "Expected \'{\' token"
				end
				prog = program()
				token = get_token()
				unless token == :rbrace
					raise Exception, "Expected \'}\' token"
				end
				return [:else, prog]
			else
				unget_token(token)
				return nil
			end
		else  #elif
			if token == :elif
				token = get_token()
				unless token == :lpar
					raise Exception, "Expected \'(\' token"
				end
				cond = condition() || call_sentence() || scalar() || expression()
				token = get_token()
				unless token == :rpar
					raise Exception, "Expected \')\' token"
				end
				token = get_token()
				unless token == :lbrace
					raise Exception, "Expected \'{\' token"
				end
				prog = program()
				token = get_token()
				unless token == :rbrace
					raise Exception, "Expected \'}\' token"
				end
				return [:elif, cond, prog, elif_else_sentence()]
			else
				unget_token(token)
				return nil
			end
		end
	end

	def while_sentence()
		debug "[repeat] in"
		token = get_token()
		unless token == :while
			debug "[repeat] not repeat_sentence #{token}"
			unget_token(token)
			return nil
		end
		token = get_token()
		unless token == :lpar
			raise Exception, "Expected \'(\' token"
		end
		cond = condition() || call_sentence() || scalar() || expression()
		token = get_token()
		unless token == :rpar
			raise Exception, "Expected \')\' token"
		end
		token = get_token()
		unless token == :lbrace
			raise Exception, "Expected \'{\' token"
		end
		prog = program()
		token = get_token()
		unless token == :rbrace
			raise Exception, "Expected \'}\' token"
		end
		result = [:while, cond, prog]
	end

	def def_sentence()
		debug "[def] in"
		token = get_token()
		unless token == :def
			unget_token(token)
			return nil
		end
		debug "[def] get token #{token}"
		name = get_token()
		unless name[0] == :func_name
			raise Exception, "Invalid function name"
		end
		debug "[def] get token #{name}"
		token = get_token()
		unless token == :lpar
			raise Exception, "Expected \'(\' token"
		end
		debug "[def] get token #{token}"
		arg_ary = []
		while true
			arg = get_token()
			sign = get_token()
			unless sign == :comma || sign == :rpar
				unget_token(sign)
				unless arg == :rpar && sign == :lbrace #引数がある場合(修正)
					unget_token(arg)
				end
				debug "[def] while end"
				break
			end

			debug "[def] get arg #{arg}"
			debug "[def] Excess code = #{@@code}"
			arg_ary << arg
		end
		debug "[def] no longer look at @look_func"
		@look_func = false #get_tokenでこれ以上look_funcを見る必要はない
		debug "Excess code = #{@@code}"
		token = get_token()
		unless token == :lbrace
			raise Exception, "Expected \'{\' token"
		end
		debug "[def] get token #{token}"
		debug "[def] to [program]"
		prog = program()
		token = get_token()
		unless token == :rbrace
			raise Exception, "Expected \'}\' token"
		end
		debug "[def] get token #{token}"
		return [:def, name, arg_ary, prog]
	end

	def call_sentence()
		debug "[call] in"
		token = get_token()
		unless token.is_a?(Array)
			unget_token(token)
			return nil
		else
			name = token[1]
			debug "[call] get name #{name}"
			unless token[0] == :func_call
				unget_token(token)
				return nil
			end
			token = get_token()
			unless token == :lpar
				unget_token(token)
				return nil
			end
			debug "[call] get token #{token}"
			arg_ary = []
			#引数があるかどうかチェックする
			has_arg = true
			token = get_token()
			if token == :rpar
				has_arg = false
			else
				unget_token(token)
			end
			while has_arg
				arg = condition()  || scalar() || expression() || get_token()  || call_sentence()
				debug "[call] get arg #{arg}"
				sign = get_token()
				debug "[call] get sign #{sign}"
				if sign == :rpar
					arg_ary << arg #最後の引数を突っ込む
					break
				elsif sign != :comma
					raise Exception, "Invalid token #{sign}"
				end
				arg_ary << arg
			end
			@look_func_call = false
			return [:call, name, arg_ary]
		end
	end

	def return_sentence()
		debug "[return] in"
		token = get_token()
		unless token == :return
			unget_token(token)
			return nil
		end
		token = get_token()
		unless token == :lpar
			raise Exception, "Expected \'(\' token"
		end
		debug "[return] get token #{token}"
		val = condition() || call_sentence() || scalar() || string_concat() || expression()
		debug "[return] get val #{val}"
		token = get_token()
		unless token == :rpar
			raise Exception, "Expected \')\' token"
		end
		debug "[return] get token #{token}"
		return [:return, val]
	end

	###Operation
	#演算
	#-式
	def expression()
		debug "[operator_expression] in"
		result = term()
		while true
			token = get_token()
			debug "[operator_expression] get token #{token}"
			unless token == :add or token == :sub
				unget_token(token)
				break
			end
			te = term()
			result = [:operation, [token, result, te]]
		end
		
		return result
	end
	#-項
	def term()
		debug "[operator_term] in"
		result = factor()
		while true
			token = get_token()
			debug "[operator_term] get token #{token}"
			unless token == :mul or token == :div or token == :mod
				unget_token(token)
				break
			end
			fac = factor()
			result = [:operation, [token, result, fac]]
		end
		
		return result
	end
	#-因子
	def factor()
		token = scalar() || get_token()

		debug "[operator_factor] get token #{token}"
		minusflg = 1

		if token == :sub
			debug "[operator_factor] this is sub!!"
			minusflg = -1
			token = get_token()
		end

		if token.is_a?(Numeric)
			return token * minusflg
		elsif token == :lpar
			result = expression()
			unless get_token() == :rpar
				raise Exception, "Expected token \')\'"
			end
			return [:operation, [:mul, minusflg, result]]
		elsif token.is_a?(Array) #変数
			return token
		else
			debug "[operator_factor] unexpected #{token}"
			raise Exception, "Unexpected token "
		end
	end

	#変数に対する代入演算
	def substitution()
		debug "[substitution] in"
		val1 = get_token()
		debug "[substitution] get token #{val1}"
		unless val1.is_a?(Array) && val1[0] == :variable
			unget_token(val1)
			return nil
		end
		operator = nil
		val2 = nil
		operator = get_token()
		unless @@substitute_operators.include?(operator)
			unget_token(operator)
			return nil
		end
		val2 = call_sentence() || scalar() || string_concat() || expression()
		unless val1 != nil && val2 != :bad_token
			raise Exception, "Invalid token"
		end
	
		return [:substitution, val1, operator, val2]
	end

	#複雑な条件(こいつを、今までのconditionと置き換えてやればいい)
	#complex_condition := '!'? condition (('||'|'&&'|'^') '!'? condition)*
	#括弧も考慮する必要が有る。そのあたりはfactor()を参考にすると良さげ？
	#[:or, condition1, [:and, condition2, condition3]]
	def complex_condition()

	end

	#条件
	def condition()
		debug "[condition] in"
		op1 = get_token()
		debug "[condition] get op1 #{op1}"
		if op1 == nil || op1 == :bad_token
			unget_token(op1)
			return nil #条件ではない
		elsif op1 == true
			return true
		end
		operator = get_token()
		debug "[condition] get operator #{operator}"
		unless @@cond_operators.include?(operator)
			unget_token(operator)
			unget_token(op1)
			return nil #条件ではない
		end
		op2 = get_token()
		debug "[condition] get op2 #{op2}"
		if op2 == nil || op2 == :bad_token
			unget_token(op2)
			unget_token(operator)
			unget_token(op1)
			return nil
		end
		return [:condition, op1, operator, op2]
	end

	#String concat
	def string_concat
		debug "[string_concat] in"
		str_concat = []
		s1 = get_token()
		debug "[string_concat] get s1 #{s1}"
		unless s1.is_a?(String)
			unget_token(s1)
			return nil
		end
		str_concat << s1
		while true
			op = get_token()
			debug "[string_concat] get op #{op}"
			unless op == :add
				unget_token(op)
				break
			end
			sn = get_token()
			debug "[string_concat] get sn #{sn}"
			unless s1.is_a?(String)
				raise Exception, "String + Other is Invalid"
			end
			str_concat << sn
		end
		debug "[string_concat] return #{[:string_concat, str_concat]}"
		return [:string_concat, str_concat]
	end

	###Scalar
	def scalar()
		debug "[scalar] in"
		token = get_token()
		lookahead = get_token()
		debug "[scalar] get lookahead #{lookahead}"
		if @@keywords.include?(token) || @@keywords.include?(lookahead) || @@operation_operators.include?(lookahead) || lookahead == :lpar #先読みして、演算でないか確かめる
			unget_token(lookahead)
			unget_token(token)
			return nil #スカラー値ではなく、演算
		elsif lookahead == nil || lookahead == :bad_token
			unget_token(token)
			return nil
		end
		unget_token(lookahead) #先読みして、大丈夫だったので戻しておく
		debug "[scalar] get token #{token}"
		if token == nil || token == :bad_token
			debug "nil or badtoken"
			return nil
		elsif token.is_a?(Numeric) #数値
			debug "numeric"
			return token
		elsif token.is_a?(String) #文字列
			debug "string"
			return token
		elsif token.is_a?(Array) #変数名
			debug "variable name"
			return token
		elsif token.is_a?(TrueClass) || token.is_a?(FalseClass) #真偽値
			return token
		end
		unget_token(token)
		return nil #tokenはnilではないが、scalarではない
	end

	#******************** 構文解析 ********************
	###Helper
	#Global or Local
	def where_exist(variable)
		debug "[where_exist] #{variable}"
		debug "local_variables = #{@local_variables}"
		debug "funcname = #{@func_name}"
		debug "func_arguments = #{@func_arguments}"
		#ローカル -> グローバルと見ていく(グローバル変数は、ローカル変数によって隠れてしまう)
		if @local_variables.include?(variable)
			return "local"
		elsif @func_name != nil && @func_arguments.keys.include?([[:func_name, @func_name], [:func_arg_name, variable]])
			return "func"
		elsif @global_variables.include?(variable)
			return "global"
		else
			debug "Unrecognized value #{variable}"
			raise Exception, "Unrecognized variable"
		end
	end
	#get variable
	def getVariable(name, where=nil)
		if where == nil
			raise Exception, "Unrecognized variable"
		elsif where == "local"
			val = @local_variables[name]
		elsif @func_name != nil && where == "func"
			val = @func_arguments[[[:func_name, @func_name], [:func_arg_name, name]]]
		elsif where == "global"
			val = @global_variables[name]
		end
		return val
	end
	#get function argument names
	def get_func_argument_names(func_name)
		return(@func_arguments.keys.select{|e| e[0][1] == func_name}.map{|e| e[1][1]})
	end

	###Main
	def myEval(program)
		#debug "Look #{program}"
		if program.is_a?(Array)
			case program[0]
			when :global_declare
				#debug "[global_declare] #{program}"
				@global_variables.store(myEval(program[1][1]), myEval(program[2]))
			when :local_declare
				#debug "[local_declare] #{program}"
				@local_variables.store(myEval(program[1][1]), myEval(program[2]))
			when :print
				#debug "[print] Exec with arg #{program[1]}"
				puts myEval(program[1])
			when :read
				val = STDIN.gets.chomp!
				if val =~ /\A\d+\z/ #数値
					val = val.to_i
				elsif val =~ /\A(true|false)\z/ #真偽値
					val = eval(val)
				end #数値でも真偽値でもなければ、文字列だと考える。
				where = where_exist(program[1][1])
				if where == "local"
					@local_variables[program[1][1]] = val
				elsif where == "func"
					debug "func substitution #{[[:func_name, @func_name],[:func_arg_name, program[1][1]]]}"
					@func_arguments[[[:func_name, @func_name], [:func_arg_name, program[1][1]]]] = val
				elsif where == "global"
					@global_variables[program[1][1]] = val
				end
			when :variable
				return(getVariable(program[1], where=where_exist(program[1])))
			when :condition
				op1 = myEval(program[1])
				op2 = myEval(program[3])
				if op1.is_a?(String) && op2.is_a?(String)
					#debug "[condition] Judge \"#{op1}\" #{@@keywords.key(program[2])} \"#{op2}\""
					return eval("\"#{op1}\" #{@@keywords.key(program[2])} \"#{op2}\"")
				else	
					#debug "[condition] Judge #{op1} #{@@keywords.key(program[2])} #{op2}"
					return eval("#{op1} #{@@keywords.key(program[2])} #{op2}")
				end
				
			when :operation
				result = program[1]
				case result[0]
				when :add
					return(myEval(result[1]) + myEval(result[2]))
				when :sub
					return(myEval(result[1]) - myEval(result[2]))
				when :mul
					return(myEval(result[1]) * myEval(result[2]))
				when :div
					return(myEval(result[1]) / myEval(result[2]))
				when :mod
					return(myEval(result[1]) % myEval(result[2]))
				end
			when :if, :elif
				if myEval(program[1])
					prog = program[2]
					prog.each{|p|
						ret = myEval(p)
						if ret != nil && ret.is_a?(Array) && ret[0] == :return
							@local_variables.clear
							return ret
						end
					}
				else
					unless program[3] == nil #もし、elifもしくはelseが続くなら
						myEval(program[3])
					end
				end
				@local_variables.clear
			when :else
				prog = program[1]
				prog.each{|p|
					ret = myEval(p)
					if ret != nil && ret.is_a?(Array) && ret[0] == :return
						@local_variables.clear
						return ret
					end
				}
				@local_variables.clear
			when :while
				prog = program[2]
				while(myEval(program[1]))
					prog.each{|p|
						ret = myEval(p)
						if ret != nil && ret.is_a?(Array) && ret[0] == :return
							@local_variables.clear
							return ret
						end
					}
				end
			when :def
				#debug "[def] executing"
				#debug "arg is #{program}"
				program[2].each {|arg|
					#debug "[def] store [#{program[1]}, #{arg}] => nil"
					@func_arguments.store([program[1], arg], nil)
				}
				#debug "[def] store program #{program[1]} => #{program[3]}"
				@func_programs.store(program[1], program[3])
			when :string_concat
				return program[1].join('')
			when :substitution
				if program[2] == :substitute
					val = myEval(program[3])
				else
					#debug "val is #{"#{myEval(program[1])} #{@@keywords.key(program[2])[0]} #{myEval(program[3])}"}"
					val = eval("#{myEval(program[1])} #{@@keywords.key(program[2])[0]} #{myEval(program[3])}")
				end
				where = where_exist(program[1][1])
				if where == "local"
					@local_variables[program[1][1]] = val
				elsif where == "func"
					debug "func substitution #{[[:func_name, @func_name],[:func_arg_name, program[1][1]]]}"
					@func_arguments[[[:func_name, @func_name], [:func_arg_name, program[1][1]]]] = val
				elsif where == "global"
					@global_variables[program[1][1]] = val
				end
			when :call
				@func_name = program[1]
				arg_names = get_func_argument_names(program[1])
				if arg_names.length != program[2].length
					raise Exception, "Invalid length of arguments"
				end
				arg_names.each_with_index{|arg, idx|
					@func_arguments[[[:func_name, @func_name], [:func_arg_name, arg]]] = myEval(program[2][idx])
				}
				func_process = @func_programs[[:func_name, program[1]]]
				ret_val = nil
				func_process.each{|proc|
					ret = myEval(proc)
					if ret != nil && ret.is_a?(Array) && ret[0] == :return #returnが実行されたならば
						ret_val = ret[1] #値を登録しておく
						break #抜け出し
					end
				}
				#引数をnilに戻す
				arg_names.each {|arg|
					@func_arguments[[[:func_name, @func_name], [:func_arg_name, arg]]] = nil
				}
				@func_name = nil
				@local_variables.clear #callはブロックを持たないが、関数がブロックを持つのでローカル変数をクリア
				return(ret_val)
			when :return
				return program #シンボルをつけたままで返す(単なるスカラー値ではなく、returnによって返ることを示すため)
			else 
				raise Exception, "UnEvaluatable program \'#{program}\'"
			end
		else #スカラー値
			#debug "[scalar] no execute #{program}"
			return program
		end	
	end

	#******************** Main Thread ********************
	def start()
		prog = program()
		debug "\n********"*5
		debug "Parse Result: #{prog}"
		debug "\n********"*5
		debug "###Results"
		prog.each {|p|
			myEval(p)
		}
		debug "\n********"*5
		debug "###variables"
		debug "global_variables = #{@global_variables}"
		debug "local_variables = #{@local_variables}"
		debug "func_programs = #{@func_programs}"
		debug "func_arguments = #{@func_arguments}"
		debug "current_func_name = #{@current_func_name}"
		debug "look_func = #{@look_func}"
		debug "look_func_call = #{@look_func_call}"
	end
end

sosuncer = Compiler.new
sosuncer.start()