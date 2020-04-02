local webviewLib = require('webview')

local url = [[data:text/html,<!DOCTYPE html>
<html>
  <body>
    <p id="sentence">It works !</p>
    loaded:<button id='inited' onclick='window.loaded=false;'>
    <button onclick='evalit()'>eval</button>
    <button onclick='dispatchit()'>disptach</button>
    <button onclick="callx();">call</button>
    <button onclick="stitle(1,2,3)">Change Title</button>
    <button onclick="print_date()">Print Date</button>
    <button onclick="show_date()">Show Date</button>
    <br/>
    <button title="Reload" onclick="window.location.reload()">&#x21bb;</button>
    <button title="Terminate" onclick="terminate()">&#x2716;</button>
    <br/>
  </body>
  <script type="text/javascript">
  document.getElementById('inited').innerHTML = window.loaded;
  function callx()
  {
    var promise = call(2*2);
    promise.then((results) => {
      document.getElementById('inited').innerHTML = results;
    });
  }
  </script>
</html>
]]
local dbg=true
local webview = webviewLib.create(dbg):title('Example'):size(320, 200)
                  :navigate(url)
webview:init("window.loaded=true");

webview:bind('print_date', function(seq, req, cbarg)
  webview:dispatch(function(msg)
    webviewLib.eval(webview, 'console.log("' .. msg .. '")');
    print(os.date())
  end, 'Hello Webview')
end, {})

webview:bind('evalit', function()
  webview:eval("document.getElementById('inited').innerHTML = window.loaded;")
end)

webview:bind('dispatchit', function()
  webview:dispatch(function(win)
    webview:eval("document.getElementById('inited').innerHTML =".. win ..";");
  end,"window");
end)

webview:bind('show_date', function(seq, req, cbarg)
  webviewLib.eval(webview,
      'document.getElementById("sentence").innerHTML =  "Lua date is '
      ..  os.date() .. '"', true)
end)

webview:bind('terminate', function(seq, req, cbarg)
  webviewLib.terminate(webview, true)
end)

webview:bind('stitle', function(seq, req, cbarg)
  webviewLib.title(webview, req)
end)

webview:bind('call', function(seq, req)
  print(req)
  webview:returns(seq, 0, req)
end)

webview:run()
