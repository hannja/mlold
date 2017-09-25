/ python utilities
/ TODO needs more docs
/ calling functions and instantiation of classes with default and named params params ...
/ in q can only have variable number of arguments with the composition with enlist trick
/ we want to be able to call python functions like this func[posarg1;posarg2;...;namedargs]
/ use .py.pycallable[foreignfunction] to get such a function (which will return a foreign object)
/ or  .py.callable[foreignfunction] to get a function which will attempt conversion to q on return
/ e.g. 
/ q)P)def foo(x,y,z=3):print("x,y,z",x,y,z);return x*y*z 
/ q)fooforeign:.P.ATTR[.P.IMP`$"__main__";`foo]
/ / now we can call this function
/ q)myfoo:.py.callable fooforeign
/ / in reality we'd just do
/ q)myfoo:.py.callable .py.impfrom[`$"__main__";`foo]
/ / or even
/ q)myfoo:.py.locfunc`foo
/ q)myfoo[1;2;4]
/ x,y,z 1 2 8
/ 8
/ q)myfoo[1;2]
/ x,y,z 1 2 3
/ 6
/ q)myfoo[`z pp 7;`y pp 3;`x pp 1] / you can use named arguments
/ x,y,z 1 3 7
/ 21
/ / the usual python rules apply
/ q)myfoo[1;`x pp 2] / will raise python error (duplicate x)
/ TypeError: foo() got multiple values for argument 'x'
/ 'pyerr
/  [0]  myfoo[1;`x pp 2]
/ q)myfoo[`z pp 7;1;2] / error positional args after named
/ 'positional argument follows keyword argument
/ [0]  myfoo[`z pp 7;1;2]
/ bear in mind you can always simply use the .P.meth and methd functions as well if you don't like these


/ ensure P.k or py.k is loaded
if[0b~@[system;"l py.k";{-1"py.k not found, will try P.k";0b}];system"l P.k"];

\d .py
/ compose list of functions
k)c:{'[y;x]}/|:
/ compose with enlist (for composition trick used for 'variadic functions')
k)ce:{'[y;x]}/enlist,|:
/ abuse of infix, identify named params for python call
/ to get infix notation with pp we have to put it in .q namespace (not recommended by kx)
/ without infix you have to use .py.pp[`argname]argvalue which is a tad ugly
if[not `pp in key`.q;.py.pp:(`..pyparam;;);.q.pp:pp];
/ list of q args to python args 
q2pargs:{
 / for zero arg callables
 if[x~enlist(::);:(();()!())];
 / we check order as we're messing with it before passing to python and it won't be able to
 if[any 1_prev[u]and not u:`..pyparam~'first each x;'"positional argument follows keyword argument"];
 cn:{$[()~x;x;11h<>type x;'`type;x~distinct x;x;'`dupnames]};
 :(x where not u;cn[named[;1]]!(named:(x,(::))where u)[;2])
 }
/ this uses the composition with enlist trick, not benchmarked performance overhead
/ callable q function from python function (python functino is foreign)
callable:{if[not 112=type x;'`type];ce .P.GET,.[.P.CALL x],`.py.q2pargs}
/ same as callable but result as python object (foreign in q)
pycallable:{if[not 112=type x;'`type];ce .[.P.CALL x],`.py.q2pargs} /q2pargs}
/ example for q functions, don't bother using
qcallable:{ce .[x],`.py.q2pargs}


/ names are horrible any suggestions welcome
/ import ...
/ from ... import ...
/ from ... import ... as
/ these return the name set by the import imp_callable.. returns a callable that will attempt
/ to convert the object to q, imp_pycallable returns the foreign object as is
imp:.P.IMP / the basic one
imp_from_i:{$[0<type y;.z.s each y;atr[$[112=type x;x;imp x]]y]} / internal, returns the thing imported, x can be name or foreign, y should be symbol
imp_from:{y set imp_from_i[x;y]}                                 / from x import y
imp_from_as:{z set imp_from_i[x;y]}                              / from x import y as z
imp_callable_from:{imp_callable_from_as[x;y;y]}                  / from x import y and make y callable returning a q object (careful if the return can't be converted)
imp_pycallable_from:{imp_pycallable_from_as[x;y;y]}              / from x import y and make y callable returning foreign 
imp_callable_from_as:{z set callable_from[x;y]}                  / from x import y as z and make z callable returning q
imp_pycallable_from_as:{z set pycallable_from[x;y]}              / from x import y as z and make z callable returning foreign

callable_from:{callable imp_from_i[x;y]}                         / gives a callable function which returns q data
pycallable_from:{pycallable imp_from_i[x;y]}                     / gives a callable function which returns foreign

/ aliases,  classes should be callable but not attempt to convert to q
imp_class_from:imp_pycallable_from
imp_class_from_as:imp_pycallable_from_as

/ shorter name for attribute access as commonly used
atr:.P.ATTR

/ get callable version of local function in __main__ which returns q
/ example above 
locfunc:c callable,imp_from_i`$"__main__" / get callable version of local function 
/ to convert q vectors to python lists (they will be tuples by default)
pylist:pycallable_from[`builtins;`list]
/ convert to q, e.g. convert a numpy array to a q array, seems to have issues doing it directly at the moment
qlist:{.P.GET pylist x}

/ classdict from an instance
/ produce a dictionary structure with callable methods and accessors for properties and data members
/ a problem is we cannot directly inspect an instance (using python inspect module) if it 
/ has properties as the property getter may not succeed, an example from keras is the regularizers 
/ property of a model can't be accessed before the model is built. In any case we need to go through the property
/ getter in python each time in order to be consistent with python behaviou.  
/ This solution finds all methods,data and properties of the *class* of an instance using inspect module
/ and creates pycallables for each taking zero args for data and properties and the usual variadic behaviour for 
/ Can get and set properties, see keras_udacity_example.q for examples of calling methods
/ e.g. for properties 
/ q).py.imp_class_from[`keras.models]`Sequential / need to use 'each' for lists of inputs currently
/ q)model:.py.classinstance Sequential[]
/ q)model.trainable[] / returns foreign
/ / since we know model.trainable returns something convertible to q it's handier to overwrite the default behaviour or it
/ q)model.trainable:.py.c .P.GET,model.trainable
/ q)model.trainable[] 
/ q)model.trainable[:;0b]    / set it to false
/ q)model.trainable[] / see the result


