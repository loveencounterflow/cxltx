




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
  info "©45 argv: #{rpr process.argv}"
  texroute    = process.argv[ 2 ]
  command     = process.argv[ 3 ]
  method_name = command.replace /-/g, '_'
  parameter   = process.argv[ 4 ]
  ### TAINT we naïvely split on comma, which is not robust in case e.g. string or list literals contain
  that character. Instead, we should be doing parsing (eg. using JSON? CoffeeScript expressions /
  signatures?) ###
  P           = if ( parameter? and parameter.length > 0 ) then parameter.split ',' else []
  #.........................................................................................................
  @dispatch texroute, method_name, P..., ( error, result ) =>
    #.......................................................................................................
    if error?
      # warn    error
      debug   error
    #.......................................................................................................
    if result?
      # whisper result
      echo    result
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@dispatch = ( texroute, method_name, P..., handler ) ->
  return handler "Unknown command: #{rpr command}" unless @[ method_name ]?
  @aux[ 'is-complete'   ] = no
  @aux[ 'texroute'      ] = texroute
  @aux[ 'method-name'   ] = method_name
  @aux[ 'parameters'    ] = P
  info '©56t', P
  @[ method_name ] P..., handler
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
  last_idx  = texroute.length - 1 - ( njs_path.extname texroute ).length
  auxroute  = texroute[ 0 .. last_idx ].concat '.auxcopy'
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
  return @_pen_debug message

#-----------------------------------------------------------------------------------------------------------
@_pen_debug = ( message ) ->
  return "\\textbf{\\textcolor{red}{#{@escape message.replace /\n+/g, '\\par\\n\\n' }}}"

#-----------------------------------------------------------------------------------------------------------
@echo = ( P... ) ->
  whisper P...
  return _echo P...

#-----------------------------------------------------------------------------------------------------------
debug = @debug.bind @
echo  = @echo.bind @


#===========================================================================================================
# SAMPLE COMMANDS
#-----------------------------------------------------------------------------------------------------------
@helo = ( name, handler ) ->
  handler null, "{Hello, \\textcolor{blue}{#{@escape name}}!}"

#-----------------------------------------------------------------------------------------------------------
@page_and_line_nr = ( page_nr, line_nr ) ->
  page_nr     = parseInt page_nr, 10
  line_nr     = parseInt line_nr, 10
  return """
    Helo from NodeJS.
    This paragraph appears on page #{page_nr}, column ..., line #{line_nr}."""

#-----------------------------------------------------------------------------------------------------------
@show_geometry = ->
  unless ( g = @aux[ 'geometry' ] )?
    message = """unable to retrieve geometry info from #{@aux[ 'auxroute' ]};"""
    debug message
      # you may want to consider using `\\auxgeo` in your TeX source."""
    return message
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
  return R

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
@show_aux = ( handler ) ->
  #.........................................................................................................
  @read_aux ( error ) =>
    return handler error if error?
    handler null, "\\begin{verbatim}#{rpr @aux}\\end{verbatim}"


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


#===========================================================================================================
# HTTP SERVER
#-----------------------------------------------------------------------------------------------------------


############################################################################################################
@main() if process.argv.length > 2












