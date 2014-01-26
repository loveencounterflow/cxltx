


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
debug                     = TRM.get_logger 'debug',     badge
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
  CXLTX.read_aux ( error, aux ) =>
    return handler error if error?
    unless ( g = aux[ 'geometry' ] )?
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
  handler null, ''

#-----------------------------------------------------------------------------------------------------------
@show_aux = ( handler ) ->
  handler null, "\\begin{verbatim}\n#{rpr CXLTX.aux}\n\\end{verbatim}"

#-----------------------------------------------------------------------------------------------------------
@show_labels = ( handler ) ->
  CXLTX.read_aux ( error, aux ) =>
    return handler error if error?
    R       = []
    #.......................................................................................................
    labels = []
    for name, label of aux[ 'labels' ]
      if label[ 'is-duplicate' ]
        for duplicate_label in aux[ 'duplicate-labels' ][ name ]
          labels.push duplicate_label
        continue
      labels.push label
    #.......................................................................................................
    labels.sort ( a, b ) ->
      ### TAINT what with roman numbers? ###
      pageref_a = parseInt a[ 'pageref' ], 10
      pageref_b = parseInt b[ 'pageref' ], 10
      ref_a     = a[ 'ref' ]
      ref_b     = b[ 'ref' ]
      a_is_dup  = a[ 'is-duplicate' ]
      b_is_dup  = b[ 'is-duplicate' ]
      return -1 if a_is_dup and not b_is_dup
      return +1 if b_is_dup and not a_is_dup
      return -1 if pageref_a < pageref_b
      return +1 if pageref_a > pageref_b
      return -1 if ref_a < ref_b
      return +1 if ref_a > ref_b
      return  0
    debug labels
    #.......................................................................................................
    # R.push "\\def\\mystrut{\\vrule height 2mmpt depth 1mm width 1pt} "
    R.push "\\begin{tabular}{ | r | l | l | l | l | }"
    R.push "\\hline"
    R.push "& name & pageref & ref & title\\\\"
    R.push "\\hline"
    for label in labels
      dupmark = if label[ 'is-duplicate' ] then '!' else ''
      R.push "#{dupmark} & #{label[ 'name' ]} & #{label[ 'pageref' ]} & #{label[ 'ref' ]} & #{label[ 'title' ]}\\\\"
    R.push "\\hline"
    R.push "\\end{tabular}"
    #.......................................................................................................
    handler null, R.join '\n'

#-----------------------------------------------------------------------------------------------------------
@add = ( P..., handler ) ->
  P[ idx ] = parseFloat p, 10 for p, idx in P
  debug P
  R   = 0
  R  += p for p in P
  return handler new Error "unable to sum up #{rpr P}" unless isFinite R
  handler null, R



