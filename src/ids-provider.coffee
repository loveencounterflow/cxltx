
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

