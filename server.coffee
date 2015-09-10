st = require('st')
http = require('http')
assert = require('assert')

redirects = require('./redirects')

originalProtocol = (req) ->
  # Heroku, OpenShift and probably others terminate HTTPS for us and indicate it via an HTTP header
  # https://devcenter.heroku.com/articles/http-routing#heroku-headers
  # https://help.openshift.com/hc/en-us/articles/202398810-How-to-redirect-traffic-to-HTTPS-
  return req.headers['x-forwarded-proto'] || 'http'

logRequest = (req, res) ->
  # Note: full URLs might still appear in other platform logs, e.g. heroku[router]
  anonimizedUrl = req.url.replace(/([?&])doc=[^&]*/, '$1doc=...')
  # TODO: also log our responses, especially errors.
  console.log('[%s] %s %s %s %s < %s %s', new Date().toISOString(), req.method, originalProtocol(req), req.headers.host, anonimizedUrl, req.socket.remoteAddress, req.headers['user-agent'])

handleStatic = st({
  path: process.cwd()
  index: 'index.html'
  passthrough: false
})

handleRequest = (req, res) ->
  redir = redirects.computeRedirect(req.method, originalProtocol(req), req.headers.host, req.url)
  if redir?
    res.writeHead(redir.status, redir.headers)
    console.log('[%s]   %s %s > %s', new Date().toISOString(), redir.status, JSON.stringify(redir.headers), req.socket.remoteAddress)
    res.end()
  else
    handleStatic(req, res)

exports.main = (port) ->
  port = port || process.env.PORT || process.env.OPENSHIFT_NODEJS_PORT || 8080
  listen_on_address = process.env.OPENSHIFT_NODEJS_IP || '0.0.0.0'  # INADDR_ANY
  httpServer = http.createServer()
  # TODO: Use Express to chain handlers.
  httpServer.on 'request', logRequest
  httpServer.on 'request', handleRequest

  httpServer.on 'listening', ->
    console.log('HttpServer up, e.g. http://localhost:' + port + '/?doc=demo');
  httpServer.listen(port, listen_on_address)
  return httpServer

if module is require.main
  exports.main()
