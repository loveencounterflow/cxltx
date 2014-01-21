




############################################################################################################
# njs_util                  = require 'util'
njs_fs                    = require 'fs'
njs_path                  = require 'path'
#...........................................................................................................
# BAP                       = require 'coffeenode-bitsnpieces'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
rpr                       = TRM.rpr.bind TRM
badge                     = 'CXLTX/main'
log                       = TRM.get_logger 'plain',     badge
info                      = TRM.get_logger 'info',      badge
whisper                   = TRM.get_logger 'whisper',   badge
alert                     = TRM.get_logger 'alert',     badge
warn                      = TRM.get_logger 'warn',      badge
help                      = TRM.get_logger 'help',      badge
_echo                     = TRM.echo.bind TRM
#...........................................................................................................
eventually                = process.nextTick
Line_by_line              = require 'line-by-line'


#-----------------------------------------------------------------------------------------------------------
# Object to represent entries in (a copy of) the `*.aux` file:
@aux = {}

#-----------------------------------------------------------------------------------------------------------
@main = ->
  # info "©45 argv: #{rpr process.argv}"
  texroute    = process.argv[ 2 ]
  jobname     = process.argv[ 3 ]
  splitter    = process.argv[ 4 ]
  command     = process.argv[ 5 ]
  parameter   = process.argv[ 6 ]
  #.........................................................................................................
  @dispatch texroute, jobname, splitter, command, parameter, ( error, result ) =>
    #.......................................................................................................
    echo debug error if error?
    echo result if result?
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@decode_unicode = ( text ) ->
  ### The `Buffer ... toString` steps below decode literal UTF-8 in the request ###
  ### TAINT the NodeJS docs say: [the 'binary'] encoding method is deprecated and should be avoided
    [...] [it] will be removed in future versions of Node ###
  return ( new Buffer text, 'binary' ).toString 'utf-8'

#-----------------------------------------------------------------------------------------------------------
@dispatch = ( texroute, jobname, splitter, command, parameter, handler ) ->
  warn '@32x', jobname, splitter, command, parameter
  method_name = command.replace /-/g, '_'
  return handler "Unknown command: #{rpr command}" unless ( method = @[ command ] )?
  parameter   = @decode_unicode parameter
  parameters  = if ( parameter? and parameter.length > 0 ) then parameter.split splitter else []
  parameters.push undefined for idx in [ 0 ... arity - 1 - parameters.length ] by 1
  @aux[ 'is-complete'   ] = no
  @aux[ 'texroute'      ] = texroute
  @aux[ 'jobname'       ] = jobname
  @aux[ 'splitter'      ] = splitter
  @aux[ 'method-name'   ] = method_name
  @aux[ 'parameters'    ] = parameters
  arity                   = method.length
  info '©56t', @aux
  method.call @, parameters..., handler
  #.........................................................................................................
  return null

# #.........................................................................................................
# @read_aux ( error ) =>
#   throw error if error?
#   warn @aux

