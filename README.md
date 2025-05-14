# Overview

The Lua module is a [webview](https://github.com/webview/webview/) binding.
That is a tiny cross-platform webview library for C/C++ to build modern cross-platform GUIs.

Lua webview is covered by the MIT license.

## Examples

```lua
require('webview').open('http://www.lua.org/'):run()
```

Using the file system
```lua
luajit examples/open.lua https://github.com
```

Pure Lua

```lua
luajit examples/simple.lua
```
