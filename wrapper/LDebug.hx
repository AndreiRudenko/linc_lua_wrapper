package wrapper;

import lua.Lua;
import lua.LuaL;
import lua.State;
import lua.Convert;

@:include('linc_lua.h')
extern class LDebug {

    @:native('linc::helpers::setErrorHandler')
    static function setErrorHandler(l:State) : Int;

    static inline function luaTrace(l:State) : Void {}
    
}

