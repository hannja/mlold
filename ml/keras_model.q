\l pyutils.q
\l mlutils.q
/ some logging utils
\l log.q
/ parameter parsing
o:first each .Q.opt .z.x
req:`data`checkpoint`method
opt:`restore`seqlen`embedsize`rnnsize`numlayers`droprate`learnrate`clipnorm`batchsize`numepochs`logs
usage:"\nq keras_model.q -method {train|generate} -data trainingtextfile -checkpoint directory\n\n\t",
        "[-restore directory]\tPreviously created checkpoint directory to restore from\n\t",
        "[-seqlen J]\t\tSequence length for inputs and outputs (default 64 chars)\n\t",
        "[-length J]\t\tlength of generated text (also during training) (default 500 chars)\n\t",
        "[-topn J]\t\tchoose next character from top N candidates (default 10)\n\t",
        "[-embedsize J]\t\tCharacter embedding size (default 32)\n\t",
	"[-rnnsize J]\t\tSize of rnn cell (default 128)\n\t",
        "[-numlayers J]\t\tNumber of RNN layers (LSTM+Dropout) (default 2)\n\t",
        "[-droprate F]\t\tDropout rate for rnn layers (default 0.0)\n\t",
        "[-learnrate F]\t\tLearning rate (default 0.001)\n\t",
        "[-clipnorm F]\t\tmax norm to clip gradient (default 5.0)\n\t",
        "[-batchsize J]\t\ttraining batch size (default 64)\n\t",
        "[-numepochs J]\t\tnumber of training epochs (default 2)\n\t", 
        "[-log file]\t\tLog file to write messages to (default keras_model.log)";

if[not all v:req in key o;
 -2"required params missing ",(csv sv string[req]where not v),"\n",usage;exit 1];

/ just utils, shouldn't be in here really
sstring:{$[10=type x;;string]x}
fexists:{u~key u:hsym`$sstring x} 
dexists:{11=type key hsym`$sstring x}

if[not fexists data:hsym`$sstring o`data;
 -2"data file does not exist\n",usage;exit 2];

if[not dexists checkpointdir:hsym`$sstring o`checkpoint;
 -1"checkpoint directory does not exist, will create it\n";
 hdel(` sv checkpointdir,`e)set ();
 ];
checkpoint:` sv checkpointdir,`checkpoint

if[not in[;`train`generate]method:`$o`method];
restore:`restore in key o;
if[restore;
 if[not fexists restorefile:$["1b"~o`restore;checkpoint;hsym`$sstring o`restore];
  .lf.err("restore specified but restore point %s does not exist\n",usage;restorefile);exit 3]];

