package echo;
#if macro
import echo.macro.MacroBuilder;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;
using haxe.macro.Context;
using echo.macro.Macro;
using Lambda;
#end

/**
 * ...
 * @author octocake1
 */
class Echo {
	
	
	@:noCompletion static public var __SEQUENCE = 0;
	
	
	public var entities(default, null):List<Int>;
	public var views(default, null):Array<View.ViewBase>;
	public var systems(default, null):Array<System>;
	
	
	public function new() {
		entities = new List();
		views = [];
		systems = [];
	}
	
	
	#if debug
		var updateStats:Map<System, Float> = new Map();
	#end
	inline public function stats():String {
		var ret = 'Echo' + ' [${entities.length}]' + '\n'; // TODO add version or something
		#if debug
			for (s in systems) {
				ret += '\t' + Type.getClassName(Type.getClass(s)) + ' : ' + updateStats.get(s) + ' ms\n';
			}
		#end
		return ret;
	}
	
	
	public function update(dt:Float) {
		for (s in systems) {
			#if debug
				var stamp = haxe.Timer.stamp();
			#end
			s.update(dt);
			#if debug
				updateStats.set(s, Std.int((haxe.Timer.stamp() - stamp) * 1000));
			#end
		}
	}
	
	
	// System
	
	public function addSystem(s:System) {
		s.activate(this);
		systems.push(s);
	}
	
	public function removeSystem(s:System) {
		s.deactivate();
		systems.remove(s);
	}
	
	
	// View
	
	public function addView(v:View.ViewBase) {
		v.activate(this);
		views.push(v);
	}
	
	public function removeView(v:View.ViewBase) {
		v.deactivate();
		views.remove(v);
	}
	
	
	// Entity
	
	public function id() {
		var e = ++__SEQUENCE;
		entities.add(e);
		return e;
	}
	
	macro public function remove(self:Expr, id:ExprOf<Int>) {
		var esafe = macro var _id_ = $id;
		var exprs = [ 
			for (n in echo.macro.MacroBuilder.componentHoldersMap) {
				var n = Context.parse(n, Context.currentPos());
				macro $n.__MAP.remove(_id_);
			}
		];
		
		Macro.traceExprs('remove', exprs);
		
		return macro {
			$esafe;
			for (_v_ in $self.views) _v_.removeIfMatch(_id_);
			$b{exprs};
			$self.entities.remove(_id_);
		}
	}
	
	
	// Component
	
	macro inline public function setComponent(self:Expr, id:ExprOf<Int>, components:Array<Expr>) {
		var esafe = macro var _id_ = $id; // TODO opt ( if EConst - safe is unnesessary )
		var exprs = [
			for (c in components) {
				var h = echo.macro.MacroBuilder.getComponentHolder(c.typeof().follow().toComplexType().fullname());
				//if (h == null) continue; // TODO define ?
				var n = Context.parse(h, Context.currentPos());
				macro $n.__MAP.set(_id_, $c);
			}
		];
		
		Macro.traceExprs('setComponent', exprs);
		
		return macro {
			$esafe;
			$b{exprs};
			for (_v_ in $self.views) _v_.addIfMatch(_id_);
		}
	}
	
	macro inline public function removeComponent<T:Class<Dynamic>>(self:Expr, id:ExprOf<Int>, type:ExprOf<T>) {
		var esafe = macro var _id_ = $id;
		var h = echo.macro.MacroBuilder.getComponentHolder(type.identName().getType().follow().toComplexType().fullname());
		//if (h == null) return macro null;
		var n = Context.parse(h, Context.currentPos());
		return macro {
			$esafe;
			if ($n.__MAP.exists(_id_)) {
				for (_v_ in $self.views) if (_v_.testcomponent($n.__ID)) _v_.removeIfMatch(_id_);
				$n.__MAP.remove(_id_);
			}
		}
	}
	
	macro inline public function getComponent<T:Class<Dynamic>>(self:Expr, id:ExprOf<Int>, type:ExprOf<T>):ExprOf<T> {
		var h = echo.macro.MacroBuilder.getComponentHolder(type.identName().getType().follow().toComplexType().fullname());
		//if (h == null) return macro null;
		var n = Context.parse(h, Context.currentPos());
		return macro $n.__MAP.get($id);
	}
	
}