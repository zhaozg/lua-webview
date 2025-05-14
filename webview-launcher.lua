local webviewLib = require('webview')

-- This module allows to launch a web page that could executes custom Lua code.

-- The webview library may change locale to native and thus mislead the JSON libraries.
if os.setlocale() == 'C' then
  -- Default locale is 'C' at startup, set native locale
  os.setlocale('')
end

-- Load JSON module
local status, jsonLib = pcall(require, 'cjson')
if not status then
  status, jsonLib = pcall(require, 'dkjson')
  if not status then
    -- provide a basic JSON implementation suitable for basic types
    local escapeMap = { ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t', ['"'] = '\\"', ['\\'] = '\\\\', ['/'] = '\\/', }
    local revertMap = {}; for c, s in pairs(escapeMap) do revertMap[s] = c; end
    jsonLib = {
      null = {},
      decode = function(value)
        if string.sub(value, 1, 1) == '"' and string.sub(value, -1, -1) == '"' then
          return string.gsub(string.gsub(string.sub(value, 2, -2), '\\u(%x%x%x%x)', function(s)
            return string.char(tonumber(s, 16))
          end), '\\.', function(s)
            return revertMap[s] or ''
          end)
        elseif string.match(value, '^%s*[%-%+]?%d[%d%.%s]*$') then
          return tonumber(value)
        elseif (value == 'true') or (value == 'false') then
          return value == 'true'
        elseif value == 'null' then
          return jsonLib.null
        end
        return nil
      end,
      encode = function(value)
        local valueType = type(value)
        if valueType == 'boolean' then
          return value and 'true' or 'false'
        elseif valueType == 'number' then
          return (string.gsub(tostring(value), ',', '.', 1))
        elseif valueType == 'string' then
          return '"'..string.gsub(value, '[%c"/\\]', function(c)
            return escapeMap[c] or string.format('\\u%04X', string.byte(c))
          end)..'"'
        elseif value == jsonLib.null then
          return 'null'
        end
        return 'undefined'
      end
    }
  end
end

-- OS file separator
local fileSeparator = string.sub(package.config, 1, 1) or '/'

-- Load file system module
local fsLib
status, fsLib = pcall(require, 'luv')
if status then
  local uvLib = fsLib
  fsLib = {
    currentdir = uvLib.cwd,
    attributes = uvLib.fs_stat,
  }
else
  status, fsLib = pcall(require, 'lfs')
  if not status then
    -- provide a basic file system implementation
    fsLib = {
      currentdir = function()
        local f = io.popen(fileSeparator == '\\' and 'cd' or 'pwd')
        if f then
          local d = f:read()
          f:close()
          return d
        end
        return '.'
      end,
      attributes = function(p)
        local f = io.open(p)
        if f then
          f:close()
          return {}
        end
        return nil
      end,
    }
  end
end

-- Lua code injected to provide default local variables
local localContextLua = 'local evalJs, callJs, expose = context.evalJs, context.callJs, context.expose; '

local function exposeFunctionJs(name, remove)
  local nameJs = "'"..name.."'"
  if remove then
    return 'delete webview['..nameJs..'];\n';
  end
  return 'webview['..nameJs..'] = function(value, callback) {'..
    'webview.invokeLua('..nameJs..', value, callback);'..
    '};\n'
end

-- Initializes the web view and provides a global JavaScript webview object
local function initializeJs(webview, functionMap, options)
  local jsContent = [[
  if (typeof window.webview === 'object') {
    console.log('webview object already exists');
  } else {
    console.log('initialize webview object');
    var webview = {};
    window.webview = webview;
    var refs = {};
    var callbackToRef = function(callback, delay) {
      if (typeof callback === 'function') {
        var ref;
        var id = setTimeout(function() {
          var cb = refs[ref];
          if (cb) {
            delete refs[ref];
            cb('timeout');
          }
        }, delay);
        ref = id.toString(36);
        refs[ref] = callback;
        return ref;
      }
      return null;
    };
    webview.callbackRef = function(ref, reason, result) {
      var id = parseInt(ref, 36);
      clearTimeout(id);
      var callback = refs[ref];
      if (callback) {
        delete refs[ref];
        callback(reason, result);
      }
    };
    webview.invokeLua = function(name, value, callback, delay) {
      var kind = ':', data = '';
      if (typeof value === 'string') {
        data = value;
      } else if (typeof value === 'function') {
        delay = callback;
        callback = value;
      } else if (value !== undefined) {
        kind = ';';
        data = JSON.stringify(value);
      }
      var message;
      var ref = callbackToRef(callback, delay || 30000);
      if (ref) {
        message = '#' + name + kind + ref + ';' + data;
      } else {
        message = name + kind + data;
      }
      window.external.invoke(message);
    };
  ]]
  if options and options.captureError then
    jsContent = jsContent..[[
      window.onerror = function(message, source, lineno, colno, error) {
        var message = '' + message; // Just "Script error." when occurs in different origin
        if (source) {
          message += '\n  source: ' + source + ', line: ' + lineno + ', col: ' + colno;
        }
        if (error) {
          message += '\n  error: ' + error;
        }
        window.external.invoke(':error:' + message);
        return true;
      };
    ]]
  end
  if options and options.useJsTitle then
    jsContent = jsContent..[[
      if (document.title) {
        window.external.invoke('title:' + document.title);
      }
    ]]
  end
  if functionMap then
    for name in pairs(functionMap) do
      jsContent = jsContent..exposeFunctionJs(name)
    end
  end
  if options and options.luaScript then
    jsContent = jsContent..[[
      var evalLuaScripts = function() {
        var scripts = document.getElementsByTagName('script');
        for (var i = 0; i < scripts.length; i++) {
          var script = scripts[i];
          if (script.getAttribute('type') === 'text/lua') {
            var src = script.getAttribute('src');
            if (src) {
              window.external.invoke('evalLuaSrc:' + src);
            } else {
              window.external.invoke('evalLua:' + script.text);
            }
          }
        }
      };
      if (document.readyState !== 'loading') {
        evalLuaScripts();
      } else {
        document.addEventListener('DOMContentLoaded', evalLuaScripts);
      }
    ]]
  end
  jsContent = jsContent..[[
    var completeInitialization = function() {
      if (typeof window.onWebviewInitalized === 'function') {
        webview.evalJs("window.onWebviewInitalized(window.webview);");
      }
    };
    if (document.readyState === 'complete') {
      completeInitialization();
    } else {
      window.addEventListener('load', completeInitialization);
    }
  }
  ]]
  webviewLib.eval(webview, jsContent, true)
end

-- Prints error message to the error stream
local function printError(value)
  io.stderr:write('WebView Launcher - '..tostring(value)..'\n')
end

local function callbackJs(webview, ref, reason, result)
  webviewLib.eval(webview, 'if (webview) {'..
    'webview.callbackRef("'..ref..'", '..jsonLib.encode(reason)..', '..jsonLib.encode(result)..');'..
    '}', true)
end

local function handleCallback(callback, reason, result)
  if callback then
    callback(reason, result)
  elseif reason then
    printError(reason)
  end
end

-- Executes the specified Lua code
local function evalLua(value, callback, context, webview)
  local f, err = load('local callback, context, webview = ...; '..localContextLua..value)
  if f then
    f(callback, context, webview)
  else
    handleCallback(callback, 'Error '..tostring(err)..' while loading '..tostring(value))
  end
end

-- Toggles the web view full screen on/off
local function fullscreen(value, callback, _, webview)
  webviewLib.fullscreen(webview, value == 'true')
  handleCallback(callback)
end

-- Sets the web view title
local function setTitle(value, callback, _, webview)
  webviewLib.title(webview, value)
  handleCallback(callback)
end

-- Terminates the web view
local function terminate(_, callback, _, webview)
  webviewLib.terminate(webview, true)
  handleCallback(callback)
end

-- Executes the specified Lua file relative to the URL
local function evalLuaSrc(value, callback, context, webview)
  local content
  if context.luaSrcPath then
    local path = context.luaSrcPath..fileSeparator..string.gsub(value, '[/\\]+', fileSeparator)
    local file = io.open(path)
    if file then
      content = file:read('a')
      file:close()
    end
  end
  if content then
    evalLua(content, callback, context, webview)
  else
    handleCallback(callback, 'Cannot load Lua file from src "'..tostring(value)..'"')
  end
end

-- Evaluates the specified JS code
local function evalJs(value, callback, _, webview)
  webviewLib.eval(webview, value, true)
  handleCallback(callback)
end

-- Calls the specified JS function name,
-- the arguments are JSON encoded then passed to the JS function
local function callJs(webview, functionName, ...)
  local argCount = select('#', ...)
  local args = {...}
  for i = 1, argCount do
    args[i] = jsonLib.encode(args[i])
  end
  local jsString = functionName..'('..table.concat(args, ',')..')'
  webviewLib.eval(webview, jsString, true)
end

-- internal dispatch callback
local function dispatch(uv, webview)
  local webexit, fired, uvwait = false, false, false
  webexit, fired = webviewLib.loop(webview, 'nowait')
  if webexit then return end
  uvwait = uv.run('nowait')

  local function mode()
    return (fired or uvwait) and 'nowait' or 'once'
  end

  while not uvwait do
    webexit, fired = webviewLib.loop(webview, mode())
    uvwait = uv.run(mode())
  end

  while not fired do
    uvwait = uv.run(mode())
    webexit, fired = webviewLib.loop(webview, mode())
  end

  return webexit
end

-- Creates the webview context and sets the callback and default functions
local function createContext(webview, options)
  local initialized = false

  -- Named requests callable from JS using window.external.invoke('name:value')
  -- Custom request can be registered using window.external.invoke('+name:Lua code')
  -- The Lua code has access to the string value, the evalJs() and callJs() functions
  local functionMap = {
    fullscreen = fullscreen,
    title = setTitle,
    terminate = terminate,
    evalLua = evalLua,
    evalLuaSrc = evalLuaSrc,
    evalJs = evalJs,
  }

  -- Defines the context that will be shared across Lua calls
  local context = {
    expose = function(name, fn)
      functionMap[name] = fn
      if initialized then
        webviewLib.eval(webview, exposeFunctionJs(name, not fn), true)
      end
    end,
    exposeAll = function(fnMap)
      local jsContent = ''
      for name, fn in pairs(fnMap) do
        functionMap[name] = fn
        jsContent = jsContent..exposeFunctionJs(name, not fn)
      end
      if initialized then
        webviewLib.eval(webview, jsContent, true)
      end

    end,
    -- Setup a Lua function to evaluates JS code
    evalJs = function(value)
      webviewLib.eval(webview, value, true)
    end,
    callJs = function(functionName, ...)
      callJs(webview, functionName, ...)
    end,
    callbackJs = function(ref, reason, result)
      callbackJs(webview, ref, reason, result)
    end,
    terminate = function()
      webviewLib.terminate(webview, true)
    end,
  }

  if options.uv then
    context.uv = options.uv
    context.dispatch = function(cb, ...)
      if cb then
        cb(...)
      else
        dispatch(context.uv, webview)
      end
    end
  end

  if options and type(options.expose) == 'table' then
    context.exposeAll(options.expose)
  end

  if options and type(options.context) == 'table' then
    for name, value in pairs(options.context) do
      context[name] = value
    end
  end

  -- Creates the web view callback that handles the JS requests coming from window.external.invoke()
  local handler = function(request)
    local flag, name, kind, value = string.match(request, '^(%A?)([%_%$%a][%_%$%w]*)([:;])(.*)$')
    if name then
      if flag == '' or flag == '#' then
        -- Look for the specified function
        local fn = functionMap[name]
        local callback, cbRef
        if fn then
          if flag == '#' then
            local ref, val = string.match(value, '^(%w+);(.*)$')
            if ref and val then
              value = val
              cbRef = ref
              callback = function(reason, result)
                callbackJs(webview, ref, reason, result)
              end
            else
              printError('Invalid reference request '..request)
              return
            end
          end
          local s, r
          if kind == ';' then
            s, r = pcall(jsonLib.decode, value)
            if s then
              value = r
            else
              handleCallback(callback, 'Fail to parse '..name..' JSON value "'..tostring(value)..'" due to '..tostring(r))
              return
            end
          end
          s, r = pcall(fn, value, callback, context, webview, cbRef)
          if not s then
            handleCallback(callback, 'Fail to execute '..name..' due to '..tostring(r))
          end
        else
          printError('Unknown function '..name)
        end
      elseif flag == '-' then
        context.expose(name)
      elseif flag == '+' then
        -- Registering the new function using the specified Lua code
        local injected = 'local value, callback, context, webview = ...; '
        local fn, err = load(injected..localContextLua..value)
        if fn then
          context.expose(name, fn)
        else
          printError('Error '..tostring(err)..' while loading '..tostring(value))
        end
      elseif name == 'error' and flag == ':' then
        printError(value)
      elseif name == 'init' and flag == ':' then
        initialized = true
        initializeJs(webview, functionMap, options)

        if options and options.initialize then
          options.initialize(webviewLib, webview, context, options)
        end
      else
        printError('Invalid flag '..flag..' for name '..name)
      end
    else
      printError('Invalid request #'..tostring(request and #request)..' "'..tostring(request)..'"')
    end
  end

  if options and options.initialize then
    initialized = true
    initializeJs(webview, functionMap, options)
  end

  return handler
end

local function escapeUrl(value)
  return string.gsub(value, "[ %c!#$%%&'()*+,/:;=?@%[%]]", function(c)
    return string.format('%%%02X', string.byte(c))
  end)
end

local function parseArgs(args)
  -- Default web content
  local url = 'data:text/html,'..escapeUrl([[<!DOCTYPE html>
  <html>
    <head>
      <title>Welcome WebView</title>
    </head>
    <script type="text/lua">
      print('You could specify an HTML file to launch as a command line argument.')
    </script>
    <body>
      <h1>Welcome !</h1>
      <p>You could specify an HTML file to launch as a command line argument.</p>
      <button onclick="window.external.invoke('terminate:')">Close</button>
    </body>
  </html>
  ]])

  local title
  local width = 800
  local height = 600
  local resizable = true
  local debug = false
  local eventMode = nil
  local initialize = true
  local luaScript = true
  local captureError = true
  local luaPath = false

  -- Parse command line arguments
  args = args or arg or {}
  local ctxArgs = {}
  local luaSrcPath = nil
  local urlArg

  for i = 1, #args do
    local name, value = string.match(args[i], '^%-%-wv%-([^=]+)=?(.*)$')
    if not name then
      if urlArg then
        table.insert(ctxArgs, args[i])
      else
        urlArg = args[i]
      end
    elseif name == 'size' and value then
      local w, h = string.match(value, '^(%d+)[xX-/](%d+)$')
      width = tonumber(w)
      height = tonumber(h)
    elseif name == 'title' and value then
      title = value
    elseif name == 'width' and tonumber(value) then
      width = tonumber(value)
    elseif name == 'height' and tonumber(value) then
      height = tonumber(value)
    elseif name == 'resizable' then
      resizable = value ~= 'false'
    elseif name == 'debug' then
      debug = value == 'true'
    elseif name == 'event' and (value == 'open' or value == 'main' or value == 'thread' or value == 'http') then
      eventMode = value
    elseif name == 'initialize' then
      initialize = value ~= 'false'
    elseif name == 'script' then
      luaScript = value ~= 'false'
    elseif name == 'captureError' then
      captureError = value ~= 'false'
    elseif name == 'luaPath' then
      luaPath = value == 'true'
    else
      print('Invalid argument', args[i])
      os.exit(22)
    end
  end

  -- Process URL argument
  if urlArg and urlArg ~= '' then
    if urlArg == '-h' or urlArg == '/?' or urlArg == '--help' then
      print('Launchs a WebView using the specified URL')
      print('Optional arguments: url --wv-title= --wv-width='..tostring(width)..' --wv-height='..tostring(height)..' --wv-resizable='..tostring(resizable))
      os.exit(0)
    end
    local protocol = string.match(urlArg, '^([^:]+):.+$')
    if protocol == 'http' or protocol == 'https' or protocol == 'file' or protocol == 'data' then
      url = urlArg
    else
      local filePath
      if string.match(urlArg, '^.:\\.+$') or string.match(urlArg, '^/.+$') then
        filePath = urlArg
      elseif fsLib then
        filePath = fsLib.currentdir()..fileSeparator..urlArg
      end
      if not filePath then
        print('Invalid URL, to launch a file please use an absolute path')
        os.exit(22)
      end
      luaSrcPath = string.match(filePath, '^(.*)[/\\][^/\\]+$')
      url = 'file://'..filePath
    end
  end

  if luaSrcPath and luaPath then
    package.path = package.path..';'..luaSrcPath..'/?.lua'
  end

  return url, {
    title = title or 'Web View',
    width = width,
    height = height,
    resizable = resizable,
    debug = debug
  }, {
    eventMode = eventMode,
    initialize = initialize,
    useJsTitle = not title,
    luaScript = luaScript,
    luaPath = luaPath,
    captureError = captureError,
    context = {
      args = ctxArgs,
      luaSrcPath = luaSrcPath,
    },
  }
end

local function createContextAndPath(wv, opts)
  if opts.luaPath and opts.context and opts.context.luaSrcPath then
    package.path = package.path..';'..opts.context.luaSrcPath..'/?.lua'
  end
  return createContext(wv, opts)
end

local function launchWithOptions(url, wvOptions, options)
  wvOptions = wvOptions or {}
  options = options or wvOptions
  local _, uv = pcall(require, 'luv')
  if not _ then
    uv = nil
  end
  options.uv = uv

  local webview = webviewLib.new(url, wvOptions.title, wvOptions.width, wvOptions.height, wvOptions.resizable, wvOptions.debug)
  local callback = createContext(webview, options)
  webviewLib.callback(webview, callback)

  if not uv then
    webviewLib.loop(webview, "default")
  else
    repeat
    until dispatch(uv, webview)
  end
end

return {
  initializeJs = initializeJs,
  createContext = createContext,
  createContextAndPath = createContextAndPath,
  escapeUrl = escapeUrl,
  launchFromArgs = function(args, ...)
    if type(args) == 'string' then
      args = {args, ...}
    elseif type(args) ~= 'table' then
      args = arg
    end
    launchWithOptions(parseArgs(args))
  end,
  launchWithOptions = launchWithOptions,
  jsonLib = jsonLib,
  fsLib = fsLib,
}
