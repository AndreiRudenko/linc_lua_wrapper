# linc/lua wrapper
Haxe/hxcpp wrapper for [linc_luajit](https://github.com/RudenkoArts/linc_luajit). 

---

This library works with the Haxe cpp target only.

---

### Example usage

See test/Test.hx

Be sure to read the Lua documentation  
www.lua.org/manual/5.1/manual.html  

```haxe
import wrapper.LuaWrapper;

class Test {

    static function main() {
        
        var lua:LuaWrapper = new LuaWrapper(); 
        lua.loadLibs(); // load all libs
        
        lua.doFile("script.lua"); // load and execute file

        lua.callFunction_ArrayArgs('foo', [1, 2.0, "three"]); // call global function from loaded script

        lua.set_var("myFloatVar", 1.618 ); // set new global variable
        trace(lua.get_var("myFloatVar")); // get global variable
        lua.delete_var("myFloatVar"); // delete global variable

        lua.execute("return 146", true); // if true return script result

        lua.execute("function test(a, b) return a + b end");
        trace(lua.callFunction_ArrayArgs('test', [236.067, 381.966], true)); // if true return function result

        // callbacks
        lua.setFunction(
            "callBack", 
            function (a:String) { 
                trace(a);
                return 123;
            }
        );

        trace(lua.callFunction_ArrayArgs('callBack', "haxe callback !!!", true)); // execute haxe function from lua

        lua.close();

    }

}

```