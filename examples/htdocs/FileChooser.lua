local uv = require('luv')

local function listFiles(value, callback)
  if type(callback) ~= 'function' then
    return
  end

  local dir = uv.fs_realpath(value or '.')

  local req = uv.fs_scandir(dir)
  local function iter()
    return uv.fs_scandir_next(req)
  end
  local files = {}
  for name, ftype in iter do
    local file = {name = name}
    local stat = uv.fs_stat(dir..'/'..name)
    file.isDirectory = stat.type=='directory'
    file.length = stat.size
    file.lastModified = stat.mtime.sec

    files[#files+1] = file
  end

  uv.run()
  table.insert(files, 1, dir)
  callback(nil, files)
end

if expose ~= nil then
  -- loaded as html src
  expose('fileList', listFiles)
else
  -- loaded as module
  return {
    listFiles = listFiles
  }
end
