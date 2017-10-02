/ log formatting,
/ "%T, %.6f" , print f like, argument should be string and n items where n is number
/ of unescaped %'s 
/ using q -> table, k -> keyed table or dict, o anything > 100
\d .lf
 
 
lfi:{
 / kindof slow, scan through if % encountered, append and mark, if next is % then drop and unmark
 f:{[s;x;i]$["%"=s i;$[x 1;(-1 _ x 0;0b);(x[0],i;1b)];(x 0;0b)]};
 u:first(0#0;0b)f[first x]/til count sx:first x;
 if[not count[x]=1+count u;'`length];
 / not optimized
 :ssr[u[0],raze lffrag'[1_u:(0,u)cut sx;1_x];"%%";"%"];
 }
 
/ for a single format fragment and argument, create a log string 
/ format log fragment
lffrag:{if[not 0=first u:ss[x;"%"];'`notfound];
  f:{$[1b~x 1;x;(1+x 0),y in tformats]};
  if[not last tii:(-1;0b)f/x;'`typenotfound];
  :gftfs[`$x tii 0][x;tii 0;y],(1+tii 0)_x;
  }
/ type specific log formatters
/ everything but floating points just get's -3!'d currently
ftfs:(enlist`)!enlist{-3!z} / default is q's string
ftfs.f:{
 j:{$[0=type x;" "sv;10=type x;;'`type]x};
 $["."in fs:1_(y)#x;
   $[null last ba:"J"$"."vs fs;-3!z;         / N. system P
     null ba 0;j .Q.f[ba 1]'[z];             / .N any before N after
               j .Q.fmt[1+sum ba;ba 1]'[z]]; / M.N M before N after, "****" if M+N<10 xlog x
  -3!z]}
ftfs.e:ftfs.f

gftfs:{ftfs$[x in key ftfs;x;`]}
tformats@:where not null tformats:.Q.t,upper[.Q.t],"qko"
li:{
 if[10=type y;:x y];
 fs:@[lfi;y;{-2"log format error \"",y,"\", format string is ",-3!x;0b}first y];
 if[not 0b~fs;x fs]}
/ actual functions 
out:{li[-1]x}
err:{1i[-2]x}
