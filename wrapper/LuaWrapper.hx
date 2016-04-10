package wrapper;

import lua.Lua;
import lua.LuaL;
import lua.State;
import lua.Convert;
import wrapper.LDebug;

class LuaWrapper {
	public var vm:State;
	public var useErrorHander:Bool;


	public function new() {
		create();
		useErrorHander = false;
	}

	/**
	 * Close lua vm state
	 */
	public function close() {
		_close(vm);
	}

	/**
	 * Creates a new lua vm state
	 */
	public function create() {
		if(vm != null){
			_close(vm);
		}
		vm = _create();
	}

	/**
	 * Get the version string from Lua
	 */
	public static var version(get, never):String;
	private inline static function get_version():String {
		return Lua.version();
	}


	/**
	 * Get the version string from LuaJIT
	 */
	public static var versionJIT(get, never):String;
	private inline static function get_versionJIT():String {
		return Lua.versionJIT();
	}

	/**
	 * Loads lua libraries (base, debug, io, math, os, package, string, table)
	 * @param libs An array of library names to load
	 */
	public function loadLibs(?libs:Array<String>):Void {
    	LuaL.openlibs(vm);
    	Lua.init_callbacks(vm);
		Lua_helper.register_hxtrace(vm);
	}

	/**
	 * 
	 */
	public function require(name:String):Void {
		Lua.getglobal(vm, "require");
		Lua.pushstring(vm, name);
		Lua.call(vm, 1, 1);
	}

	/**
	 * Set new global variable
	 * @param vname variable name
	 * @param v     parameter
	 */
	public function set_var(vname:String, v:Dynamic):Void {
		Convert.toLua(vm, v);
        Lua.setglobal(vm, vname);
	}

	/**
	 * delete global variable, simply set this var to nil
	 * @param vname variable name
	 */
	public function delete_var(vname:String):Void {
		Lua.pushnil(vm);
        Lua.setglobal(vm, vname);
	}

	/**
	 * Set new variable to table
	 * @param tname global table name
	 * @param vname table variable name
	 * @param v     parameter
	 */
	public function set_var_to_table(tname:String, vname:String, v:Dynamic):Void {
		Lua.getglobal(vm, tname);
		if (Lua.istable(vm, -1) == 1) {
		    Lua.pushstring(vm, vname);
			Convert.toLua(vm, v);
		    Lua.settable(vm, -3);
		}
		Lua.pop(vm, 1);
	}

	/**
	 * Get global variable
	 * @param  vname global variable name
	 * @return       variable parameters
	 */
	public function get_var(vname:String):Dynamic {
		Lua.getglobal(vm, vname);
		var ret:Dynamic = Convert.fromLua(vm, -1);
		if(ret != null) Lua.pop(vm, 1);

		return ret;
	}

	/**
	 * Get variable from table
	 * @param  tname global table name
	 * @param  vname variable name
	 * @return       variable parameters
	 */
	public function get_var_from_table(tname:String, vname:String):Dynamic {
		Lua.getglobal(vm, tname);
		Lua.getfield(vm, -1, vname);
		var ret:Dynamic = Convert.fromLua(vm, -1);
		if(ret != null) Lua.pop(vm, 1);

		return ret;
	}

	/**
	 * add callback function 
	 * @param fname name
	 * @param f     function (5 arguments maximum)
	 */
	public function setFunction(fname:String, f:Dynamic):Void {
        Lua_helper.add_callback(vm, fname, f);
	}

	/**
	 * remove callback function 
	 * @param fname name
	 */
	public function removeFunction(fname:String):Void {
        Lua_helper.remove_callback(vm, fname);
	}

	/**
	 * Runs a lua script
	 * @param script The lua script to run in a string
	 * @param  retVal if true return script result
	 * @return The result from the lua script in Haxe
	 */
	public function execute(script:String, retVal:Bool = false):Dynamic {
		var ret:Dynamic = null;
        var oldtop:Int = Lua.gettop(vm);

		if(LuaL.dostring(vm, script) != Lua.LUA_OK){
			trace("LUA execute error: " + Lua.tostring(vm, -1));
		} else if(retVal){
			ret = multiReturn(oldtop);
		}
        Lua.settop(vm, oldtop);

		return ret;
	}
	
