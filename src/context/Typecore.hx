package context;

import haxe.ds.Option;
import ocaml.Ref;
using ocaml.Cloner;

using haxe.EnumTools.EnumValueTools;
// import haxe.EnumTools.EnumValueTools;

// using equals.Equal;

class Forbid_package {
	public var a:{pack:String,m:core.Path, p:core.Globals.Pos};
	public var pl:Array<core.Globals.Pos>;
	public var pf:String;
	public function new (a:{pack:String,m:core.Path, p:core.Globals.Pos}, pl:Array<core.Globals.Pos>, pf:String) {
		this.a = a;
		this.pl = pl;
		this.pf = pf;
	}
}
class WithTypeError {
	public var m:core.Error.ErrorMsg;
	public var pos:core.Globals.Pos;
	public function new (m:core.Error.ErrorMsg, pos:core.Globals.Pos) {
		this.m = m;
		this.pos = pos;
	}
}

enum WithType {
	NoValue;
	Value;
	WithType (v:core.Type.T);
}

typedef TypePatch = {
	tp_type : Option<core.Ast.ComplexType>,
	tp_remove : Bool,
	tp_meta : core.Ast.Metadata
}

enum CurrentFun {
	FunMember;
	FunStatic;
	FunConstructor;
	FunMemberAbstract;
	FunMemberClassLocal;
	FunMemberAbstractLocal;
}

enum MacroMode {
	MExpr;
	MBuild;
	MMacroType;
	MDisplay;
}

enum TyperPass {
	PBuildModule; // build the module structure and setup module type parameters
	PBuildClass; // build the class structure
	PTypeField; // type the class field, allow access to types structures
	PCheckConstraint; // perform late constraint checks with inferred types
	PForce; // usually ensure that lazy have been evaluated
	PFinal; // not used, only mark for finalize
}

typedef TyperModule = {
	curmod : core.Type.ModuleDef,
	module_types : Array<{mt:core.Type.ModuleType, pos:core.Globals.Pos}>,
	module_using : Array<{tc:core.Type.TClass, pos:core.Globals.Pos}>,
	module_globals : Map<String, {a:core.Type.ModuleType, b:String, pos:core.Globals.Pos}>,
	wildcard_packages : Array<{l:Array<String>, pos:core.Globals.Pos}>,
	module_imports : Array<core.Ast.Import>
}

@:structInit
class TyperGlobals {
	public var types_module : Map<core.Path, core.Path>;
	public var modules : Map<core.Path, core.Type.ModuleDef>;
	public var delayed : Array<{fst:TyperPass, snd:Array<Void->Void>}>;
	public var debug_delayed : Array<{fst:TyperPass, snd:Array<{f:Void->Void, s:String, t:context.Typecore.Typer}>}>;
	public var doinline : Bool;
	public var core_api : Option<Typer>;
	public var macros : Option<{f:Void->Void, t:Typer}>;
	public var std : core.Type.ModuleDef;
	public var hook_generate : Array<Void->Void>;
	public var type_patches : Map<core.Path, {map:Map<{s:String, b:Bool}, context.Typecore.TypePatch>, tp:context.Typecore.TypePatch}>;
	public var global_metadata : Array<{l:Array<String>, me:core.Ast.MetadataEntry, bs:{a:Bool, b:Bool, c:Bool}}>;
	public var module_check_policies : Array<{l:Array<String>, mcps:Array<core.Type.ModuleCheckPolicy>, b:Bool}>;
	public var get_build_infos : Void->Option<{mt:core.Type.ModuleType, l:Array<core.Type.T>, cfs: Array<core.Ast.ClassField>}>;
	public var delayed_macros : Array<Void->Void>;
	public var global_using : Array<{a:core.Type.TClass, pos:core.Globals.Pos}>;
	// api
	public var do_inherit : Typer->core.Type.TClass->core.Globals.Pos->{is_extends:Bool, tp:core.Ast.PlacedTypePath}->Bool;
	public var do_create : context.Common.Context->Typer;
	public var do_macro : Typer->MacroMode->core.Path->String->Array<core.Ast.Expr>->core.Globals.Pos->Option<core.Ast.Expr>;
	public var do_load_module : Typer->core.Path->core.Globals.Pos->core.Type.ModuleDef;
	public var do_optimize : Typer->core.Type.TExpr->core.Type.TExpr;
	// do_build_instance : Typer->core.Type.ModuleType->core.Globals.Pos->{types:Array<{s:String, t:core.Type.T}>, path:core.Path, f:Array<core.Type.T>->core.Type.T};
	public var do_build_instance : Typer->core.Type.ModuleType->core.Globals.Pos->{types:core.Type.TypeParams, path:core.Path, f:Array<core.Type.T>->core.Type.T};
	public var do_format_string : Typer->String->core.Globals.Pos->core.Ast.Expr;
	public var do_finalize : Typer->Void;
	public var do_generate : Typer->{main:Option<core.Type.TExpr>, types:Array<core.Type.ModuleType>, modules:Array<core.Type.ModuleDef>};
}


