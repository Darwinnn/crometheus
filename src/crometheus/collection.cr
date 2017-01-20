require "./gauge"

module Crometheus

  class Collection(T)
    property metric
    property name, docstring

    def initialize(@name : Symbol, @docstring : String)
      @metric = T.new(@name, {} of Symbol => String)
      @children = {} of Hash(Symbol, String) => T
    end

    # Fetch or create a child metric with the given labelset
    def labels(**tuple)
      labelset = tuple.to_h
      return @children[labelset] ||= T.new(@name, labelset)
    end

    # pending https://github.com/crystal-lang/crystal/issues/3918
    #~ def [](**tuple)
      #~ labels(**tuple)
    #~ end

    def to_s(io)
      io << "# TYPE " << @name << " gauge\n"
      io << "# HELP " << @name << ' ' << @docstring << '\n'
      io << @metric
      @children.values.each {|child| io << child}
      return io
    end

    forward_missing_to(metric)
  end


end