	/**
	 * Runs a lua file
	 * @param path The path of the lua file to run
	 * @param  retVal if true return file execution result
	 * @return The result from the lua script in Haxe
	 */
	public function doFile(path:String, retVal:Bool = false):Dynamic {
        var ret:Dynamic = null;
        var oldtop:Int = Lua.gettop(vm);
        
		if(LuaL.dofile(vm, path) != Lua.LUA_OK){ // (luaL_loadfile(L, filename) || lua_pcall(L, 0, Lua.LUA_MULTRET, 0))
			trace("LUA doFile error: " + Lua.tostring(vm, -1));
		} else if(retVal){
			ret = multiReturn(oldtop);
		}

        Lua.settop(vm, oldtop);
		return ret;
	}

	/**
	 * Calls a previously loaded lua function with no args
	 * @param  func   function name
	 * @param  retVal if true, return result
	 * @return        function result
	 */
	public function callFunction(func:String, retVal:Bool = false):Dynamic {

        var oldtop:Int = Lua.gettop(vm);
        var ret:Dynamic = null;

        if(useErrorHander) LDebug.setErrorHandler(vm);	

		Lua.getglobal(vm, func);
        if(Lua.pcall(vm, 0, Lua.LUA_MULTRET, -2) != Lua.LUA_OK){
			trace("LUA callFunction error: " + Lua.tostring(vm, -1));
        } else if(retVal){
			ret = multiReturn(oldtop);
        }

        Lua.settop(vm, oldtop);

        return ret;
	}

	/**
	 * Calls a previously loaded lua function
	 * @param func The lua function name (globals only)
	 * @param args A single argument or array of arguments
	 * @param  retVal if true return function result
	 */
	public function callFunction_ArrayArgs(func:String, ?args:Dynamic, retVal:Bool = false):Dynamic {

        var oldtop:Int = Lua.gettop(vm);
        var ret:Dynamic = null;

        if(useErrorHander) LDebug.setErrorHandler(vm);	

		Lua.getglobal(vm, func);

        if(args == null){
        	if(Lua.pcall(vm, 0, Lua.LUA_MULTRET, -2) != Lua.LUA_OK){
				trace("LUA callFunction_ArrayArgs error: " + Lua.tostring(vm, -1));
        	} else if(retVal){
				ret = multiReturn(oldtop);
	        }
        } else {
            if(Std.is(args, Array)){
                var nargs:Int = 0;
                var arr:Array<Dynamic>;
                arr = cast args;
                for (a in arr) {
                    if(Convert.toLua(vm, a)){
                        nargs++;
                    }
                }
                if(Lua.pcall(vm, nargs, Lua.LUA_MULTRET, -(nargs + 2)) != Lua.LUA_OK){
					trace("LUA callFunction_ArrayArgs error: " + Lua.tostring(vm, -1));
	        	} else if(retVal){
					ret = multiReturn(oldtop);
		        }
            } else {
                if(Convert.toLua(vm, args)){
                	if(Lua.pcall(vm, 1, Lua.LUA_MULTRET, -3) != Lua.LUA_OK){
						trace("LUA callFunction_ArrayArgs error: " + Lua.tostring(vm, -1));
		        	} else if(retVal){
						ret = multiReturn(oldtop);
			        }
                } else {
                    trace('LUA callFunction_ArrayArgs error: unknown type of argument !');
                }
            }
        }

        Lua.settop(vm, oldtop);

        return ret;
	}


	/**
	 * Calls a previously loaded lua function
	 * @param func The lua function name (globals only)
	 * @param arg1 A string argument
	 * @param  retVal if true return function result
	 */
	public function callFunction_String(func:String, arg1:String, retVal:Bool = false):Dynamic {

        var oldtop:Int = Lua.gettop(vm);
        var ret:Dynamic = null;

        if(useErrorHander) LDebug.setErrorHandler(vm);	

		Lua.getglobal(vm, func);

		Lua.pushstring(vm, arg1);
        if(Lua.pcall(vm, 1, Lua.LUA_MULTRET, -3) != Lua.LUA_OK){
			trace("LUA callFunction_String error: " + Lua.tostring(vm, -1));
		} else if(retVal){
			ret = multiReturn(oldtop);
		}

        Lua.settop(vm, oldtop);

        return ret;
	}

