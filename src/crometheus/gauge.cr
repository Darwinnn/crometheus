module Crometheus
  class Gauge
    property name, docstring
    def initialize(name : Symbol, docstring : String)
      raise ArgumentError.new("docstring must be given") if docstring.empty?
      
      @values = Hash(Hash(Symbol, String), Float64).new
      @name = name
      @docstring = docstring
    end
    
    def get()
      get({} of Symbol => String)
    end

    def get(labels : Hash(Symbol, String))
      @values[labels]
    end
    
    # Sets the metric for a given label set
    def set(labels : Hash(Symbol, String), value : Int | Float)
      value = value.to_f64
      unless Crometheus.valid_labels?(labels)
        raise ArgumentError.new("invalid labels: #{labels}")
      end
      
      @values[labels] = value
      return self
    end
    
    # Sets the metric without any labels
    def set(value : Int | Float)
      value = value.to_f64
      set({} of Symbol => String, value)
    end
    
    def format(io)
      io << "# TYPE " << @name << " gauge\n"
      io << "# HELP " << @name << ' ' << @docstring << '\n'
      @values.each do |labels, value|
        io << @name
        unless labels.empty?
          io << '{' << labels.map{|k,v| "#{k}=\"#{v}\""}.join(", ") << '}'
        end
        io << ' ' << value << '\n'
      end
    end
    
    def format()
      String.build {|ss| format(ss) }
    end
  end
end
