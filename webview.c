#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#define WEBVIEW_IMPLEMENTATION

// wget https://raw.githubusercontent.com/zserge/webview/master/webview.h
#include "webview.h"

/*
********************************************************************************
* Lua 5.1 compatibility
********************************************************************************
*/

#if LUA_VERSION_NUM < 502 && !defined(LUA_JITLIBNAME)
// From Lua 5.3 lauxlib.c
LUALIB_API void luaL_setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
  luaL_checkstack(L, nup, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -nup);
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_setfield(L, -(nup + 2), l->name);
  }
  lua_pop(L, nup);  /* remove upvalues */
}
LUALIB_API void *luaL_testudata (lua_State *L, int ud, const char *tname) {
  void *p = lua_touserdata(L, ud);
  if (p != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      luaL_getmetatable(L, tname);  /* get correct metatable */
      if (!lua_rawequal(L, -1, -2))  /* not the same? */
        p = NULL;  /* value is a userdata with wrong metatable */
      lua_pop(L, 2);  /* remove both metatables */
      return p;
    }
  }
  return NULL;  /* value is not a userdata with a metatable */
}
#endif

/*
********************************************************************************
* Lua reference structure and functions
********************************************************************************
*/

typedef struct LuaReferenceStruct {
	lua_State *state;
	int ref;
} LuaReference;

static void initLuaReference(LuaReference *r) {
	if (r != NULL) {
		r->state = NULL;
		r->ref = LUA_NOREF;
	}
}

static void registerLuaReference(LuaReference *r, lua_State *l) {
	if ((r != NULL) && (l != NULL)) {
		if ((r->state != NULL) && (r->ref != LUA_NOREF)) {
			luaL_unref(r->state, LUA_REGISTRYINDEX, r->ref);
		}
		r->state = l;
		r->ref = luaL_ref(l, LUA_REGISTRYINDEX);
	}
}

static void unregisterLuaReference(LuaReference *r, lua_State *l) {
	if ((r != NULL) && (r->state != NULL) && (r->state == l) && (r->ref != LUA_NOREF)) {
		luaL_unref(r->state, LUA_REGISTRYINDEX, r->ref);
		r->state = NULL;
		r->ref = LUA_NOREF;
	}
}

/*
********************************************************************************
* Lua webview structure
********************************************************************************
*/

typedef struct LuaWebViewStruct {
	LuaReference cbFn;
	lua_State *initState;
	struct webview webview;
} LuaWebView;

#define WEBVIEW_PTR(_cp) \
	((LuaWebView *) ((char *) (_cp) - offsetof(LuaWebView, webview)))

/*
********************************************************************************
* Lua webview functions
********************************************************************************
*/

static int lua_webview_open(lua_State *l) {
	const char *url = luaL_checkstring(l, 1);
	const char *title = luaL_optstring(l, 2, "Lua Web View");
	lua_Integer width = luaL_optinteger(l, 3, 800);
	lua_Integer height = luaL_optinteger(l, 4, 600);
	lua_Integer resizable = lua_toboolean(l, 5);
	webview_run(title, url, (int)width, (int)height, (int)resizable);
	return 0;
}

static LuaWebView *lua_webview_asudata(lua_State *l, int ud) {
	if (lua_islightuserdata(l, ud)) {
		return (LuaWebView *)lua_touserdata(l, ud);
	}
	return (LuaWebView *)luaL_checkudata(l, ud, "webview");
}

