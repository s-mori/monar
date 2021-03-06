require "bundler/setup"
require "monar"
require "monar/parser"

class ArithmeticParser
  def digit
    Monar::Parser.one_of(%w(1 2 3 4 5 6 7 8 9 0))
  end

  def number
    Monar::Parser.many(digit).monadic_eval do |d|
      pure(d.join.to_i)
    end
  end

  def spaces
    space = Monar::Parser.char(" ")
    Monar::Parser.many(space)
  end

  def add
    Monar::Parser.char("+").monadic_eval do |_|
      pure(->(a, b) { a + b })
    end
  end

  def sub
    Monar::Parser.char("-").monadic_eval do |_|
      pure(->(a, b) { a - b })
    end
  end

  def multiply
    Monar::Parser.char("*").monadic_eval do |_|
      pure(->(a, b) { a * b })
    end
  end

  def div
    Monar::Parser.char("/").monadic_eval do |_|
      pure(->(a, b) { a / b rescue nil })
    end
  end

  def lparen
    Monar::Parser.char("(")
  end

  def rparen
    Monar::Parser.char(")")
  end

  def addsub
    add | sub
  end

  def prioritized_op
    multiply | div
  end

  def factor(prev = nil, prev_op = nil)
    _self = self

    lparen.monadic_eval do |_|
      result0 <<= _self.expression
      _      <<= _self.rparen

      _      <<= _self.spaces
      op     <<= _self.prioritized_op
      _      <<= _self.spaces

      result1 = if prev
                  prev_op.call(prev, result0)
                else
                  result0
                end

      result2 <<= _self.factor(result1, op)
      pure(result2)
    end | lparen.monadic_eval do |_|
      result <<= _self.expression
      _      <<= _self.rparen

      result = if prev
                  prev_op.call(prev, result)
                else
                  result
                end

      pure(result)
    end | number.monadic_eval do |n|
      _      <<= _self.spaces
      op     <<= _self.prioritized_op
      _      <<= _self.spaces

      result0 = if prev
                  prev_op.call(prev, n)
                else
                  n
                end

      result <<= _self.factor(result0, op)
      pure(result)
    end | number.monadic_eval do |n|
      result0 = if prev
                  prev_op.call(prev, n)
                else
                  n
                end
      pure(result0)
    end
  end

  def expression(prev = nil, prev_op = nil)
    _self = self

    factor.monadic_eval do |f|
      result0 = if prev
                  prev_op.call(prev, f)
                else
                  f
                end
      _      <<= _self.spaces
      op     <<= _self.addsub
      _      <<= _self.spaces
      result <<= _self.expression(result0, op)
      pure(result)
    end | factor.monadic_eval do |f|
      result0 = if prev
                  prev_op.call(prev, f)
                else
                  f
                end
      pure(result0)
    end
  end

  def get_parser
    expression
  end
end

pp ArithmeticParser.new.get_parser.run_parser("100 - 200 - (300 - 1000)")[0][0]
pp eval("100 - 200 - (300 - 1000)")
pp ArithmeticParser.new.get_parser.run_parser("(100 + 200) - (300 + 1000)")[0][0]
pp eval("(100 + 200) - (300 + 1000)")
pp ArithmeticParser.new.get_parser.run_parser("(100 - 1 * 10) / (3 * 3)")[0][0]
pp eval("(100 - 1 * 10) / (3 * 3)")