	/**
	 * Calls a previously loaded lua function
	 * @param func The lua function name (globals only)
	 * @param arg1 A string argument
	 * @param arg2 A string argument
	 * @param  retVal if true return function result
	 */
	public function callFunction_String_String(func:String, arg1:String, arg2:String, retVal:Bool = false):Dynamic {

        var oldtop:Int = Lua.gettop(vm);
        var ret:Dynamic = null;

        if(useErrorHander) LDebug.setErrorHandler(vm);	

		Lua.getglobal(vm, func);

		Lua.pushstring(vm, arg1);
		Lua.pushstring(vm, arg2);
        if(Lua.pcall(vm, 2, Lua.LUA_MULTRET, -4) != Lua.LUA_OK){
			trace("LUA callFunction_String_String error: " + Lua.tostring(vm, -1));
		} else if(retVal){
			ret = multiReturn(oldtop);
		}

        Lua.settop(vm, oldtop);

        return ret;
	}

	/**
	 * Calls a previously loaded lua function
	 * @param func The lua function name (globals only)
	 * @param arg1 A string argument
	 * @param arg2 A float argument
	 * @param  retVal if true return function result
	 */
	public function callFunction_String_Float(func:String, arg1:String, arg2:Float, retVal:Bool = false):Dynamic {

        var oldtop:Int = Lua.gettop(vm);
        var ret:Dynamic = null;

        if(useErrorHander) LDebug.setErrorHandler(vm);	

		Lua.getglobal(vm, func);

		Lua.pushstring(vm, arg1);
		Lua.pushnumber(vm, arg2);
        if(Lua.pcall(vm, 2, Lua.LUA_MULTRET, -4) != Lua.LUA_OK){
			trace("LUA callFunction_String_Float error: " + Lua.tostring(vm, -1));
		} else if(retVal){
			ret = multiReturn(oldtop);
		}

        Lua.settop(vm, oldtop);

        return ret;
	}


	/**
	 * Calls a previously loaded lua function from table
	 * @param  tname  table name
	 * @param  fname  function name
	 * @param  args   argsuments: array, value, or null
	 * @param  retVal if true return function result
	 * @return        function result
	 */
	public function callFunction_FromTable_ArrayArgs(tname:String, fname:String, ?args:Dynamic, retVal:Bool = false):Dynamic {

        var oldtop:Int = Lua.gettop(vm);
        var ret:Dynamic = null;

        if(useErrorHander) LDebug.setErrorHandler(vm);	
        
		Lua.getglobal(vm, tname);
		Lua.getfield(vm, -1, fname);
        if(args == null){
        	if(Lua.pcall(vm, 0, Lua.LUA_MULTRET, -3) != Lua.LUA_OK){
				trace("LUA callFunction_FromTable_ArrayArgs error: " + Lua.tostring(vm, -1));
        	} else if(retVal){
				ret = multiReturn(oldtop);
	        }

        } else {
            if(Std.is(args, Array)){
                var nargs:Int = 0;
                var arr:Array<Dynamic>;
                arr = cast args;
                for (a in arr) {
                    if(Convert.toLua(vm, a)){
                        nargs++;
                    }
                }
                if(Lua.pcall(vm, nargs, Lua.LUA_MULTRET, -(nargs + 3)) != Lua.LUA_OK){
					trace("LUA callFunction_FromTable_ArrayArgs error: " + Lua.tostring(vm, -1));
	        	} else if(retVal){
					ret = multiReturn(oldtop);
		        }
            } else {
                if(Convert.toLua(vm, args)){
                	if(Lua.pcall(vm, 1, Lua.LUA_MULTRET, -4) != Lua.LUA_OK){
						trace("LUA callFunction_FromTable_ArrayArgs error: " + Lua.tostring(vm, -1));
		        	} else if(retVal){
						ret = multiReturn(oldtop);
			        }
                } else {
                    trace('LUA callFunction_FromTable_ArrayArgs error: unknown type of arguments');
                }
            }
        }

        Lua.settop(vm, oldtop);

        return ret;
	}

