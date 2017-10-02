/ some utils, update this over time as we find out what's useful
/ THIS ONE ISN"T tidied up, just a few utilities

/ produce one hot encoded matrix of class labels
/ in practice would need to store the labels with the encoded object (probably as dict)
/ to be able to reverse, here no reverse is being done
/ return a table with categories from the specified column as new column headers
/ e.g. if the 'foobar' column contains unique values 2 3 4 in the input table, there will be columns foobar_2 foobar_3 foobar_4 in the output table
ohecol2tab:{[tab;cname]
 / assumes cname_classlabels aren't already cols in the table
 ![;();0b;enlist cname]tab,'(`$string[cname],/:"_",'string cols ohedata)xcol ohedata:oheastab tab cname}
oheastab:{flip(`$string dlabels)!"i"$x=/:dlabels:asc distinct x}
/ reverse it, assumes results come back as one hot encoded, anything > .5 true o/w false
/ TODO
/ohe2lab:{dlabels {x?max x}each x}
/ normalize list of values to (0;1)
normvec:{x%max x}
/ test train split, assumes unkeyed table, feature cols a list, label cols a list
/ sets dict with names specified in ttnames with features and labels elements
/ nrows is number of rows to take sa training set, the remainder is the test set
ttsplit:{[data;fnames;lnames;ttnames;nrows]
 if[nrows>count data;'toomany];
 ttnames set'`features`labels!/:((0,nrows)cut data)@\:(fnames;lnames)}
/ simple mode (for voting  amongst k neighbors for example)
mode:{u?max u:freq x} 

/ number of occurrences by class
freq:{?[([]x);();`x;(count;`i)]}

/ sample one index from top y of list of result propabilities x
sample:{first u randp[1]x y sublist u:idesc x}
/ x random indices for a list of relative probablilites y 
randp:{sy bin x?last sy:0,sums y}

\

/ confusion matrix TODO 
cfm:{[pred;act]sdl:`$string dl:asc distinct pred,act;exec sdl!value 0^dl#freq pred by act:act from ([]act;pred)}
cfm1:{[pred;act]
 cfmr:cfm[pred;act];
 prec:precision[pred;act];
 rec:recall[pred;act];
 f:freq act;
 update total:f act,precision:prec act,recall:rec act from cfmr}

/ precision and recall for multi class prediction
/ for binary case 
/ precision is (true positives)/(tp+fp)
/ recall is (tp)/tp+fn
/ precision by class (correct)/(correct+sum all other predicted)
/ recall by class (correct)/count by class
recall:{[pred;act]exec sum[pred=act]%count i by act from ([]act;pred)}
precision:{[pred;act]exec sum[act=pred]%count i by pred from ([]act;pred)}