{[o;n;t;d]n set d^t$o n;}[o].'
 (`seqlen,"J",64;`embedsize,"J",32;`length,"J",500;`rnnsize,"J",128;`numlayers,"J",2;`topn,"J",10;
  `numepochs,"J",2;`batchsize,"J",64;`droprate,"F",0.;`learnrate,"J",1e-3;`clipnorm,"F",5.;
  `log,"S",`keras_model.log);




/ work begins
/ keras imports
.py.imp_class_from[`keras.callbacks]`Callback`ModelCheckpoint`TensorBoard`LambdaCallback
.py.imp_class_from[`keras.layers]`Dense`Dropout`Embedding`LSTM`TimeDistributed
.py.imp_class_from[`keras.models]`load_model`Sequential
.py.imp_class_from[`keras.optimizers]`Adam
/ create np arrays from q lists
nparray:.py.pycallable_from[`numpy;`array]

/ read the data and create encode and decode functions
/ new lines are a valid character 0x0b 0x0c and \r are not`
data:"c"$data where not in[;0x0b0c0d]data:read1 data; 
/ encode and decode TODO need any null handling?
dec:key enc:u!til count u:asc distinct data;

		

/ validation of required items in param dict and apply defaults
/ signals error or returns defaults overrriden with param dict given
/ default param prototype 
dd:(0#`)!()
vldparams:{[req;p;d]if[not all u:req in key p:d,p;'"missing params: ",csv sv string req where not u];p}

/ gives (LSTM layer;Dropout layer) 
lstmdrop:{[rnnsz;dr]LSTM[rnnsz;`return_sequences pp 1b;`stateful pp 1b],Dropout dr}

/ build and compile model from param dictionary
/ the add and compile calls here are from python, each add statements adds a python foreign object
/ (created using Embedding, LSTM, Dropout or TimeDistributed
bmodel:{[p]
 p:vldparams[key[defs],`batchsize`seqlen;p]
  defs:select vocsz:count dec,embedsz:32,rnnsz:128,nl:2,dr:0.,lr:.001,cn:5. from dd; 

 add:@[;`add]model:cim Sequential[]; / we'll be using methods from model so wrap the object
 add each Embedding[p`vocsz;p`embedsz;`batch_input_shape pp p`batchsize`seqlen],Dropout p`dr;
 / add LSTM layers
 add each raze lstmdrop[p`rnnsz]each p[`nl]#p`dr;
 add TimeDistributed Dense[p`vocsz;`activation pp `softmax];
 model[`compile][`loss pp `categorical_crossentropy;`optimizer pp Adam[p`lr;`clipnorm pp p`cn]];
 model}

/ build an inference model
bimodel:{[model;batchsize;seqlen]
 / grr no dot notation with locals;
 config:model[`get_config][];
 config[0;`config;`batch_input_shape]:batchsize,seqlen;
 inference_model:cim model[`from_config]config;
 / don't want training of the prediction model 
 inference_model[`trainable][:;0b];
 inference_model}

/ class instance of model 
/ we'll want to access methods and properties of models and 
/ the predict and get_config methods to return q objects so
/ we override the default behaviour which is to return a foreign object
cim:{x:.py.classinstance x;
 x[`predict]:.py.c .py.np2qlist,x`predict;
 x[`get_config]:.py.c .P.GET,x`get_config;
 x}

/ generate some text using an inference model and an input seed
gtext:{[imodel;seed;len;topn]
 generated:seed;
 imodel[`reset_states][];
 / set internal state of the model
 (pf:imodel`predict) each nparray each 1 cut -1 _ et:enc seed;
 / generate text and return appended to the seed
 :seed,dec 1_len{[pf;topn;ind]sample[;topn]first first pf nparray 1#ind}[pf;topn]\last et;
 }

/ copies weights from the trained model to an inference model and generate text
inferandgenerate:{[imodel;model;length;topn]
 imodel[`set_weights]model[`get_weights][];
 .lf.out"generating text";
 -1 gtext[imodel;randseq data;length;topn];
 }

/ pick a sequence of random length from a random position in the input data
randseq:{[data]data rand[count[data]-l]+til l:rand 4 5 16 32 64}


/ example of a callback invoked by keras, writes some generated text on each epoch end
epochend:{[n;dict]
 .lf.out("Epoch %j end, loss %.6f";n;dict`loss);
 imodel.set_weights model.get_weights[];
 -1 gtext[imodel;randseq data;length;topn];
 };


/ returns a generator function for use in keras's model.fit_generator method
/ does the data prep once before creating the generator function
batchgen:{[sequence;dec;batchsize;seqlen;ohef;ohel] 
 if[0=nb:(-1+count sequence)div batchsize*seqlen;
  '"no batches created. Use smaller batchsize or seqlen."];
 .lf.out("number of batches:%j";nb);
 .lf.out("effective text length: %j";rl:nb*batchsize*seqlen);

 / one hot encode if necessary
 / like np.eye, build identity matrix, should be a better way
 eye:{neg[til x]rotate'x#enlist 1,(x-1)#0};
 ohe:eye count dec; / TODO inefficient I suspect
 / cut into batches
 x:$[ohef;ohe;](nb*seqlen)cut rl#sequence;
 y:$[ohel;ohe;](nb*seqlen)cut (1,rl)sublist sequence;
 xep:flip seqlen cut'x;
 yep:flip seqlen cut'y;

 / the actual generator function, taking state and dummy, 
 / state is batchnum, epoch, batches per epoch 
 / we don't want huge state passing q<->python 
 / just training data for the epoch -> python and current batch and epoch info -> q
 / these are globals, analogous to case where data on disk is too large to be passed to keras
 XEP::xep;YEP::yep; 
 :{[bn;ep;nb;d]
  / same epoch, increment batch, new epoch start at batch 0
  $[bn<-1+nb;bn+:1;[bn:0;ep+:1]];
  xres:ep rotate XEP bn;
  yres:ep rotate YEP bn;
  :((.z.s;bn;ep;nb);(nparray xres;nparray yres))}[0;-1;nb];
 }


/ script can either be called to train or generate text from a trained model

/ train the model
train:{[]
 / global will be used in callbacks
 model::$[restore;cim load_model 1_ string restorefile;
                  bmodel`batchsize`seqlen`nl!batchsize,seqlen,numlayers]; 
 model.summary[];
 / build call backs for training
 / checkpointing
 ccb:ModelCheckpoint[1_string checkpoint;`verbose pp 0;`save_best_only pp 0b];
 / logging callbacks 
 lcb:LambdaCallback[`on_epoch_end pp epochend];
 / write tensorboard output
 tbcb:TensorBoard["./log";`write_graph pp 1b;`write_images pp 1b;`write_grads pp 1b];

 nb:(-1+count data)div batchsize*seqlen;
 / build a generator function for keras
 bg:batchgen[enc data;dec;batchsize;seqlen;0b;1b]; 
 / inference model
 imodel::bimodel[model;1;1]; 
 / training
 model.fit_generator[.py.qgenfi bg;nb;numepochs;`callbacks pp .py.pylist(ccb;lcb;tbcb)];
 / once trained, generate some text 
 inferandgenerate[imodel;model;batchsize;seqlen];
 }

/ just generate text from a previously trained model
generate:{
 if[not fexists checkpoint;"Checkpoint ",string[checkpoint]," does not exist"];
 model::cim load_model 1 _ string checkpoint;
 imodel::bimodel[model;1;1];
 inferandgenerate[imodel;model;length;topn];
 }

/ train or generate
method[]


 
\
