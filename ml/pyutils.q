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
pycallable:{if[not 112=type x;'`type];ce .[.P.CALL x],`.py.q2pargs} 
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
imp_from:{imp_from_as[x;y;y]}                                    / from x import y
imp_from_as:{z set'imp_from_i[x]'[y]}                            / from x import y as z
imp_callable_from:{imp_callable_from_as[x;y;y]}                  / from x import y and make y callable returning a q object (careful if the return can't be converted)
imp_pycallable_from:{imp_pycallable_from_as[x;y;y]}              / from x import y and make y callable returning foreign 
imp_callable_from_as:{z set'callable_from[x]'[y]}                / from x import y as z and make z callable returning q
imp_pycallable_from_as:{z set'pycallable_from[x]'[y]}            / from x import y as z and make z callable returning foreign

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
pylist:pycallable_from[`builtins]`list
/ used to convert NumPy arrays to lists, issues with higher dimensional numpy arrays
/ currently in python interface, just using pylist doesn't do deep list conversion
np2list:pycallable_from[imp_from_i[`numpy;`ndarray];`tolist]
/ convert to q, e.g. convert x to a list (using list(...)) then convert to q 
qlist:{.P.GET pylist x}
/numpy array to a q array, seems to have issues doing it directly at the moment
np2qlist:{.P.GET np2list x}

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

/ python function creation and wrapping
/ from a function foo:{[a;b;c;d]}
/ we can define a something callable in python with exactly 4 arguments with
/ .P.SET[`pyfoo]foo
/ however if less arguments are passed, this call gives back a projection (wrapped in python)
/ and if more seg faults (though should throw rank probably)
/ so we'd like to get a different function in python with named parameters
/ which will call the python callable object with exactly the correct parameters 
/  we'd also like this new function to have keyword args so the eventual python caller can use this
/  and ability to set defaults
/ Approach
/ from a q function, create a python lambda (via string building for now) which calls the q function with it's args
/  this first function has no optional arguments and arguments are all positional
/ using functools.partial wrap this function specifying the defaults we want 
/ no projections or compositions for now, although this should be done TODO

/qf2pl:{pl:get[x]1;.P.EVAL "lambda ",(csv sv u,\:"=None"),",f=None:f(",(csv sv u:string pl),")"} 
/ build python function callable with keyword args 
/pyfunc:{[x;dd].P.CALL[partial;enlist qf2pl;(`f,key dd)!enlist[x],value dd]}


/ TODO param validation
/partial:{[f;args;kwargs].P.CALL[imp_from_i[`functools]`partial][f](args;kwargs)}
/qpartial:{[f;args;kwargs]partial[f](args;kwargs)}
/ create a function callable in python with args applied from q (but overrideable in python)
/ TODO x is foreign args is list of positional argument  names, 
/deffunc:{[x]}
 
/TODO these should really be in a python module I think, needed to wrap q projections for callbacks and generators
/ note that you need the modified version of py.c with the change for projections for this to work
/# callable class wrappers for q projections and 'closures' (see below) 
P)from itertools import count
P)class qclosure(object):
 def __init__(self,qfunc=None):
  self.qlist=qfunc
 def __call__(self,*args):
  res=self.qlist[0](*self.qlist[1:]+args)
  self.qlist=res[0] #update the projection
  return res[-1]
 def __getitem__(self,ind):
  return self.qlist[ind]
 def __setitem__(self,ind):
  pass
 def __delitem__(self,ind):
  pass

P)class qprojection(object):
 def __init__(self,qfunc=None):
  self.qlist=qfunc
 def __call__(self,*args):
  return self.qlist[0](*self.qlist[1:]+args)
 def __getitem__(self,ind):
  return self.qlist[ind]
 def __setitem__(self,ind):
  pass
 def __delitem__(self,ind):
  pass

/ closures don't exist really in q, however they're useful for implementing
/ python generators. we model a closure as a projection like this
/ f:{[state;dummy]...;((.z.s;modified state);func result)}[initialstate]
/ the closure class above in python when called will return the final result
/ but update the projection (as a list) it is maintaining internally to use the new state
/ example generator functions 
gftil:{[state;d](.z.s,u;u:state+1)}0 / 0,1,...,N-1 
gffact:{[state;d]((.z.s;u);last u:prds 1 0+state)}0 1 / factorial

/ generator lambda, to be partially applied with a closure in python
/ the subsequent application of this function to an int N will give a 
/ generator which yields N times
gl:.P.EVAL"lambda genarg,clsr:[(yield clsr(x)) for x in range(genarg)]"
/ this one just keeps yielding
gli:.P.EVAL"lambda genarg,clsr:[(yield clsr(x)) for x in count()]"
.py.imp_pycallable_from[`functools]`partial;
/ should be in it's own module
.py.imp_class_from[`$"__main__"]`qclosure;
/ returns a python generator function from q 'closure' x and argument y where y is the
/ number of times the generator will be called
qgenf:{pycallable[partial[gl;`clsr pp qclosure x]]y}
qgenfi:{pycallable[partial[gli;`clsr pp qclosure x]]0}
/ examples
/.py.imp_callable_from_as[`builtins;`sum;`pysum]
// sum of first N ints using python generators
/ pysum .py.qgenf[.py.gftil;10]
// sum of factorials of first N numbers
/ pysum .py.qgenf[.py.gffact;10]
/genq:partial[gl;`

\
TODO
do we need module handling so we can do similar thing to classinstance behaviour?
to give something analogous to
import numpy as np
np.array(...)
np.add(...)




