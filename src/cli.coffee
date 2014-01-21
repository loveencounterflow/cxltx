

############################################################################################################
CXLTX                     = require './main'
MULTIMIX                  = require 'coffeenode-multimix'
#...........................................................................................................
sample_provider           = require './sample-provider'
ids_provider              = require './ids-provider'
#...........................................................................................................
provider                  = MULTIMIX.compose sample_provider, ids_provider

#-----------------------------------------------------------------------------------------------------------
@main = ->
  # info "©45 argv: #{rpr process.argv}"
  texroute    = process.argv[ 2 ]
  jobname     = process.argv[ 3 ]
  splitter    = process.argv[ 4 ]
  command     = process.argv[ 5 ]
  parameter   = process.argv[ 6 ]
  #.........................................................................................................
  CXLTX.dispatch provider, texroute, jobname, splitter, command, parameter, ( error, result ) =>
    #.......................................................................................................
    CXLTX.echo CXLTX.debug error if error?
    CXLTX.echo result if result?
  #.........................................................................................................
  return null


############################################################################################################
@main()








