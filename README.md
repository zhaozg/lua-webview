## Overview

The Lua webview module provides functions to open a web page in a dedicated window from Lua.
This repo is a fork of [lua-webview](https://github.com/javalikescript/lua-webview), with heavy update.

```lua
require('webview').open('http://www.lua.org/'):run()
```

This module is a binding of the tiny cross-platform [webview](https://github.com/zserge/webview) library.

Lua webview is covered by the MIT license.

## Examples

Using the file system
```lua
luajit examples/open.lua https://github.com
```

Pure Lua

```lua
luajit examples/simple.lua
```