#-----------------------------------------------------------------------------------------------------------
@read_aux = ( handler ) ->
  return null if @aux[ 'is-complete' ]
  #.........................................................................................................
  texroute  = @aux[ 'texroute' ]
  jobname   = @aux[ 'jobname' ]
  # last_idx  = texroute.length - 1 - ( njs_path.extname texroute ).length
  # auxroute  = texroute[ 0 .. last_idx ].concat '.auxcopy'
  auxroute  = ( njs_path.join texroute, jobname ).concat '.auxcopy'
  #.........................................................................................................
  unless njs_fs.existsSync auxroute
    warn "unable to locate #{auxroute}; ignoring"
    eventually => handler null
    return null
  #.........................................................................................................
  @aux[ 'auxroute'  ] = auxroute
  @aux[ 'labels'    ] = labels = {}
  #.........................................................................................................
  @_lines_of auxroute, ( error, line, line_nr ) =>
    return handler error if error?
    if line is null
      postprocess()
      @aux[ 'is-complete' ] = yes
      return handler null
    #.......................................................................................................
    ### De-escaping characters: ###
    line = line.replace @read_aux.protectchar_matcher, ( $0, $1 ) =>
      return String.fromCharCode parseInt $1, 16
    #.......................................................................................................
    ### Compiling and evaluating CoffeeScript: ###
    coffee = null
    if ( match = line.match @read_aux.coffeescript_matcher )?
      coffee ?= require 'coffee-script'
      try
        source  = coffee.compile match[ 1 ], 'bare': yes, 'filename': auxroute
        x       = eval source
      catch error
        warn "unable to parse line #{line_nr} of #{auxroute}:"
        warn line
        warn rpr error
        return null
      switch type = TYPES.type_of x
        when 'pod'
          @aux[ name ] = value for name, value of x
        else
          warn "ignoring value of type #{type} on line #{line_nr} of #{auxroute}:\n#{rpr line}"
      return null
    #.......................................................................................................
    ### Parsing labels and references: ###
    if ( match = line.match @read_aux.newlabel_matcher )?
      [ ignore, label, ref, pageref, title, unknown, unknown, ] = match
      labels[ label ] =
        name:           label
        ref:            parseInt ref,     10
        pageref:        parseInt pageref, 10
        title:          title
      return null

  #---------------------------------------------------------------------------------------------------------
  postprocess = =>
    ### Postprocessing of the data delivered by the `\auxgeo` command.

    All resulting lemgths are in millimeters. `firstlinev` is the distance between the
    top of the paper and the top of the first line of text. Similarly, the implicit 1 inch distance in
    `\voffset` and `\hoffset` is being made explicit so that the reference point is shifted to the paper's
    top left corner.

    See http://www.ctex.org/documents/packages/layout/layman.pdf p9 and
    http://en.wikibooks.org/wiki/LaTeX/Page_Layout ###
    one_inch = 4736286
    if ( g = @aux[ 'geometry' ] )?
      for name, value of g
        value += one_inch if name is 'voffset'
        value += one_inch if name is 'hoffset'
        # g[ name ] = value / 27597261 * 148.5
        g[ name ] = ( Math.round value / 39158276 * 210 * 10000 + 0.5 ) / 10000
      g[ 'firstlinev' ] = g[ 'voffset' ] + g[ 'topmargin' ] + g[ 'headsep' ] + g[ 'headheight' ]
  #.........................................................................................................
  return null

#...........................................................................................................
### matcher for those uber-verbosely: `\protect \char "007B\relax` escaped characters: ###
@read_aux.protectchar_matcher = ///
  \\protect \s+ \\char \s+ "( [ 0-9 A-F ]+ )\\relax \s?
  ///g

#...........................................................................................................
### matcher for CoffeeScript: ###
@read_aux.coffeescript_matcher = ///
  ^ % \s+ coffee\s+ ( .+ ) $
  ///

### \newlabel{otherlabel}{{2}{3}} ###
### \newlabel{otherlabel}{{2}{3}{References}{section.2}{}} ###
### TAINT not sure whether this RegEx is backtracking-safe as per
  http://www.regular-expressions.info/catastrophic.html ###
@read_aux.newlabel_matcher = ///
  ^ \\newlabel \{ ( [^{}]+ ) \}
  \{
    \{ ( [0-9]* ) \}
    \{ ( [0-9]* ) \}
    (?:
      \{ ( [^{}]* ) \}
      \{ ( [^{}]* ) \}
      \{ ( [^{}]* ) \}
      )?
    \} $ ///

#-----------------------------------------------------------------------------------------------------------
@_lines_of = ( route, handler ) ->
  line_nr = 0
  #.........................................................................................................
  line_reader = new Line_by_line route
  line_reader.on 'error', ( error ) => handler error
  line_reader.on 'end',             => handler null, null
  #.........................................................................................................
  line_reader.on 'line',  ( line  ) =>
    line_nr += 1
    handler null, line, line_nr
  #.........................................................................................................
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@debug = ( message ) ->
  return echo() unless message?
  warn message
  return @_pen_debug message

#-----------------------------------------------------------------------------------------------------------
@_pen_debug = ( message ) ->
  message = @escape_error message
  return "\\textbf{\\textcolor{red}{#{message}}}"