static LuaWebView * lua_webview_newuserdata(lua_State *l) {
	size_t urlLen;
	size_t titleLen;
	const char *url = luaL_optlstring(l, 1, "", &urlLen);
	const char *title = luaL_optlstring(l, 2, "Lua Web View", &titleLen);
	lua_Integer width = luaL_optinteger(l, 3, 800);
	lua_Integer height = luaL_optinteger(l, 4, 600);
	lua_Integer resizable = lua_toboolean(l, 5);
	lua_Integer debug = lua_toboolean(l, 6);
	LuaWebView *lwv = (LuaWebView *)lua_newuserdata(l, sizeof(LuaWebView) + titleLen + 1 + urlLen + 1);
	char *titleCopy = ((char *)lwv) + sizeof(LuaWebView);
	char *urlCopy = ((char *)lwv) + sizeof(LuaWebView) + titleLen + 1;
	memset(lwv, 0, sizeof(LuaWebView));
	memcpy(titleCopy, title, titleLen + 1);
	memcpy(urlCopy, url, urlLen + 1);
	lwv->initState = NULL;
	lwv->webview.title = titleCopy;
	lwv->webview.url = urlCopy;
	lwv->webview.width = width;
	lwv->webview.height = height;
	lwv->webview.resizable = resizable;
	lwv->webview.debug = debug;
	initLuaReference(&lwv->cbFn);
	return lwv;
}

static int lua_webview_new(lua_State *l) {
	LuaWebView *lwv = lua_webview_newuserdata(l);
	int r = webview_init(&lwv->webview);
	if (r != 0) {
		return 0;
	}
	lwv->initState = l;
	luaL_getmetatable(l, "webview");
	lua_setmetatable(l, -2);
	return 1;
}

static int lua_webview_allocate(lua_State *l) {
	(void) lua_webview_newuserdata(l);
	luaL_getmetatable(l, "webview");
	lua_setmetatable(l, -2);
	return 1;
}

static int lua_webview_init(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	int initialized = 0;
	if (lwv != NULL && lwv->initState == NULL) {
		int r = webview_init(&lwv->webview);
		if (r == 0) {
			initialized = 1;
			lwv->initState = l;
		}
	}
	lua_pushboolean(l, initialized);
	return 1;
}

static int lua_webview_initialized(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	lua_pushboolean(l, lwv != NULL && lwv->initState != NULL);
	return 1;
}

static const char *const lua_webview_loop_modes[] = {
  "default", "once", "nowait", NULL
};

static int lua_webview_loop(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	int mode = luaL_checkoption(l, 2, "default", lua_webview_loop_modes);
	int r = 0;
	int fired = 0;
	if (l == lwv->initState) {
		do {
			r = webview_loop_ex(&lwv->webview, mode != 2, &fired);
		} while ((mode == 0) && (r == 0));
	} else {
		webview_debug("loop and init states differs");
	}
	lua_pushboolean(l, r);
	lua_pushboolean(l, fired);
	return 2;
}

static void invoke_callback(struct webview *w, const char *arg) {
	if ((w != NULL) && (arg != NULL)) {
		LuaWebView *lwv = WEBVIEW_PTR(w);
		lua_State *l = lwv->cbFn.state;
		int ref = lwv->cbFn.ref;
		if ((l != NULL) && (ref != LUA_NOREF)) {
			if (l == lwv->initState) {
				lua_rawgeti(l, LUA_REGISTRYINDEX, ref);
				lua_pushstring(l, arg);
				lua_pcall(l, 1, 0, 0);
			} else {
				webview_debug("callback and init states differs");
			}
		}
	}
}

static int lua_webview_callback(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	if (lua_isfunction(l, 2)) {
		lua_pushvalue(l, 2);
		registerLuaReference(&lwv->cbFn, l);
		lwv->webview.external_invoke_cb = &invoke_callback;
	} else {
		unregisterLuaReference(&lwv->cbFn, l);
		lwv->webview.external_invoke_cb = NULL;
	}
	return 0;
}

static void dispatched_eval(struct webview *w, void *arg) {
	webview_eval(w, (const char *) arg);
}

static int lua_webview_eval(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	const char *js = luaL_checkstring(l, 2);
	int dispatch = lua_toboolean(l, 3);
	if (dispatch) {
		// do we need to register the js code to dispatch?
		webview_dispatch(&lwv->webview, dispatched_eval, (void *)js);
		return 0;
	}
	int r = webview_eval(&lwv->webview, js);
	lua_pushboolean(l, r);
	return 1;
}

