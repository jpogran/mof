module Mofscanner
  def fill_queue
    if @file.eof?
#      $stderr.puts "eof ! #{@fstack.size}"
      @file.close unless @file == $stdin
      unless @fstack.empty?
	@file, @name, @lineno = @fstack.shift
#	$stderr.puts "fill! #{@fstack.size}, #{@file}@#{@lineno}"
        return fill_queue
      end
      @q.push [false, false]
      return false
    end
    str = @file.gets
    return true unless str
    @lineno += 1

#    $stderr.puts "fill_queue(#{str})"

    scanner = StringScanner.new(str.chomp!)

    until scanner.empty?
#      $stderr.puts "#{@q.size}:\"#{scanner.rest}\""
      if @in_comment
	if scanner.scan(%r{.*\*/})
	  @in_comment = false
	else
	  break
	end
      end

      case
      when scanner.scan(/\s+/)
	next        # ignore space
	
      when m = scanner.scan(/\n+/)
	@lineno += m.size
	next        # ignore newlines

      when m = scanner.scan(%r{/\*})
        @in_comment = true
	
      when m = scanner.scan(%r{//.*})
	next        # c++ style comment
	
      when m = scanner.scan(%r{[(){}\[\],;#:=]})
	@q.push [m, m]

      when m = scanner.scan(%r{[123456789]\d*})
	@q.push [:positiveDecimalValue, m.to_i]
     
      # decimalValue = [ "+" | "-" ] ( positiveDecimalDigit *decimalDigit | "0" )
      # decimalDigit = "0" | positiveDecimalDigit
      when m = scanner.scan(%r{(\+|-)?\d+})
	@q.push [:decimalValue, m.to_i]

      # hexValue = [ "+" | "-" ] [ "0x" | "0X"] 1*hexDigit
      #      hexDigit = decimalDigit | "a" | "A" | "b" | "B" | "c" | "C" | "d" | "D" | "e" | "E" | "f" | "F"
      when m = scanner.scan(%r{(\+|-)?(0x|0X)([0123456789]|[abcdef]|[ABCDEF])+})
	@q.push [:hexValue, m.to_i]

      # octalValue = [ "+" | "-" ] "0" 1*octalDigit
      when m = scanner.scan(%r{(\+|-)?0[01234567]+})
	@q.push [:octalValue, m.to_i]

      #	binaryValue = [ "+" | "-" ] 1*binaryDigit ( "b" | "B" )
      when m = scanner.scan(%r{(\+|-)?(0|1)(b|B)})
	@q.push [:binaryValue, m.to_i]
	
      #      realValue = [ "+" | "-" ] *decimalDigit "." 1*decimalDigit
      #      [ ( "e" | "E" ) [ "+" | "-" ] 1*decimalDigit ]

      when m = scanner.scan(%r{(\+|-)?\d*\.\d+})
	@q.push [:realValue, m.to_f]

      #      charValue = // any single-quoted Unicode-character, except single quotes
      
      when m = scanner.scan(%r{\'([^\'])\'})
	@q.push [:charValue, scanner[1]]

      #      stringValue = 1*( """ *ucs2Character """ )
      #      ucs2Character = // any valid UCS-2-character

      when m = scanner.scan(%r{\"([^\\\"]*)\"})
	@q.push [:stringValue, scanner[1]]

      # string with embedded backslash
      when m = scanner.scan(%r{\"(.*\\.*)\"})
#	$stderr.puts ":string(#{scanner[1]})"
	@q.push [:stringValue, scanner[1]]

      when m = scanner.scan(%r{\w+})
	case m.downcase
	when "any": @q.push [:ANY, m]
	when "as": @q.push [:AS, m]
	when "association": @q.push [:ASSOCIATION, m]
	when "class": @q.push( [:CLASS, m] )
	when "disableoverride": @q.push [:DISABLEOVERRIDE, m]
	when "boolean": @q.push [:DT_BOOL, m]
	when "char16": @q.push [:DT_CHAR16, m]
	when "datetime": @q.push [:DT_DATETIME, m]
	when "real32": @q.push [:DT_REAL32, m]
	when "real64": @q.push [:DT_REAL64, m]
	when "sint16": @q.push [:DT_SINT16, m]
	when "sint32": @q.push [:DT_SINT32, m]
	when "sint64": @q.push [:DT_SINT64, m]
	when "sint8": @q.push [:DT_SINT8, m]
	when "string": @q.push [:DT_STR, m]
	when "uint16": @q.push [:DT_UINT16, m]
	when "uint32": @q.push [:DT_UINT32, m]
	when "uint64": @q.push [:DT_UINT64, m]
	when "uint8": @q.push [:DT_UINT8, m]
	when "enableoverride": @q.push [:ENABLEOVERRIDE, m]
	when "false": @q.push [:booleanValue, false]
	when "flavor": @q.push [:FLAVOR, m]
	when "indication": @q.push [:INDICATION, m]
	when "instance": @q.push [:INSTANCE, m]
	when "method": @q.push [:METHOD, m]
	when "null": @q.push [:nullValue, m]
	when "of": @q.push [:OF, m]
	when "parameter": @q.push [:PARAMETER, m]
	when "pragma": @q.push [:PRAGMA, m]
	when "property": @q.push [:PROPERTY, m]
	when "qualifier": @q.push [:QUALIFIER, m]
	when "ref": @q.push [:REF, m]
	when "reference": @q.push [:REFERENCE, m]
	when "restricted": @q.push [:RESTRICTED, m]
	when "schema": @q.push [:SCHEMA, m]
	when "scope": @q.push [:SCOPE, m]
	when "tosubclass": @q.push [:TOSUBCLASS, m]
	when "translatable": @q.push [:TRANSLATABLE, m]
	when "true": @q.push [:booleanValue, true]
	else
	  x = m.split "_"
	  if x.size > 1
	    @q.push( [:IDENTIFIER, x.shift] )
	    @q.push( ["_", "_"] )
	    m = x.join("_")
	  end
	  @q.push( [:IDENTIFIER, m] )
	end # case m.downcase
      
      else
	raise "**** Unrecognized(#{scanner.rest})" unless scanner.rest.empty?
      end # case
    end # until scanner.empty?
#    $stderr.puts "scan done, @q #{@q.size} entries"
    true
  end

  def parse( file )
    open file
    @q = []
    do_parse
  end

  def next_token
    while @q.empty?
      break unless fill_queue 
    end
#    $stderr.puts "next_token #{@q.first.inspect}"
    @q.shift
  end
  
  def on_error(*args)
    $stderr.puts "Err #{@name}@#{@lineno}: args=#{args.inspect}"
    raise
  end

end # module