typedef Typer = {
	// shared
	com : context.Common.Context,
	t : core.Type.BasicTypes,
	g : TyperGlobals,
	meta : core.Ast.Metadata,
	this_stack : Array<core.Type.TExpr>,
	with_type_stack : Array<WithType>,
	call_argument_stack : Array<Array<core.Ast.Expr>>,
	// variable
	pass : TyperPass,
	// per-module
	m : TyperModule,
	is_display_file : Bool,
	// per-class
	curclass : core.Type.TClass,
	tthis : core.Type.T,
	type_params : core.Type.TypeParams,
	// per-function
	curfield : core.Type.TClassField,
	untyped_ : Bool,
	in_loop : Bool,
	in_display : Bool,
	in_macro : Bool,
	macro_depth : Int,
	curfun : CurrentFun,
	ret : core.Type.T,
	locals : Map<String, core.Type.TVar>,
	opened : Array<Ref<core.Type.AnonStatus>>,
	vthis : Option<core.Type.TVar>,
	in_call_args : Bool,
	// events
	on_error : Typer->String->core.Globals.Pos->Void
}

class Typecore {
	public static var type_expr_ref = new Ref<Typer -> core.Ast.Expr -> WithType -> core.Type.TExpr>(function (_,_,_) { throw false; });
	public static var cast_or_unify_ref = new Ref<Typer-> core.Type.T -> core.Type.TExpr -> core.Globals.Pos -> core.Type.TExpr>(function (_, _, _, _) { throw false; });
	public static var analyser_run_on_expr_ref = new Ref<context.Common.Context-> core.Type.TExpr -> core.Type.TExpr>(function (_, _) { throw false; });

	public static function display_error (ctx:Typer, msg:String, p:core.Globals.Pos) : Void {
		switch (ctx.com.display.dms_error_policy) {
			case EPShow, EPIgnore: ctx.on_error(ctx, msg, p);
			case EPCollect: context.Common.add_diagnostics_message(ctx.com, msg, p, Error);
		}
	}

	public static function type_expr (ctx:Typer, e:core.Ast.Expr, with_type:WithType) : core.Type.TExpr {
		return type_expr_ref.get()(ctx, e, with_type);
	}

	public static function raise_or_display (ctx:Typer, l:Array<core.Type.UnifyError>, p:core.Globals.Pos) {
		if (ctx.untyped_) {}
		else if (ctx.in_call_args) {
			throw new WithTypeError(Unify(l), p);
		}
		else {
			display_error(ctx, core.Error.error_msg(Unify(l)), p);
		}
	}
	
	public static function raise_or_display_message (ctx:Typer, msg:String, p:core.Globals.Pos) : Dynamic {
		if (ctx.in_call_args) {
			throw new WithTypeError(Custom(msg), p);
		}
		else {
			display_error(ctx, msg, p);
		}
		return null;
	}
	

	public static function unify (ctx:Typer, t1:core.Type.T, t2:core.Type.T, p:core.Globals.Pos) : Dynamic {
		try {
			core.Type.unify(t1, t2);
		}
		catch(err:core.Type.Unify_error) {
			raise_or_display(ctx, err.l, p);
		}
		return null;
	}

	public static function unify_raise (ctx:Typer, t1:core.Type.T, t2:core.Type.T, p:core.Globals.Pos) : Dynamic {
		try {
			core.Type.unify(t1, t2);
		}
		catch(err:core.Type.Unify_error) {
			// no untyped check
			throw new core.Error(Unify(err.l),p);
		}
		return null;
	}

	public static function save_locals (ctx:Typer) : Void->Void {
		var locals = ctx.locals.clone();
		return function() { ctx.locals = locals; }
	}