static int lua_webview_title(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	const char *title = luaL_checkstring(l, 2);
	webview_set_title(&lwv->webview, title);
	return 0;
}

static int lua_webview_fullscreen(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	int fullscreen = lua_toboolean(l, 2);
	webview_set_fullscreen(&lwv->webview, fullscreen);
	return 0;
}

static void dispatched_terminate(struct webview *w, void *arg) {
	webview_terminate(w);
}

static int lua_webview_terminate(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	int dispatch = lua_toboolean(l, 2);
	if (dispatch) {
		webview_dispatch(&lwv->webview, dispatched_terminate, NULL);
		return 0;
	}
	webview_terminate(&lwv->webview);
	return 0;
}

static void clean_webview(lua_State *l, LuaWebView *lwv) {
	if (lwv != NULL) {
		unregisterLuaReference(&lwv->cbFn, l);
		if (lwv->initState == l) {
			//webview_debug("clean_webview()");
			webview_exit(&lwv->webview);
			lwv->initState = NULL;
		}
	}
}

static int lua_webview_clean(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	clean_webview(l, lwv);
	return 0;
}

static int lua_webview_lighten(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)luaL_checkudata(l, 1, "webview");
	lua_pushlightuserdata(l, lwv);
	return 1;
}

static int lua_webview_asstring(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)luaL_checkudata(l, 1, "webview");
	lua_pushlstring(l, (const char *) &lwv, sizeof(void *));
	return 1;
}

static int lua_webview_fromstring(lua_State *l) {
	size_t len = 0;
	const char *udata = luaL_optlstring(l, 1, NULL, &len);
	if (len == sizeof(void *)) {
		lua_pushlightuserdata(l, *((void **) udata));
		return 1;
	}
	return 0;
}

static int lua_webview_gc(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)luaL_testudata(l, 1, "webview");
	clean_webview(l, lwv);
	return 0;
}

static int lua_webview_tostring(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)luaL_testudata(l, 1, "webview");
	lua_pushfstring(l, "webview: %p", (void *)lwv);
	return 1;
}

static int is_non_symbol(char c) {
	if (c == '\0')
		return 1; // we want to write null regardless
	int c_int = (int)c;
	return (c_int >= 48 && c_int <= 57) || (c_int >= 65 && c_int <= 90) ||
		(c_int >= 97 && c_int <= 122);
}

static char *url_decode(const char *input, size_t input_length) {
	input_length = input_length > 0 ? input_length : strlen(input);
	size_t output_length = (input_length + 1) * sizeof(char);
	char *working = (char *)malloc(output_length), *output = working;

	while (*input) {
		if (*input == '%') {
			char buffer[3] = {input[1], input[2], 0};
			*working++ = (char)strtol(buffer, NULL, 16);
			input += 3;
		} else {
			*working++ = *input++;
		}
	}

	*working = 0;
	return output;
}

char *url_encode(const char *input, size_t input_length) {
	input_length = input_length > 0 ? input_length : strlen(input);
	size_t final_size = (input_length * 3) + 1;
	char *working = (char *)malloc(final_size * sizeof(char)), *output = working;

	while (*input) {
		const char c = *input;
		if (c < 0) {
			input++;
		} else if (is_non_symbol(c)) {
			*working++ = *input++;
		} else {
			char encoded[4] = {0};
			snprintf(encoded, 4, "%%%02x", c);

			*working++ = encoded[0];
			*working++ = encoded[1];
			*working++ = encoded[2];
			input++;
		}
	}

	*working = 0;
	return output;
}

static int lua_urlencode(lua_State *L) {
	size_t sz;
	const char *input = luaL_checklstring(L, 1, &sz);
	char *encoded = url_encode(input, sz);

	lua_pushstring(L, encoded);
	free(encoded);
	return 1;
}