	/**
	 * Convienient way to run a lua script in Haxe without loading any libraries
	 * @param script The lua script to run in a string
	 * @param vars An object defining the lua variables to create
	 * @return The result from the lua script in Haxe
	 */
	public static function run(script:String, ?vars:Dynamic):Dynamic {
		// var lua = new Lua();
		// lua.setVars(vars);
		// return lua.execute(script);
		return null;
	}

	/**
	 * Convienient way to run a lua file in Haxe without loading any libraries
	 * @param script The path of the lua file to run
	 * @param vars An object defining the lua variables to create
	 * @return The result from the lua script in Haxe
	 */
	public static function runFile(path:String, ?vars:Dynamic):Dynamic {
		// var lua = new Lua();
		// lua.setVars(vars);
		// return lua.executeFile(path);
		return null;
	}
	
	function _close(_lua:State) {
		Lua.close(_lua);
	}

	function multiReturn(oldtop:Int):Dynamic {

		if((Lua.gettop(vm) - oldtop) > 1){ // if oldtop is not 0
			var arr:Array<Dynamic> = [];
			var top:Int;
			var i:Int;
			while ((top = Lua.gettop(vm)) != Lua.LUA_OK){
				i = top - 1;
				arr[i] = Convert.fromLua(vm, top);
				Lua.pop(vm, 1);
			}
			return arr;
		} else {
			return Convert.fromLua(vm, -1);
		}

	}

	function _create() {
		var _vm:State = LuaL.newstate();
		return _vm;
	}

	/**
	 * helpers
	 */
	
    public function stackDump(msg:String = ""):Void{
        var top:Int = Lua.gettop(vm);

        trace('---------------- Stack Dump : "'  + msg +  '" ----------------');

        if(top > 0){
            trace("stacksize: " + top);
            var i:Int = -(top + 1);
            while(top > 0){
                var v:Dynamic = Convert.fromLua(vm, top);
                // trace( top + " | " + (i + top) + ") " + v );
                trace( (i + top) + ") " + v );
                top--;
            }
        }

        trace('---------------- Stack Dump : "'  + msg +  '" Finished ----------------');
    }

    public function printGlobalTable() {
    	var nvars:Int = 0;
    	Lua.getglobal(vm, "_G");
		Lua.pushnil(vm);
		while (Lua.next(vm,-2) != Lua.LUA_OK) { 
			var k:String = Std.string(Convert.fromLua(vm, -2));
			var v:Dynamic = lua_value_to_haxe_string(-1);
			trace(k + " : " + v);
			Lua.pop(vm,1);
			nvars++;
		}
		Lua.pop(vm,1);
		trace("GLOBAL VARS: " + nvars);
    }


    function lua_value_to_haxe_string(v:Int) {
        var ret:String = null;

        switch(Lua.type(vm, v)) {
            case Lua.LUA_TNIL:
                ret = "null";
            case Lua.LUA_TBOOLEAN:
                ret = "bool";
            case Lua.LUA_TNUMBER:
                var n:Float = Lua.tonumber(vm, v);
                ret = (n % 1) == 0 ? "int" : "float";
            case Lua.LUA_TSTRING:
                ret = "string";
            case Lua.LUA_TTABLE:
                ret = "table";
            case Lua.LUA_TFUNCTION:
                ret = "function";
                // trace("function\n");
            case Lua.LUA_TUSERDATA:
                ret = "userdata";
                // trace("userdata\n");
            case Lua.LUA_TTHREAD:
                ret = "thread";
                // trace("thread\n");
            case Lua.LUA_TLIGHTUSERDATA:
                ret = "lightuserdata";
                // trace("lightuserdata\n");
            default:
                ret = "return value not supported";
                // trace("return value not supported\n");
        }
        return ret;
    }
}

