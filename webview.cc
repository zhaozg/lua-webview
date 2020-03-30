// wget https://raw.githubusercontent.com/zserge/webview/master/webview.h
#define WEBVIEW_IMPLEMENTATION
#include "webview.h"

#include <lua.hpp>
#include <lauxlib.h>

typedef struct Webview_Arg
{
  lua_State *L;
  int cbref;
  int argref;
} Webview_Arg_t;

#define WEBVIEW_NAME  "Webview"

static inline webview_t lua_webview_check(lua_State *L, int ud)
{
  return *(webview_t*)luaL_checkudata(L, ud, WEBVIEW_NAME);
}

// implication

static int lua_webview_open(lua_State *L)
{
  const char *url= luaL_checkstring(L, 1);
  const char *title = luaL_optlstring(L, 2, WEBVIEW_NAME, NULL);
  int width = luaL_optint(L, 3, 800);
  int height = luaL_optint(L, 4, 600);
  const char* shits[] = { "none", "min", "max", "fixed" };
  int hints = luaL_checkoption(L, 5, "none", shits);
  webview_t w = webview_create(false, nullptr);

  *(webview_t*)lua_newuserdata(L, sizeof(webview_t)) = w;
  lua_pushlightuserdata(L, w);
  lua_newtable(L);
  lua_rawset(L, LUA_REGISTRYINDEX);

  webview_set_title(w, title);
  webview_navigate(w, url);
  webview_set_size(w, width, height, hints);

  luaL_getmetatable(L, WEBVIEW_NAME);
  lua_setmetatable(L, -2);
  return 1;
}

static int lua_webview_create(lua_State *L)
{
  webview_t w = webview_create(false, nullptr);
  *(webview_t*)lua_newuserdata(L, sizeof(webview_t)) = w;
  lua_pushlightuserdata(L, w);
  lua_newtable(L);
  lua_rawset(L, LUA_REGISTRYINDEX);

  luaL_getmetatable(L, WEBVIEW_NAME);
  lua_setmetatable(L, -2);
  return 1;
}

static int lua_webview_destroy(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  if (w != NULL)
  {
    lua_pushlightuserdata(L, w);
    lua_rawget(L, LUA_REGISTRYINDEX);

    lua_pushnil(L);
    while (lua_next(L, -2) != 0)
    {
      /* uses 'key' (at index -2) and 'value' (at index -1) */
      Webview_Arg_t *arg = (Webview_Arg_t*)lua_touserdata(L, -1);
      luaL_unref(L, LUA_REGISTRYINDEX, arg->cbref);
      luaL_unref(L, LUA_REGISTRYINDEX, arg->argref);

      /* removes 'value'; keeps 'key' for next iteration */
      lua_pop(L, 1);
    }

    lua_pop(L, 1);

    lua_pushlightuserdata(L, w);
    lua_pushnil(L);
    lua_rawset(L, LUA_REGISTRYINDEX);

    webview_destroy(w);
    *(webview_t*)lua_touserdata(L, 1) = NULL;
  }
  return 0;
}

static int lua_webview_run(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  webview_run(w);
  lua_pushvalue(L, 1);
  return 1;
}

static inline void lua_webview_terminal_cb(webview_t w, void *arg)
{
  webview_terminate(w);
}

static int lua_webview_terminate(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  int dispatch = lua_toboolean(L, 2);
  if (dispatch)
  {
    webview_dispatch(w, lua_webview_terminal_cb, NULL);
    return 0;
  }
  webview_terminate(w);
  return 0;
}

