/ example of keras similar to https://github.com/udacity/machine-learning/tree/master/projects/practice_projects/imdb
\l ../ml/mlutils.q
/ python utilities to make callable classes and functions with named and optional args
\l ../ml/pyutils.q

/ Load data, split to features and labels and into training and testing sets
data:0^`admit`gre`gpa`classrank xcol ("BFFF";enlist csv)0:`:student_data.csv
/ one hot encode ranks class ranks
data:ohecol2tab[data;`classrank]
data:ohecol2tab[data;`admit]
/ normalize label values TODO, should store original max values to denormalize later
/ results below are normalized values
update normvec gre,normvec gpa from `data
 
ttsplit[data;`gre`gpa,`$"classrank_",/:string 0 1 2 3 4;`$"admit_",/:string 0 1;`testing`training;50]
/ keras will want the data flipped (rows not columns)
{@[x;`features`labels;flip]}each `testing`training
/ that's all the q part
/ the rest is importing stuff we need from keras, training and prediction


/ import everything we need
.py.imp_class_from[`keras.models]`Sequential
.py.imp_class_from[`keras.layers]each`Dense`Dropout`Activation
.py.imp_class_from[`keras.optimizers]`SGD
/ don't want to convert numpy arrays back to q as it doesn't work at the moment
.py.imp_class_from_as[`numpy;`array;`nparray] 

/ create a model and wrap it in a dictionary with methods/properties accessible with dot notation
/ data and properties have to be accessed via mode.propertyname[] (as needs to use python getter) 
model:.py.classinstance Sequential[]
/ model.predict should return a proper q object
/ we shouldn't need the q list here but numpy array doesn't come back properly
/ (maybe a bug in python interface?) so we can't just do .P.GET foreign on the object (as we should)
model.predict:.py.c .py.qlist,model.predict

/ add some layers to model
/ all python functions return a py object, we don't care about the result so suppress output
model.add Dense[123;`activation pp `relu;`input_shape pp enlist 7];
model.add Dropout .2;
model.add Dense[64;`activation pp `relu];
model.add Dropout .1;
model.add Dense[2;`activation pp `softmax];

/ compile the model
/ metrics param needs to be manually converted to python list as keras insists on list
/ but q makes python tuple from symlist, .py.pylist does gives a python list as foreign object
model.compile[`loss pp`categorical_crossentropy;
              `optimizer pp SGD[`lr pp .01];
              `metrics pp .py.pylist 1#`accuracy];
/ print a summary
model.summary[];

-1"\n\ntraining for 10 epochs. To change number of epochs run\n\t",
 "model.fit[nparray training.features;nparray training.labels;`epochs pp 50;`batch_size pp 512]\n\tmodel.predict nparray testing.features\n\n\tresults are expected (normalized) gre and gpa for each student in test set\n\n";
model.fit[nparray training.features;nparray training.labels;`epochs pp 10;`batch_size pp 1000]; 

/ predict the labels for the test set
/ note that we overwrote model.predict above to return a q object because it's convertable to q
result:model.predict[nparray testing.features]


\
