local webviewLib = require('webview')

local url = [[data:text/html,<!DOCTYPE html>
<html>
  <body>
    <p id="sentence">It works !</p>
    <button onclick="stitle(1,2,3)">Change Title</button>
    <button onclick="print_date()">Print Date</button>
    <button onclick="show_date()">Show Date</button>
    <br/>
    <button title="Reload" onclick="window.location.reload()">&#x21bb;</button>
    <button title="Terminate" onclick="terminate()">&#x2716;</button>
    <br/>
  </body>
  <script type="text/javascript">
  var fullscreen = false;
  </script>
</html>
]]

local webview = webviewLib.create():title('Example'):size(320, 200)
                  :navigate(url)

webview:bind('print_date', function(seq, req, cbarg)
  webview:dispatch(function(msg)
    webviewLib.eval(webview, 'alert("' .. msg .. '")');
    print(os.date())
  end, 'Hello Webview')
end, {})

webview:bind('show_date', function(seq, req, cbarg)
  webviewLib.eval(webview,
                  'document.getElementById("sentence").innerHTML =  "Lua date is ' ..
                    os.date() .. '"', true)
end)

webview:bind('terminate', function(seq, req, cbarg)
  webviewLib.terminate(webview, true)
end)

webview:bind('stitle',
             function(seq, req, cbarg) webviewLib.title(webview, req) 
end)


webview:run()