	public static function add_local (ctx:Typer, n:String, t:core.Type.T, p:core.Globals.Pos) {
		var v = core.Type.alloc_var(n, t, p);
		if (core.Define.defined(ctx.com.defines, WarnVarShadowing)) {
			try {
				var v_ = ocaml.PMap.find(n, ctx.locals);
				ctx.com.warning("This variable shadows a previously declared variable", p);
				ctx.com.warning("Previous variable was here", v_.v_pos);
			}
			catch (_:ocaml.Not_found) {}
		}
		ctx.locals.set(n, v);
		return v;
	}

	public static function delay (ctx:context.Typecore.Typer, p:context.Typecore.TyperPass, f:Void->Void) : Void {
		function loop (s:Array<{fst:TyperPass, snd:Array<Void->Void>}>) {
			if (s.length == 0) {
				return [{fst:p, snd:[f]}];
			}
			var rest = s.slice(1);
			var p2 = s[0].fst;
			var l = s[0].snd.copy();
			if (p2.equals(p)) {
				l.unshift(f);
				rest.unshift({fst:p, snd:l});
			}
			// else if (p2.getIndex() < p.getIndex()) {
			else if (typerPassToInt(p2) < typerPassToInt(p)) {
				rest = loop(rest);
				rest.unshift({fst:p2, snd:l});
			}
			else {
				rest.unshift({fst:p2, snd:l});
				rest.unshift({fst:p, snd:[f]});
			}
			return rest;
		}
		ctx.g.delayed = loop(ctx.g.delayed);
	}

	public static function delay_late (ctx:context.Typecore.Typer, p:context.Typecore.TyperPass, f:Void->Void) : Void {
		function loop (s:Array<{fst:TyperPass, snd:Array<Void->Void>}>) {
			if (s.length == 0) {
				return [{fst:p, snd:[f]}];
			}
			var rest = s.slice(1);
			var p2 = s[0].fst;
			var l = s[0].snd.copy();
			// if (p2.getIndex() <= p.getIndex()) {
			if (typerPassToInt(p2) < typerPassToInt(p)) {
				rest = loop(rest);
				rest.unshift({fst:p2, snd:l});
			}
			else {
				rest.unshift({fst:p2, snd:l});
				rest.unshift({fst:p, snd:[f]});
			}
			return rest;
		}
		ctx.g.delayed = loop(ctx.g.delayed);
	}

	public static function flush_pass (ctx:context.Typecore.Typer, p:context.Typecore.TyperPass, where:String) {
		if (ctx.g.delayed.length > 0) {
			var p2 = ctx.g.delayed[0].fst;
			if (typerPassToInt(p2) <= typerPassToInt(p)) {
				var l = ctx.g.delayed[0].snd;
				if (l.length == 0) {
					ctx.g.delayed.shift();
				}
				else {
					var f = l.shift();
					ctx.g.delayed.unshift({fst:p2, snd:l});
					f();
				}
				flush_pass(ctx, p, where);
			}
		}
	}

	public static function make_pass (ctx:context.Typecore.Typer, f:Void->core.Type.BuildState) : Void->core.Type.BuildState {
		return f;
	}

	public static function init_class_done (ctx:context.Typecore.Typer) : Void {
		ctx.pass = PTypeField;
	}


	public static function exc_protect (?force:Bool=true, ctx:Typer, f:Ref<core.Type.TLazy>->core.Type.T, where:String) : Ref<core.Type.TLazy> {
		var r = new Ref(core.Type.lazy_available(core.Type.t_dynamic));
		r.set(core.Type.lazy_wait(function () {
			return try {
				var t = f(r);
				r.set(core.Type.lazy_available(t));
				t;
			}
			catch (err:core.Error) {
				throw new core.Error.Fatal_error(core.Error.error_msg(err.msg), err.pos);
			}
		}));
		if (force) {
			delay(ctx, PForce, function () {core.Type.lazy_type(r);});
		}
		return r;
	}

	static function compareTyperPass (a:TyperPass, b:TyperPass) : Int {
		if (a == b) { return 0; }
		return (typerPassToInt(a) > typerPassToInt(b)) ? 1 : -1;
	}

	static function typerPassToInt (p:TyperPass) : Int {
		return switch (p) {
			case PBuildModule: 0;
			case PBuildClass: 1;
			case PTypeField: 2;
			case PCheckConstraint: 3;
			case PForce: 4;
			case PFinal: 5;
		};
	}
}