#-----------------------------------------------------------------------------------------------------------
@echo = ( P... ) ->
  # whisper P...
  return _echo P...

#-----------------------------------------------------------------------------------------------------------
debug = @debug.bind @
echo  =  @echo.bind @


#===========================================================================================================
# SAMPLE COMMANDS
#-----------------------------------------------------------------------------------------------------------
@helo = ( name, handler ) ->
  # handler null, "{Hello, \\textcolor{blue}{#{@escape name}}!}"
  handler null, "{Hello, #{@escape name}!}"

#-----------------------------------------------------------------------------------------------------------
@page_and_line_nr = ( page_nr, line_nr ) ->
  page_nr     = parseInt page_nr, 10
  line_nr     = parseInt line_nr, 10
  return """
    Helo from NodeJS.
    This paragraph appears on page #{page_nr}, column ..., line #{line_nr}."""

#-----------------------------------------------------------------------------------------------------------
@show_geometry = ( handler ) ->
  @read_aux ( error ) =>
    return handler error if error?
    unless ( g = @aux[ 'geometry' ] )?
      # debug message
        # you may want to consider using `\\auxgeo` in your TeX source."""
      handler """unable to retrieve geometry info from #{@aux[ 'auxroute' ]};"""
    #.........................................................................................................
    R     = []
    names = ( name for name of g ).sort()
    #.........................................................................................................
    for name in names
      value = g[ name ]
      value = if value? then ( ( value.toFixed 2 ).concat ' mm' ) else './.'
      value = value.replace /-/g, '–'
      R.push "#{name} & #{value}"
    #.........................................................................................................
    R = R.join '\\\\\n'
    R = "\\begin{tabular}{ | l | r | }\n\\hline\n#{R}\\\\\n\\hline\\end{tabular}"
    handler null, R

#-----------------------------------------------------------------------------------------------------------
@show_special_chrs = ( handler ) ->
  chr_by_names =
    'opening brace':    '{'
    'closing brace':    '}'
    'Dollar sign':      '$'
    'ampersand':        '&'
    'hash':             '#'
    'caret':            '^'
    'underscore':       '_'
    'wave':             '~'
    'percent sign':     '%'
  #.........................................................................................................
  R = []
  R.push "#{name} & #{@escape chr}" for name, chr of chr_by_names
  R = R.join '\\\\\n'
  R = "\\begin{tabular}{ | l | c | }\n\\hline\n#{R}\\\\\n\\hline\n\\end{tabular}"
  #.........................................................................................................
  handler null, R

#-----------------------------------------------------------------------------------------------------------
@clear_aux = ( handler ) ->
  delete @aux[ name ] for name of @aux
  handler null

#-----------------------------------------------------------------------------------------------------------
@show_aux = ( handler ) ->
  #.........................................................................................................
  # @read_aux ( error ) =>
  # return handler error if error?
  handler null, "\\begin{verbatim}\n#{rpr @aux}\n\\end{verbatim}"

#-----------------------------------------------------------------------------------------------------------
@ids_table = ( pattern, relsize = -5, handler ) ->
  pattern  = @ids_table.pattern_by_names[ pattern ] ? pattern
  pattern  = pattern.replace /\s+/g, ''
  #.........................................................................................................
  unless /^[_+*]{9}$/.test pattern
    return handler new Error """expected a string with 9 characters out of `_`, `+`, `*` or a valid
    pattern name, got #{rpr pattern}"""
  #.........................................................................................................
  fillers = @ids_table.fillers
  tl      = fillers[ pattern[ 0 ] ]
  tc      = fillers[ pattern[ 1 ] ]
  tr      = fillers[ pattern[ 2 ] ]
  ml      = fillers[ pattern[ 3 ] ]
  mc      = fillers[ pattern[ 4 ] ]
  mr      = fillers[ pattern[ 5 ] ]
  bl      = fillers[ pattern[ 6 ] ]
  bc      = fillers[ pattern[ 7 ] ]
  br      = fillers[ pattern[ 8 ] ]
  handler null, """
    \\begingroup%
    \\renewcommand{\\arraystretch}{0}%
    \\setlength{\\tabcolsep}{0mm}%
    \\jzrfont\\relsize{#{relsize}}%
    \\begin{tabu} to 20mm { | c | c | c | }%
    \\hline
    {\\color{red}\\rule[0mm]{0mm}{0.8em}}#{tl}&#{tc}&#{tr}\\\\
    \\hline
    {\\color{red}\\rule[0mm]{0mm}{0.8em}}#{ml}&#{mc}&#{mr}\\\\
    \\hline
    {\\color{red}\\rule[0mm]{0mm}{0.8em}}#{bl}&#{bc}&#{br}\\\\
    \\hline%
    \\end{tabu}%
    \\endgroup%
    """
