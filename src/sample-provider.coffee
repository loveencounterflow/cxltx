


############################################################################################################
# njs_util                  = require 'util'
# njs_fs                    = require 'fs'
# njs_path                  = require 'path'
#...........................................................................................................
# BAP                       = require 'coffeenode-bitsnpieces'
# TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
rpr                       = TRM.rpr.bind TRM
badge                     = 'CXLTX/sample-provider'
log                       = TRM.get_logger 'plain',     badge
info                      = TRM.get_logger 'info',      badge
whisper                   = TRM.get_logger 'whisper',   badge
alert                     = TRM.get_logger 'alert',     badge
warn                      = TRM.get_logger 'warn',      badge
help                      = TRM.get_logger 'help',      badge
echo                      = TRM.echo.bind TRM
#...........................................................................................................
CXLTX                     = require './main'


#===========================================================================================================
# SAMPLE COMMANDS
#-----------------------------------------------------------------------------------------------------------
@helo = ( name, handler ) ->
  # handler null, "{Hello, \\textcolor{blue}{#{CXLTX.escape name}}!}"
  handler null, "{Hello, #{CXLTX.escape name}!}"

#-----------------------------------------------------------------------------------------------------------
@page_and_line_nr = ( page_nr, line_nr, handler ) ->
  page_nr     = parseInt page_nr, 10
  line_nr     = parseInt line_nr, 10
  handler null, """
    Helo from NodeJS.
    This paragraph appears on page #{page_nr}, column ..., line #{line_nr}."""

#-----------------------------------------------------------------------------------------------------------
@show_geometry = ( handler ) ->
  CXLTX.read_aux ( error ) =>
    return handler error if error?
    unless ( g = CXLTX.aux[ 'geometry' ] )?
      # debug message
        # you may want to consider using `\\auxgeo` in your TeX source."""
      return handler "unable to retrieve geometry info from #{CXLTX.aux[ 'auxroute' ]};"
    #.......................................................................................................
    R     = []
    names = ( name for name of g ).sort()
    #.......................................................................................................
    for name in names
      value = g[ name ]
      value = if value? then ( ( value.toFixed 2 ).concat ' mm' ) else './.'
      value = value.replace /-/g, '–'
      R.push "#{name} & #{value}"
    #.......................................................................................................
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
  R.push "#{name} & #{CXLTX.escape chr}" for name, chr of chr_by_names
  R = R.join '\\\\\n'
  R = "\\begin{tabular}{ | l | c | }\n\\hline\n#{R}\\\\\n\\hline\n\\end{tabular}"
  #.........................................................................................................
  handler null, R

#-----------------------------------------------------------------------------------------------------------
@clear_aux = ( handler ) ->
  delete CXLTX.aux[ name ] for name of CXLTX.aux
  handler null

#-----------------------------------------------------------------------------------------------------------
@show_aux = ( handler ) ->
  #.........................................................................................................
  # CXLTX.read_aux ( error ) =>
  # return handler error if error?
  handler null, "\\begin{verbatim}\n#{rpr CXLTX.aux}\n\\end{verbatim}"