static inline void lua_webview_dispatch_cb(webview_t w, void *arg)
{
  Webview_Arg_t *warg = (Webview_Arg_t*)arg;
  lua_State *L = warg->L;
  int ret;

  lua_rawgeti(L, LUA_REGISTRYINDEX, warg->cbref);
  lua_rawgeti(L, LUA_REGISTRYINDEX, warg->argref);
  ret = lua_pcall(L, 1, 0, 0);
  if (ret != LUA_OK)
  {
    fprintf(stderr, "dispatch callback error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
  luaL_unref(L, LUA_REGISTRYINDEX, warg->cbref);
  luaL_unref(L, LUA_REGISTRYINDEX, warg->argref);
  free(arg);
}

static int lua_webview_dispatch(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  Webview_Arg_t *arg;
  int idx;

  luaL_checktype(L, 2, LUA_TFUNCTION);

  arg = (Webview_Arg_t*)malloc(sizeof(*arg));
  arg->L = L;
  lua_pushvalue(L, 2);
  arg->cbref = luaL_ref(L, LUA_REGISTRYINDEX);
  if (lua_isnone(L, 3))
    arg->argref = LUA_NOREF;
  else
  {
    lua_pushvalue(L, 3);
    arg->argref = luaL_ref(L, LUA_REGISTRYINDEX);
  }

  webview_dispatch(w, lua_webview_dispatch_cb, arg);

  lua_pushvalue(L, 1);
  return 1;
}

static int lua_webview_title(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  const char *title = luaL_checkstring(L, 2);
  webview_set_title(w, title);

  lua_pushvalue(L, 1);
  return 1;
}

static int lua_webview_size(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  int width = luaL_checkint(L, 2);
  int height = luaL_checkint(L, 3);
  const char* shits[] = { "none", "min", "max", "fixed" };
  int hints = luaL_checkoption(L, 4, "none", shits);

  // Updates native window size. See WEBVIEW_HINT constants.
  webview_set_size(w, width, height, hints);

  lua_pushvalue(L, 1);
  return 1;
}

static int lua_webview_navigate(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  const char *url= luaL_checkstring(L, 2);
  webview_navigate(w, url);

  lua_pushvalue(L, 1);
  return 1;
}

// javascript releative
static int lua_webview_init(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  const char *js = luaL_checkstring(L, 2);
  webview_init(w, js);

  lua_pushvalue(L, 1);
  return 1;
}

static int lua_webview_eval(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  const char *js = luaL_checkstring(L, 2);
  webview_eval(w, js);

  lua_pushvalue(L, 1);
  return 1;
}

static inline void lua_webview_bind_cb(const char *seq, const char *req,
                                       void *arg)
{
  Webview_Arg_t *warg = (Webview_Arg_t*) arg;
  lua_State *L = warg->L;
  int ret;

  lua_rawgeti(L, LUA_REGISTRYINDEX, warg->cbref);
  lua_pushstring(L, seq);
  lua_pushstring(L, req);
  lua_rawgeti(L, LUA_REGISTRYINDEX, warg->argref);
  ret = lua_pcall(L, 3, 0, 0);
  if (ret!=LUA_OK)
  {
    fprintf(stderr, "bind callback error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 3);
  }
}

static int lua_webview_bind(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  const char *name = luaL_checkstring(L, 2);
  Webview_Arg_t *arg;

  luaL_checktype(L, 3, LUA_TFUNCTION);

  lua_pushlightuserdata(L, w);
  lua_rawget(L, LUA_REGISTRYINDEX);
  lua_pushvalue(L, 2);
  arg = (Webview_Arg_t*)lua_newuserdata(L, sizeof(*arg));
  lua_rawset(L, -3);
  lua_pop(L, 1);

  arg->L = L;
  lua_pushvalue(L, 3);
  arg->cbref = luaL_ref(L, LUA_REGISTRYINDEX);
  if (lua_isnone(L, 4))
    arg->argref = LUA_NOREF;
  else
  {
    lua_pushvalue(L, 4);
    arg->argref = luaL_ref(L, LUA_REGISTRYINDEX);
  }

  webview_bind(w, name, lua_webview_bind_cb, arg);

  lua_pushvalue(L, 1);
  return 1;
}

static int lua_webview_return(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  const char *seq = luaL_checkstring(L, 2);
  int status = luaL_optinteger(L, 3, 0);
  const char *result = luaL_optstring(L, 4, NULL);
  webview_return(w, seq, status, result);

  lua_pushvalue(L, 1);
  return 1;
}

static int lua_webview_tostring(lua_State *L)
{
  webview_t w = lua_webview_check(L, 1);
  lua_pushfstring(L, "%s: 0x%p", WEBVIEW_NAME, w);
  return 1;
}

static  luaL_Reg webview_mt[] =
{
  { "destroy", lua_webview_destroy },

  { "run", lua_webview_run },
  { "terminate", lua_webview_terminate },
  { "dispatch", lua_webview_dispatch },

  { "title", lua_webview_title },
  { "size", lua_webview_size },

  { "navigate", lua_webview_navigate },

  { "init", lua_webview_init },
  { "eval", lua_webview_eval },
  { "bind", lua_webview_bind },
  { "return", lua_webview_return },

  { "__tostring", lua_webview_tostring },
  { "__gc", lua_webview_destroy },

  { NULL, NULL }
};

static  luaL_Reg webview_lib[] =
{
  { "open", lua_webview_open },
  { "create", lua_webview_create },
  { "destroy", lua_webview_destroy },

  { "run", lua_webview_run },
  { "terminate", lua_webview_terminate },
  { "dispatch", lua_webview_dispatch },

  { "title", lua_webview_title },
  { "size", lua_webview_size },

  { "navigate", lua_webview_navigate },

  { "init", lua_webview_init },
  { "eval", lua_webview_eval },
  { "bind", lua_webview_bind },
  { "return", lua_webview_return },

  { NULL, NULL }
};

static void luaL_newclass(lua_State *L, const char *classname, luaL_Reg *func)
{
  luaL_newmetatable(L, classname); /* mt */
  /* create __index table to place methods */
  lua_pushstring(L, "__index");    /* mt,"__index" */
  lua_newtable(L);                 /* mt,"__index",it */
  /* put class name into class metatable */
  lua_pushstring(L, "class");      /* mt,"__index",it,"class" */
  lua_pushstring(L, classname);    /* mt,"__index",it,"class",classname */
  lua_rawset(L, -3);               /* mt,"__index",it */
  /* pass all methods that start with _ to the metatable, and all others
   * to the index table */
  for (; func->name; func++)       /* mt,"__index",it */
  {
    lua_pushstring(L, func->name);
    lua_pushcfunction(L, func->func);
    lua_rawset(L, func->name[0] == '_' ? -5: -3);
  }
  lua_rawset(L, -3);               /* mt */
  lua_pop(L, 1);
}

#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM == 501
void luaL_setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
  luaL_checkstack(L, nup+1, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    lua_pushstring(L, l->name);
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -(nup + 1));
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_settable(L, -(nup + 3));
    /* table must be below the upvalues, the name and the closure */
  }
  lua_pop(L, nup);  /* remove upvalues */
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
LUALIB_API int luaopen_webview(lua_State *L)
{
  luaL_newclass(L, WEBVIEW_NAME, webview_mt);

  lua_newtable(L);
  luaL_setfuncs(L, webview_lib, 0);
  lua_pushliteral(L, WEBVIEW_NAME);
  lua_setfield(L, -2, "_NAME");
  lua_pushliteral(L, "0.0.1");
  lua_setfield(L, -2, "_VERSION");

  return 1;
}
#ifdef __cplusplus
}
#endif
