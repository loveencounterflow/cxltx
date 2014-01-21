

############################################################################################################
# njs_util                  = require 'util'
# njs_fs                    = require 'fs'
# njs_path                  = require 'path'
njs_url                   = require 'url'
#...........................................................................................................
# BAP                       = require 'coffeenode-bitsnpieces'
TYPES                     = require 'coffeenode-types'
TRM                       = require 'coffeenode-trm'
rpr                       = TRM.rpr.bind TRM
badge                     = 'CXLTX/server'
log                       = TRM.get_logger 'plain',     badge
info                      = TRM.get_logger 'info',      badge
whisper                   = TRM.get_logger 'whisper',   badge
debug                     = TRM.get_logger 'debug',     badge
alert                     = TRM.get_logger 'alert',     badge
warn                      = TRM.get_logger 'warn',      badge
help                      = TRM.get_logger 'help',      badge
_echo                     = TRM.echo.bind TRM
#...........................................................................................................
express                   = require 'express'
#...........................................................................................................
CXLTX                     = require './main'
MULTIMIX                  = require 'coffeenode-multimix'
#...........................................................................................................
sample_provider           = require './sample-provider'
ids_provider              = require './ids-provider'
#...........................................................................................................
provider                  = MULTIMIX.compose sample_provider, ids_provider



#-----------------------------------------------------------------------------------------------------------
server_options =
  'host':         '127.0.0.1'
  'port':         8910

#-----------------------------------------------------------------------------------------------------------
@request_count = 0

#-----------------------------------------------------------------------------------------------------------
@main = ->
  #---------------------------------------------------------------------------------------------------------
  process_request = ( request, handler ) =>
    @request_count += 1
    RC              = @request_count
    #.......................................................................................................
    # debug "©45f #{RC} rq.params:  ", request.params
    { texroute
      jobname
      splitter
      command
      parameter } = request.params
    #.......................................................................................................
    debug "©45f #{RC} url:        ", request[ 'url' ]
    debug "©45f #{RC} texroute:   ", texroute
    debug "©45f #{RC} jobname:    ", jobname
    debug "©45f #{RC} splitter:   ", splitter
    debug "©45f #{RC} command:    ", command
    debug "©45f #{RC} parameter:  ", parameter
    #.......................................................................................................
    ### TAINT rewrite as middleware ###
    unless texroute? and command? # and parameters?
      return handler "need 2 or 3 parts in URL route"
    #.......................................................................................................
    # texroute    = @decode_url_crumb texroute
    # command     = @decode_url_crumb command
    #.......................................................................................................
    CXLTX.dispatch provider, texroute, jobname, splitter, command, parameter, handler
    #.......................................................................................................
    return null
  #---------------------------------------------------------------------------------------------------------
  return ( request, response ) =>
    #.......................................................................................................
    process_request request, ( error, result ) =>
      #.....................................................................................................
      if error?
        error = rpr error unless ( TYPES.type_of error ) is 'text'
        warn "©23 #{@request_count} error:", error
        status  = 500
        headers = 'Content-Type': 'text/plain'
        response.writeHeader status, headers
        response.write CXLTX.escape_error error
        return response.end()
      #.....................................................................................................
      whisper "©23 #{@request_count} result:", result
      status  = 200
      headers = 'Content-Type': 'text/plain'
      response.writeHeader status, headers
      response.write result if result?
      return response.end()
    #.......................................................................................................
    return null


#-----------------------------------------------------------------------------------------------------------
# APP
#-----------------------------------------------------------------------------------------------------------
app   = express()
view  = @main()

#-----------------------------------------------------------------------------------------------------------
# MIDDLEWARE
#-----------------------------------------------------------------------------------------------------------
app.use express.logger 'format': 'dev'


#-----------------------------------------------------------------------------------------------------------
# ENDPOINTS
#-----------------------------------------------------------------------------------------------------------
main = @main()
app.get '/:texroute/:jobname/:splitter/:command/:parameter',  main
app.get '/:texroute/:jobname/:splitter/:command',              main
# app.use view 'not_found'


#===========================================================================================================
# SERVING
#-----------------------------------------------------------------------------------------------------------
app.listen server_options[ 'port' ], ( error ) ->
  throw error if error?
  log TRM.green "listening to #{server_options[ 'host' ]}:#{server_options[ 'port' ]}"


############################################################################################################
# @serve()