static int lua_urldecode(lua_State *L) {
	size_t sz;
	const char *input = luaL_checklstring(L, 1, &sz);
	char *decoded = url_decode(input, sz);

	lua_pushstring(L, decoded);
	free(decoded);
	return 1;
}

typedef struct dispatch_arg {
	lua_State *l;
	int ref;
} dispatch_arg;

static void dispatched_cb(struct webview *w, void *arg) {
	dispatch_arg *dispatch = arg;
	lua_rawgeti(dispatch->l, LUA_REGISTRYINDEX, dispatch->ref);

	if (!lua_isfunction(dispatch->l, -1))
		lua_pop(dispatch->l, 0);
	else {
		if (lua_pcall(dispatch->l, 0, 0, 0)) {
			const char *err = lua_tostring(dispatch->l, -1);
			webview_debug("dispatch callback fail with %s", err);
			webview_print_log(err);
			lua_pop(dispatch->l, 1);
		}
	}
	luaL_unref(dispatch->l, LUA_REGISTRYINDEX, dispatch->ref);
	free(dispatch);
}

static int lua_webview_dispatch(lua_State *l) {
	LuaWebView *lwv = (LuaWebView *)lua_webview_asudata(l, 1);
	dispatch_arg *arg;
	luaL_checktype(l, 2, LUA_TFUNCTION);

	arg = malloc(sizeof(dispatch_arg));
	arg->l = l;
	lua_pushvalue(l, 2);
	arg->ref = luaL_ref(l, LUA_REGISTRYINDEX);

	webview_dispatch(&lwv->webview, dispatched_cb, (void *)arg);
	return 0;
}

#if defined(WEBVIEW2_MEMORY_MODULE)
static int lua_webview_loadWebView2Dll(lua_State *l) {
	void *data;
	size_t len = 0;
	int status = 0;
	data = lua_tolstring(l, 1, &len);
	if (data != NULL && len > 0 && WebView2Load(data, len)) {
		status = 1;
	}
	lua_pushboolean(l, status);
	return 1;
}
#endif

LUALIB_API int luaopen_webview(lua_State *l) {
	luaL_newmetatable(l, "webview");
	lua_pushliteral(l, "__gc");
	lua_pushcfunction(l, lua_webview_gc);
	lua_settable(l, -3);
	lua_pushliteral(l, "__tostring");
	lua_pushcfunction(l, lua_webview_tostring);
	lua_settable(l, -3);
	lua_pushliteral(l, "__name");
	lua_pushliteral(l, "webview");
	lua_settable(l, -3);

	luaL_Reg reg[] = {
		{ "open", lua_webview_open },
		{ "new", lua_webview_new },
		{ "allocate", lua_webview_allocate },
		{ "clean", lua_webview_clean },
		{ "init", lua_webview_init },
		{ "initialized", lua_webview_initialized },
		{ "loop", lua_webview_loop },
		{ "eval", lua_webview_eval },
		{ "callback", lua_webview_callback },
		{ "terminate", lua_webview_terminate },
		{ "fullscreen", lua_webview_fullscreen },
		{ "title", lua_webview_title },
		{ "lighten", lua_webview_lighten },
		{ "asstring", lua_webview_asstring },
		{ "fromstring", lua_webview_fromstring },
#if defined(WEBVIEW2_MEMORY_MODULE)
		{ "loadWebView2Dll", lua_webview_loadWebView2Dll },
#endif

		{ "urlencode", lua_urlencode },
		{ "urldecode", lua_urldecode },

		{ "dispatch", lua_webview_dispatch },

		{ NULL, NULL }
	};
	lua_newtable(l);
	luaL_setfuncs(l, reg, 0);
	lua_pushliteral(l, "Lua webview");
	lua_setfield(l, -2, "_NAME");
	lua_pushliteral(l, "1.0");
	lua_setfield(l, -2, "_VERSION");
	return 1;
}