/ make a q dict from a class instance
/ TODO better name!
.py.classinstance:{[x]
 if[not 112=type x;'"can only use inspection on python objects"];
 / filter class content by type (methods, data, properties)
 f:i.anames i.ccattrs atr[x]`$"__class__";
 mn:f("method";"class method";"static method");
 / data and classes handled identically at the moment
 dpn:f `data`property;
 / build callable method functions, these will return python objects not q ones
 / override with c .P.GET,x.methodname if you expect q convertible returns
 / keep a reference to the python object somewhere easy to access
 res:``_pyobj!((::);x); 
 res,:mn!{pycallable atr[x]y}[x]each mn;
 / properties and data have to be accessed with [] (in case updated, TODO maybe not for data)
 bf:{[x;y]ce .[paccess[x;y]],`.py.pparams};
 /:res,dpn!{{[o;n;d]$[d~(::);atr[o]n}[x;y]}[x]each dpn;
 :res,dpn!{[o;n]ce .[paccess[o;n]],`.py.pparams}[x]each dpn;
 }
/ class content info helpers
i.ccattrs:pycallable_from[`inspect]`classify_class_attrs
i.anames:{`${x where not x like"_*"} callable[.P.EVAL"lambda xlist,y: [xi.name for xi in xlist if xi.kind in y]"][x;y]}

/ some other utilities and helper functions 
pyhelp:{pycallable_from[`builtins;`help]x;}
pyprint:{x y;}pycallable_from[`builtins;`print]
setattr:pycallable_from[`builtins;`setattr]; / maybe should be in c?
/ getting and setting properties and data
/ attempt to make this easier to use than .py.setattr[dict._pyobj;attrnameassym;newval]
paccess:{[ob;n;op;v]$[op~(:);setattr[ob;n;v];atr[ob]n]}
/ property params
/ syntax for property and data params is now a bit odd but we can at least do
/ instance.propertyname[] / get the value
/ instance.propertyname[:;newval] / set the value to newval
pparams:{`.property_access;2#x}

/ help function
/ help displays python help on any of these
/ / foreign objects e.g.
/ q)help Sequential[]
/ / a pycallable e.g.
/ q)help Sequential
/ wrapped python class instances returned from .py.classinstance e.g. 
/ q)help model
/ q)model:.py.classinstance Sequential[]
/ properties accessors e.g.
/ q)help model.trainable
/ methods in wrapped classes e.g.
/ q)help model.add


help:{
 $[112=type x;
   :pyhelp x;
  105=type x; /might be a pycallable 
   $[last[u:get x]~ce 1#`.py.q2pargs;
     :.z.s last get last get first u;
    .P.GET~u 0; / callable or some other composition with .P.GET as final function
     :.z.s last u; 
    105=type last u; / might be property setter
     if[last[u]~ce 1#`.py.pparams;:.z.s x[]]; 
    ]; 
  99=type x; / might be wrapped class
   if[11h=type key x;:.z.s x`$"_pyobj"]; / doesn't matter if not there 
   ];"no help available"}


/comment if you want your top level namespace left in peace (this puts help and print in top level)
@[`.;`help;:;help];
@[`.;`print;:;pyprint];
 

\
TODO
do we need module handling so we can do equivalent similar thing to classinstance behaviour?
to give something analogous to
import numpy as np
np.array(...)
np.add(...)