#...........................................................................................................
@ids_table.fillers =
    '_':     "\ue020"
    '+':     "\ue021"
    '*':     "\ue022"

#...........................................................................................................
@ids_table.negate = ( pattern ) ->
  R = @ids_table.pattern_by_names[ pattern ] ? pattern
  R = R.replace /_/g,   'E'
  R = R.replace /\*/g,  '_'
  R = R.replace /E/g,   '*'
  return R
#...........................................................................................................
@ids_table.negate = @ids_table.negate.bind @

#...........................................................................................................
@get_operator_method = ( operator_name ) ->
  #.........................................................................................................
  inner = ( pattern_a, pattern_b ) =>
    table     = @ids_table.truth_tables[ operator_name ]
    R         = []
    #.......................................................................................................
    for idx in [ 0 .. 8 ]
      chr_a = pattern_a[ idx ]
      chr_b = pattern_b[ idx ]
      idx_a = @ids_table.trit_by_chrs[ chr_a ]
      idx_b = @ids_table.trit_by_chrs[ chr_b ]
      R.push table[ idx_a * 3 + idx_b ]
    #.......................................................................................................
    return R
  #.........................................................................................................
  return ( patterns... ) =>
    throw new Error "need at least 2 arguments, got #{arity}" unless ( arity = patterns.length ) >= 1
    #.......................................................................................................
    for pattern, idx in patterns
      pattern         = @ids_table.pattern_by_names[ pattern ] ? pattern
      patterns[ idx ] = pattern.replace /\s+/g, ''
    #.......................................................................................................
    R = patterns[ 0 ]
    for idx in [ 1 ... arity ]
      R = inner R, patterns[ idx ]
    #.......................................................................................................
    return R.join ''

#...........................................................................................................
### trit: trinary digit; https://en.wikipedia.org/wiki/Three-valued_logic ###
@ids_table.trit_by_chrs =
  '_':  0
  '+':  1
  '*':  2

#...........................................................................................................
@ids_table.truth_tables = _truth_tables =
  #.........................................................................................................
  'and': """
        ___
        _+*
        _**
  """
  #.........................................................................................................
  'andor': """
        __+
        _+*
        +**
  """
  #.........................................................................................................
  'or': """
        __*
        _+*
        ***
  """

#...........................................................................................................
_self = @
do ->
  for name, pattern of _truth_tables
    _truth_tables[ name ] = pattern.replace /\s+/g, ''
    _self.ids_table[ name ] = _self.get_operator_method.call _self, name

#...........................................................................................................
@ids_table.rotate = ( pattern, degrees = 90 ) ->
  pattern   = @ids_table.pattern_by_names[ pattern ] ? pattern
  P         = pattern.replace /\s+/g, ''
  steps     = Math.abs degrees / 90
  return P if steps is 0
  direction = if degrees is 0 then 0 else ( if degrees < 0 then -1 else +1 )
  R         = ( chr for chr in P )
  for idx in [ 0 ... steps ]
    if direction is 1
      [ R[ 0 ], R[ 1 ], R[ 2 ], R[ 3 ], R[ 4 ], R[ 5 ], R[ 6 ], R[ 7 ], R[ 8 ], ] = \
      [ R[ 6 ], R[ 3 ], R[ 0 ], R[ 7 ], R[ 4 ], R[ 1 ], R[ 8 ], R[ 5 ], R[ 2 ], ]
    else
      [ R[ 0 ], R[ 1 ], R[ 2 ], R[ 3 ], R[ 4 ], R[ 5 ], R[ 6 ], R[ 7 ], R[ 8 ], ] = \
      [ R[ 2 ], R[ 5 ], R[ 8 ], R[ 1 ], R[ 4 ], R[ 7 ], R[ 0 ], R[ 3 ], R[ 6 ], ]
  #.........................................................................................................
  return R.join ''
