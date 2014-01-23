




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
#...........................................................................................................


#-----------------------------------------------------------------------------------------------------------
@dispatch = ( provider, texroute, splitter, command, parameter, handler ) ->
  jobname     = njs_path.basename texroute
  texroute    = njs_path.dirname  texroute
  warn '@32x', texroute, jobname, splitter, command, parameter
  method_name = command.replace /-/g, '_'
  method      = provider[ method_name ]
  arity       = method.length
  #.........................................................................................................
  return handler "unknown method #{rpr method_name}" unless method?
  #.........................................................................................................
  if parameter?
    parameter   = @decode_literal_utf8 parameter
    parameters  = if parameter.length is 0 then [] else parameter.split splitter
  #.........................................................................................................
  else
    parameter   = ''
    parameters  = []
  #.........................................................................................................
  parameters.push undefined for idx in [ 0 ... arity - 1 - parameters.length ] by 1
  #.........................................................................................................
  @aux[ 'is-complete'   ] = no
  @aux[ 'texroute'      ] = texroute
  @aux[ 'auxroute'      ] = ( njs_path.join texroute, jobname ).concat '.auxcopy'
  @aux[ 'jobname'       ] = jobname
  @aux[ 'splitter'      ] = splitter
  @aux[ 'method-name'   ] = method_name
  @aux[ 'parameters'    ] = parameters
  info '©56t', @aux
  method.call provider, parameters..., handler
  #.........................................................................................................
  return null


#===========================================================================================================
# AUX OBJECT
#-----------------------------------------------------------------------------------------------------------
# Object to represent entries in (a copy of) the `*.aux` file:
@aux = {}

#-----------------------------------------------------------------------------------------------------------
@read_aux = ( handler ) ->
  return null if @aux[ 'is-complete' ]
  #.........................................................................................................
  texroute  = @aux[ 'texroute' ]
  jobname   = @aux[ 'jobname' ]
  auxroute  = @aux[ 'auxroute' ]
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

#-----------------------------------------------------------------------------------------------------------
@decode_literal_utf8 = ( text ) ->
  ### The `Buffer ... toString` steps decode literal UTF-8 in the request ###
  ### TAINT the NodeJS docs say: [the 'binary'] encoding method is deprecated and should be avoided
    [...] [it] will be removed in future versions of Node ###
  return ( new Buffer text, 'binary' ).toString 'utf-8'