#...........................................................................................................
@ids_table.rotate = @ids_table.rotate.bind @

#...........................................................................................................
@ids_table.pattern_by_names = patterns =
  'empty':                '___ ___ ___'
  'full':                 '*** *** ***'
  #.........................................................................................................
  'top':                  '*** +++ ___'
  'center-beam':          '+++ *** +++'
  'bottom':               '___ +++ ***'
  #.........................................................................................................
  'left':                 '*+_ *+_ *+_'
  'middle-beam':          '+*+ +*+ +*+'
  'right':                '_+* _+* _+*'
  #.........................................................................................................
  'top-left-corner':      '*+_ ++_ ___'
  #.........................................................................................................
  'top-I':                '_*_ _+_ ___'
#...........................................................................................................
patterns[ 'top-right-corner'    ] = @ids_table.rotate 'top-left-corner',      90
patterns[ 'bottom-right-corner' ] = @ids_table.rotate 'top-left-corner',      180
patterns[ 'bottom-left-corner'  ] = @ids_table.rotate 'top-left-corner',      -90
patterns[ 'bottom-right-L'      ] = @ids_table.negate 'top-left-corner'
patterns[ 'bottom-left-L'       ] = @ids_table.negate 'top-right-corner'
patterns[ 'top-left-L'          ] = @ids_table.negate 'bottom-right-corner'
patterns[ 'top-right-L'         ] = @ids_table.negate 'bottom-left-corner'
patterns[ 'right-I'             ] = @ids_table.rotate 'top-I',                90
patterns[ 'bottom-I'            ] = @ids_table.rotate 'top-I',                180
patterns[ 'left-I'              ] = @ids_table.rotate 'top-I',                -90
patterns[ 'top-C'               ] = @ids_table.negate 'bottom-I'
patterns[ 'right-C'             ] = @ids_table.negate 'left-I'
patterns[ 'bottom-C'            ] = @ids_table.negate 'top-I'
patterns[ 'left-C'              ] = @ids_table.negate 'right-I'
patterns[ 'inner-O'             ] = @ids_table.and 'top', 'right', 'bottom', 'left'
patterns[ 'outer-O'             ] = @ids_table.or  'top', 'right', 'bottom', 'left'
# patterns[ 'top-left-L' ] = @ids_table.negate patterns[ 'top-left-corner' ]



#===========================================================================================================
# SERIALIZATION
#-----------------------------------------------------------------------------------------------------------
@_escape_replacements = [
  [ ///  \\  ///g,  '\\textbackslash{}',    ]
  [ ///  \{  ///g,  '\\{',                  ]
  [ ///  \}  ///g,  '\\}',                  ]
  [ ///  &   ///g,  '\\&',                  ]
  [ ///  \$  ///g,  '\\$',                  ]
  [ ///  \#  ///g,  '\\#',                  ]
  [ ///  %   ///g,  '\\%',                  ]
  [ ///  _   ///g,  '\\_',                  ]
  [ ///  \^  ///g,  '\\textasciicircum{}',  ]
  [ ///  ~   ///g,  '\\textasciitilde{}',   ]
  # '`'   # these two are very hard to catch when TeX's character handling is switched on
  # "'"   #
  ]

#-----------------------------------------------------------------------------------------------------------
@escape = ( text ) ->
  R = text
  for [ matcher, replacement, ] in @_escape_replacements
    R = R.replace matcher, replacement
  return R

#-----------------------------------------------------------------------------------------------------------
@escape_error = ( text ) ->
  ### Escape all characters that would cause difficulties with TeX's `\verbatiminput`. ###
  return ( @escape text ).replace /\n+/g, '\\par\n\n'

#===========================================================================================================
# HTTP SERVER
#-----------------------------------------------------------------------------------------------------------


############################################################################################################
@main() if process.argv.length > 2












